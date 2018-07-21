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
   
   output           cyc1MHz,
   
   output reg       INT,
   input            crtc_vs,
   input            crtc_hs,
   input            crtc_de,
   input     [15:0] vram_D,
   
   input            INTack,
   input      [7:0] D,
   input            WE,
   
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


assign cyc1MHz = (phase1MHz == 0);
reg [1:0] phase1MHz;
always @(posedge CLK) if(CE_4) phase1MHz <= phase1MHz + 1'd1;

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
		if (CE_4 && phase1MHz == 3) begin
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
	reg old_hsync;
	reg old_vsync;

	old_hsync <= crtc_hs;
	if(old_hsync & ~crtc_hs) vmode <= MODE_select; //standard vmode

	old_vsync <= crtc_vs;
	if(~old_vsync & crtc_vs) vmode_fs <= MODE_select; //HQ2x friendly vmode
end

// Generate HSync,VSync for monitor
// HSync delayed by 2us and limited by 4us.
// VSync delayed by 2 lines and limited by 2 lines.
always @(posedge CLK) begin
	reg [2:0] monitor_hsync;
	reg [2:0] monitor_vsync;
	reg [2:0] monitor_vhsync;

	reg       old_hsync;
	reg       old_vsync;
	reg [3:0] hSyncCount;
	reg [3:0] vSyncCount;

	if (CE_4 && phase1MHz == 1) begin
		old_hsync <= crtc_hs;

		monitor_hsync[2:1] <= monitor_hsync[1:0];

		if (~old_hsync & crtc_hs) begin
			hSyncCount <= 0;
			monitor_hsync[0] <= 1;
		end              // should be 6, but 5 gives better screen centering
		else if (~crtc_hs || hSyncCount == 5) monitor_hsync <= 0;
		else hSyncCount <= hSyncCount + 1'd1;

		if (~old_hsync & crtc_hs) begin
			old_vsync <= crtc_vs;

			{monitor_vhsync[0],monitor_vsync[1]} <= monitor_vsync[1:0];
			if (~old_vsync & crtc_vs) begin
				vSyncCount <= 0;
				monitor_vsync[0] <= 1;
			end
			else if (~crtc_vs || vSyncCount == 4) monitor_vsync <= 0;
			else vSyncCount <= vSyncCount + 1'd1;
		end

		monitor_vhsync[2:1] <= monitor_vhsync[1:0];
	end

	VSYNC <= monitor_vhsync[2];
	HSYNC <= monitor_hsync[2];
end

reg  [1:0] vmode, vmode_fs;
reg  [23:0] rgb;

/*
//ASIC palette
wire [23:0] palette[32] = '{
	'h686764,'h666662,'h04f562,'hfdf563,
	'h050663,'hFF0764,'h046764,'hfd6763,
	'hfb0562,'hfbf361,'hfef504,'hfdf5f0,
	'hFD0704,'hFD07F2,'hfd6704,'hfd67f1,
	'h03045e,'h03f361,'h04f502,'h04f5f1,
	'h000000,'h0507f1,'h046703,'h0567f1,
	'h680764,'h68f564,'h68f500,'h68f5f1,
	'h670600,'h6807F1,'h686704,'h6867f1
};
*/

//GA palette
wire [23:0] palette[32] = '{
	'h6E7D6B,'h6E7B6D,'h00F36B,'hF3F36D,
	'h00026B,'hF00268,'h007868,'hF37D6B,
	'hF30268,'hF3F36B,'hF3F30D,'hFFF3F9,
	'hF30506,'hF302F4,'hF37D0D,'hFA80F9,
	'h000268,'h02F36B,'h02F001,'h0FF3F2,
	'h000000,'h0C02F4,'h027801,'h0C7BF4,
	'h690268,'h71F36B,'h71F504,'h71F3F4,
	'h6C0201,'h6C02F2,'h6E7B01,'h6E7BF6
};

assign {RED,GREEN,BLUE} = (VBLANK | VBLANK) ? 24'h000000 : rgb;

always @(posedge CLK) begin

	localparam  BEGIN_VBORDER = 4 * 8 - 4;
	localparam  END_VBORDER = 37 * 8 + 4;

	localparam  BEGIN_HBORDER = 8 * 16;
	localparam  END_HBORDER = 56 * 16;

	reg [3:0] cycle;
	reg[15:0] data;
	reg       de;
	reg       vs,old_vs;
	reg       hs,old_hs;

	integer   vborder;
	integer   hborder;

	CE_PIX <= 0;
	CE_PIX_FS <= 0;
	if (CE_16) begin
		cycle = cycle + 1'd1;

		if (CE_4) begin
			if (phase1MHz == 0) begin
				data = vram_D;
				cycle = 0;
				de = crtc_de;
				vs = VSYNC;
				hs = HSYNC;
			end
		end

		hborder = hborder + 1;
		old_hs <= hs;
		if (old_hs & ~hs) begin
			hborder = 0;

			vborder = vborder + 1;
			old_vs <= vs;
			if(old_vs & ~vs) vborder = 0;
		end

		VBLANK <= (vborder < BEGIN_VBORDER || vborder >= END_VBORDER);
		HBLANK <= (hborder < BEGIN_HBORDER || hborder >= END_HBORDER);

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

		casex({de,vmode})
			'b110: rgb <= palette[pen[data[{cycle[3],~cycle[2:0]}]]];
			'b101: rgb <= palette[pen[{data[{cycle[3],1'b0,~cycle[2:1]}],data[{cycle[3],1'b1,~cycle[2:1]}]}]];
			'b100: rgb <= palette[pen[{data[{cycle[3],2'b00,~cycle[2]}],data[{cycle[3],2'b10,~cycle[2]}],data[{cycle[3],2'b01,~cycle[2]}],data[{cycle[3],2'b11,~cycle[2]}]}]];
			'b0xx: rgb <= palette[border];
		endcase
	end
end

endmodule
