//------------------------------------------------------------------------------
//
// Extracted to separate entity, converted to verilog, optimized and tweaked
// (c) 2018 Sorgelig
//
//------------------------------------------------------------------------------
//
//    {@{@{@{@{@{@
//  {@{@{@{@{@{@{@{@  This code is covered by CoreAmstrad synthesis r005
//  {@    {@{@    {@  A core of Amstrad CPC 6128 running on MiST-board platform
//  {@{@{@{@{@{@{@{@
//  {@  {@{@{@{@  {@  CoreAmstrad is implementation of FPGAmstrad on MiST-board
//  {@{@        {@{@   Contact : renaudhelias@gmail.com
//  {@{@{@{@{@{@{@{@   @see http://code.google.com/p/mist-board/
//    {@{@{@{@{@{@     @see FPGAmstrad at CPCWiki
//
//------------------------------------------------------------------------------

// https://sourceforge.net/p/jemu/code/HEAD/tree/JEMU/src/jemu/system/cpc/GateArray.java

// altera message_off 10027
module Amstrad_GA
(
   input            CLK,
   input            CE_4,
   input            CE_16,
   input            RESET,
   
   input      [1:0] phase,
   input            resync,

   output reg       INT,
   input            crtc_vs,
   input            crtc_hs,
   input            crtc_de,
   output           crtc_shift,
   input     [15:0] vram_D,
   
   input            INTack,
   input      [7:0] D,
   input            WE,
   
   input            PAL,
   output reg       CE_PIX,
   output reg       CE_PIX_FS,
   output reg [7:0] RED,
   output reg [7:0] GREEN,
   output reg [7:0] BLUE,
   output reg       HBLANK,
   output reg       VBLANK,
   output reg       HSYNC,
   output reg       VSYNC
);

//HD6845S 	Hitachi 	0 HD6845S_WriteMaskTable type 0 in JavaCPC
//UM6845 	UMC 		0
//UM6845R 	UMC 		1 UM6845R_WriteMaskTable type 1 in JavaCPC <==
//MC6845 	Motorola	2 

// output pixels
// Amstrad
// 
//OFFSET:STD_LOGIC_VECTOR(15 downto 0)$x"C000";
// screen.bas
// CLS
// FOR A=&C000 TO &FFFF
// POKE A,&FF
// NEXT A
// 
// line.bas
// CLS
// FOR A=&C000 TO &C050
// POKE A,&FF
// NEXT A
// 
// lines.bas
// CLS
// FOR A=&C000 TO &C7FF
// POKE A,&FF
// NEXT A
// 
// byte pixels structure :
// mode 1 :
//   1 byte <=> 4 pixels
//   [AAAA][BBBB] : layering colors [AAAA] and [BBBB]
//   A+B=0+0=dark blue (default Amstrad background color)
//   A+B=0+1=light blue
//   A+B=1+0=yellow
//   A+B=1+1=red
//  for example [1100][0011] with give 2 yellow pixels followed by 2 light blue pixels &C3
// mode 0 : 
//   1 byte <=> 2 pixels
//   [AA][BB][CC][DD] : layering colors of AA, BB, CC, DD
//   Because it results too many equations for a simple RGB output, they do switch the last equation (alternating at a certain low frequency (INK SPEED))
// mode 2 :
//   1 byte <=> 8 pixels
//   [AAAAAAAA] : so only 2 colors xD

reg  [4:0] pen[15:0] = '{4,12,21,28,24,29,12,5,13,22,6,23,30,0,31,14};
reg  [4:0] border;
reg  [1:0] MODE_select;

always @(posedge CLK) begin
	reg [3:0] ink;
	reg       border_ink;

	if (RESET) MODE_select <= 2'b00;
	else begin
		if (WE) begin //7Fxx gate array --
			if (D[7:6] == 2'b10)	begin
				//http://www.cpctech.org.uk/docs/garray.html
				if (D[1:0] == 3) MODE_select <= 0;
				else MODE_select <= D[1:0];
			end
			else if (~D[7]) begin
				// palette
				if (~D[6]) {border_ink,ink} <= D[4:0];
				else if (border_ink) border <= D[4:0];
				else               pen[ink] <= D[4:0];
			end
		end
	end
end

// Interrupt generator
always @(posedge CLK) begin
	reg [5:0] InterruptLineCount;
	reg [1:0] line_delay;
	reg       old_hsync;
	reg       old_vsync;

	if (RESET) begin
		InterruptLineCount <= 0;
		line_delay <= 0;
		old_hsync <= 0;
		old_vsync <= 0;
		INT <= 0;
	end
	else begin
		if(CE_4 && phase == 2) begin
			old_hsync <= crtc_hs;
			old_vsync <= crtc_vs;

			// The GA has a counter that increments on every falling edge of the CRTC generated HSYNC signal.
			// It triggers 6 interrupts per frame http://pushnpop.net/topic-452-1.html
			if (old_hsync & ~crtc_hs) begin
				InterruptLineCount <= InterruptLineCount + 1'd1;
				if (InterruptLineCount == 51) begin	// Asphalt ? -- 52="110100"
					// Once this counter reaches 52, the GA raises the INT signal and resets the counter to 0.
					InterruptLineCount <= 0;
					INT <= 1;
				end

				line_delay <= line_delay << 1;
				if (line_delay[1]) begin
					// activate interrupt only if bit5 of counter is set.
					if (InterruptLineCount[5]) INT <= 1;
					InterruptLineCount <= 0;
				end
			end

			// A VSYNC triggers a delay action of 2 HSYNCs in the GA
			// In both cases the following interrupt requests are synchronised with the VSYNC. 
			if (~old_vsync & crtc_vs) line_delay <= 1;
		end
		
		// the interrupt request remains active until the Z80 acknowledges it.
		//	http://cpctech.cpc-live.com/docs/ints.html
		if (INTack) begin
			// When the interrupt is acknowledged, this is sensed by the Gate-Array. The top bit (bit 5),
			// of the counter is set to "0" and the interrupt request is cleared.
			// This prevents the next interrupt from occuring closer than 32 HSYNCs time. 
			// http://cpctech.cpc-live.com/docs/ints.html
			InterruptLineCount[5] <= 0;
			INT <= 0;
		end
		
		// InterruptLineCount begin
		// http://www.cpcwiki.eu/index.php/Synchronising_with_the_CRTC_and_display
		if(WE) begin
			if (D[7] & ~D[6] & D[4]) begin
				// Grimware : if D[4] is set, then interrupt request is cleared and the 6-bit counter is reset to "0".
				// http://cpctech.cpc-live.com/docs/ints.html
				InterruptLineCount <= 0;
				INT <= 0;
			end
		end
	end
end

// vmode is applied after HSync
always @(posedge CLK) begin
	reg old_hsync, old_hsync2;
	reg old_vsync;
	reg hsact;

	old_hsync2 <= HSYNC;
	old_hsync <= crtc_hs;
	if(~old_hsync & crtc_hs) hsact <= 1;
	if(hsact & ((old_hsync & ~crtc_hs) | (old_hsync2 & ~HSYNC))) begin
		vmode <= MODE_select; //standard vmode
		hsact <= 0;
	end

	old_vsync <= crtc_vs;
	if(~old_vsync & crtc_vs) vmode_fs <= MODE_select; //HQ2x friendly vmode
end

reg hs4,shift;
assign crtc_shift = shift ^ hs4;

// Generate HSync,VSync for monitor
// HSync: delayed by 2us for set, immediate reset and limited by 4us.
// VSync: delayed by 2 lines for set, immediate reset and limited by 2 lines.
always @(posedge CLK) begin
	reg       old_hsync;
	reg       old_vsync,old_vs;
	reg [8:0] hSyncCount;
	reg [9:0] hSyncCount2x;
	reg [8:0] hSyncSize;
	reg       hSyncReg;
	reg [3:0] vSyncCount;
	reg [1:0] syncs;
	reg [7:0] vSyncFlt;

	localparam HFLT_SZ = 50*4;
	localparam VFLT_SZ = 200;

	if(CE_4) begin
		old_hsync <= crtc_hs;

		if(resync) begin
			if(~&hSyncCount) hSyncCount = hSyncCount + 1'd1;
			if(~old_hsync & crtc_hs) old_vs <= crtc_vs;

			//re-align restored hsync to the first hsync of vsync
			if((~old_vs & crtc_vs & ~old_hsync & crtc_hs) || (hSyncCount >= hSyncSize)) begin
				hSyncCount = 0;
				if(~old_hsync & crtc_hs) hSyncReg <= 1;
			end
			
			// Calc line size from length of 2 first lines after VSync
			// 2 lines are needed to neutralize fake interlace video
			if(~&hSyncCount2x) hSyncCount2x = hSyncCount2x + 1'd1;
			if(~old_hsync & crtc_hs) begin
				if(~crtc_vs & ~&syncs) syncs = syncs + 1'd1;
				if(crtc_vs) {syncs,hSyncCount2x} = 0;
				if(syncs == 2) hSyncSize <= hSyncCount2x[9:1];
			end
		end
		else begin
			if(hSyncCount < HFLT_SZ) hSyncCount = hSyncCount + 1'd1;
			else if(~old_hsync & crtc_hs) begin
				hSyncCount = 0;
				hSyncReg <= 1;
			end
		end

		if(old_hsync & ~crtc_hs & hSyncReg) begin
			hSyncReg <= 0;
			if(hSyncCount > 7*4) hs4 <= 0;
			if((hSyncCount >= 4*4-1) && (hSyncCount < 6*4-1)) begin
				if(hSyncCount == 4*4-1) hs4 <= 1;
				shift <= 1;
			end
		end

		if(hSyncCount == 2*4) begin
			HSYNC <= 1;
			shift <= 0;
			old_vsync <= crtc_vs;
			
			if(~&vSyncFlt) vSyncFlt <= vSyncFlt + 1'd1;

			if(crtc_vs) begin
				if(~old_vsync && (vSyncFlt > VFLT_SZ)) begin
					vSyncCount = 0;
					vSyncFlt <= 0;
				end
				else if(~&vSyncCount) vSyncCount = vSyncCount + 1'd1;
			end
			
			if(vSyncCount == 1) VSYNC <= 1;
			if(!vSyncCount || (vSyncCount == 3)) VSYNC <= 0;
		end

		//force VSYNC disable earlier
		if(~crtc_vs) VSYNC <= 0;

		if(hSyncCount == 6*4) HSYNC <= 0;
	end
end

reg  [1:0] vmode, vmode_fs;
reg  [23:0] rgb;

wire [23:0] palette[64] = '{
	//GA palette
	'h6E7D6B,'h6E7B6D,'h00F36B,'hF3F36D,
	'h00026B,'hF00268,'h007868,'hF37D6B,
	'hF30268,'hF3F36B,'hF3F30D,'hFFF3F9,
	'hF30506,'hF302F4,'hF37D0D,'hFA80F9,
	'h000268,'h02F36B,'h02F001,'h0FF3F2,
	'h000000,'h0C02F4,'h027801,'h0C7BF4,
	'h690268,'h71F36B,'h71F504,'h71F3F4,
	'h6C0201,'h6C02F2,'h6E7B01,'h6E7BF6,

	//ASIC palette
	'h686764,'h666662,'h04f562,'hfdf563,
	'h050663,'hFF0764,'h046764,'hfd6763,
	'hfb0562,'hfbf361,'hfef504,'hfdf5f0,
	'hFD0704,'hFD07F2,'hfd6704,'hfd67f1,
	'h03045e,'h03f361,'h04f502,'h04f5f1,
	'h000000,'h0507f1,'h046703,'h0567f1,
	'h680764,'h68f564,'h68f500,'h68f5f1,
	'h670600,'h6807F1,'h686704,'h6867f1
};

assign {RED,GREEN,BLUE} = (VBLANK | VBLANK) ? 24'h000000 : rgb;

always @(posedge CLK) begin

	localparam  BEGIN_VBORDER = 4 * 8 - 2;
	localparam  END_VBORDER = 37 * 8 + 6;

	localparam  BEGIN_HBORDER = 12 * 16;
	localparam  END_HBORDER = 60 * 16;

	reg [2:0] cycle;
	reg[15:0] data;
	reg [1:0] de;
	reg       vs,old_vs;
	reg       hs,old_hs;

	integer   vborder;
	integer   hborder;

	CE_PIX <= 0;
	CE_PIX_FS <= 0;
	if (CE_16) begin
		cycle = cycle + 1'd1;

		if (CE_4) begin
			if (phase == 0) begin
				data = vram_D;
				if(crtc_shift) data[7:0] = vram_D[15:8];
				cycle = 0;
				de = {de[0], crtc_de};
				vs = VSYNC;
				hs = HSYNC;
			end
			if (phase == 2) begin
				de[1] = de[0];
				data[7:0] = crtc_shift ? vram_D[7:0] : data[15:8];
			end
		end

		hborder = hborder + 1;
		old_hs <= hs;
		if (~old_hs & hs) begin
			hborder = 0;
			HBLANK <= 1;

			vborder = vborder + 1;
			old_vs <= vs;
			if(~old_vs & vs) begin
				vborder = 0;
				VBLANK <= 1;
			end
		end

		if(hborder == BEGIN_HBORDER) begin
			HBLANK <= 0;
			if(vborder == BEGIN_VBORDER) VBLANK <= 0;
		end
		
		if(hborder == END_HBORDER) begin
			HBLANK <= 1;
			if(vborder == END_VBORDER) VBLANK <= 1;
		end

		case(vmode_fs)
			2: CE_PIX_FS <= 1;
			1: CE_PIX_FS <= !cycle[0];
			0: CE_PIX_FS <= !cycle[1:0];
		endcase

		case(vmode)
			2: CE_PIX <= 1;
			1: CE_PIX <= !cycle[0];
			0: CE_PIX <= !cycle[1:0];
		endcase

		casex({de[crtc_shift],vmode})
			'b110: rgb <= palette[{PAL,pen[data[~cycle]]}];
			'b101: rgb <= palette[{PAL,pen[{data[{1'b0,~cycle[2:1]}],data[{1'b1,~cycle[2:1]}]}]}];
			'b100: rgb <= palette[{PAL,pen[{data[{2'b00,~cycle[2]}],data[{2'b10,~cycle[2]}],data[{2'b01,~cycle[2]}],data[{2'b11,~cycle[2]}]}]}];
			'b0xx: rgb <= palette[{PAL,border}];
		endcase
	end
end

endmodule
