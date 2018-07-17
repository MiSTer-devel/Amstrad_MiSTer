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
   output reg [1:0] RED,
   output reg [1:0] GREEN,
   output reg [1:0] BLUE,
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


assign cyc1MHz = !phase1MHz;
reg [1:0] phase1MHz;
always @(posedge CLK) if(CE_4) phase1MHz <= phase1MHz + 1'd1;

reg  [4:0] pen[15:0] = '{4,12,21,28,24,29,12,5,13,22,6,23,30,0,31,14};
reg  [4:0] border;
reg  [1:0] MODE_select;

always @(posedge CLK) begin
	reg [3:0] ink;
	reg       border_ink;
	reg [4:0] ink_color;
	reg [4:0] c_border;
	reg [4:0] c_inkc;
	reg [3:0] c_ink;

	if (RESET) MODE_select <= 2'b00;
	else begin
		if (CE_4) begin
			if (phase1MHz == 0 && WE) begin //7Fxx gate array --
				if (D[7:6] == 2'b10)	begin
					//http://www.cpctech.org.uk/docs/garray.html
					if (D[1:0] == 3) MODE_select <= 0;
					else MODE_select <= D[1:0];
				end
				else if (~D[7]) begin
					// palette
					if (~D[6]) begin
						border_ink = D[4];
						ink = D[3:0];
					end
					else begin
						ink_color = D[4:0];
						if (~border_ink) begin
							c_inkc = ink_color;
							c_ink = ink;
						end
						else c_border = ink_color;
					end
				end
			end

			if (phase1MHz == 2) begin
				pen[c_ink] <= c_inkc;
				border <= c_border;
			end
		end
	end
end

always @(posedge CLK) begin
	reg [5:0] InterruptLineCount;
	reg [1:0] InterruptSyncCount;
	reg       old_hsync;
	reg       old_vsync;

	if (RESET) begin
		InterruptLineCount = 0;
		InterruptSyncCount = 2;
		old_hsync = 0;
		old_vsync = 0;
		INT <= 0;
	end
	else begin

		// the interrupt request remains active until the Z80 acknowledges it.
		//	http://cpctech.cpc-live.com/docs/ints.html
		if (INTack) begin
			// When the interrupt is acknowledged, this is sensed by the Gate-Array. The top bit (bit 5),
			// of the counter is set to "0" and the interrupt request is cleared.
			// This prevents the next interrupt from occuring closer than 32 HSYNCs time. 
			// http://cpctech.cpc-live.com/docs/ints.html
			InterruptLineCount[5] = 0;
			INT <= 0;
		end
		
		// InterruptLineCount begin
		// http://www.cpcwiki.eu/index.php/Synchronising_with_the_CRTC_and_display
		if(WE) begin
			if (D[7] & ~D[6] & D[4]) begin
				InterruptLineCount = 0;
				// Grimware : if set (1), this will (only) reset the interrupt counter.
				// the interrupt request is cleared and the 6-bit counter is reset to "0".
				// http://cpctech.cpc-live.com/docs/ints.html
				INT <= 0;
			end
		end

		old_hsync <= crtc_hs;
		old_vsync <= crtc_vs;

		// The GA has a counter that increments on every falling edge of the CRTC generated HSYNC signal.
		// It triggers 6 interrupts per frame http://pushnpop.net/topic-452-1.html
		if (old_hsync & ~crtc_hs) begin
			InterruptLineCount = InterruptLineCount + 1'd1;
			if (InterruptLineCount == 52) begin	// Asphalt ? -- 52="110100"
				// Once this counter reaches 52, the GA raises the INT signal and resets the counter to 0.
				InterruptLineCount = 0;
				INT <= 1;
			end
			
			if (InterruptSyncCount < 2) begin
				InterruptSyncCount = InterruptSyncCount + 1'd1;
				if (InterruptSyncCount == 2) begin
					if (InterruptLineCount >= 32)	INT <= 1;
					InterruptLineCount = 0;
				end
			end

			vmode <= MODE_select;
		end
		
		// A VSYNC triggers a delay action of 2 HSYNCs in the GA
		// In both cases the following interrupt requests are synchronised with the VSYNC. 
		if (~old_vsync & crtc_vs) InterruptSyncCount = 0;
	end
end

reg vsync;
reg hsync;

always @(posedge CLK) begin

	reg [3:0] monitor_hsync;
	reg [3:0] monitor_vsync;
	reg [3:0] monitor_vhsync;

	reg       old_hsync;
	reg       old_vsync;
	reg [3:0] hSyncCount;
	reg [3:0] vSyncCount;

	begin
		if (CE_4 && phase1MHz == 1) begin
			monitor_hsync = {monitor_hsync[2:0], monitor_hsync[0]};

			if (~old_hsync & crtc_hs) begin
				hSyncCount = 0;
				monitor_hsync[0] = 1;
			end
			else if (old_hsync & ~crtc_hs) monitor_hsync = 0;
			else if (crtc_hs) begin
				hSyncCount = hSyncCount + 1'd1;
				if (hSyncCount == 5) monitor_hsync = 0;
			end

			if (~old_hsync & crtc_hs) begin
				monitor_vsync = {monitor_vsync[2:0], monitor_vsync[0]};
				if (~old_vsync & crtc_vs) begin
					vSyncCount = 0;
					monitor_vsync[0] = 1;
				end
				else if (old_vsync & ~crtc_vs) monitor_vsync = 0;
				else if (crtc_vs) begin
					vSyncCount = vSyncCount + 1'd1;
					if (vSyncCount == 4) monitor_vsync = 0;
				end

				old_vsync = crtc_vs;
			end

			old_hsync = crtc_hs;

			monitor_vhsync = {monitor_vhsync[2:0], monitor_vsync[2]};

			vsync <= monitor_vhsync[2];
			hsync <= monitor_hsync[2];
		end
	end
end

reg  [1:0] vmode;
reg  [5:0] rgb;
wire [5:0] palette[31:0] = '{ // RRGGBB
	6'b010111, 6'b010100, 6'b010011, 6'b010000,
	6'b011111, 6'b011100, 6'b011101, 6'b010001,
	6'b000111, 6'b000100, 6'b000011, 6'b000000,
	6'b001111, 6'b001100, 6'b001101, 6'b000001,
	6'b110111, 6'b110100, 6'b110011, 6'b110000,
	6'b111111, 6'b111100, 6'b111101, 6'b110001,
	6'b110101, 6'b000101, 6'b110001, 6'b000001,
	6'b111101, 6'b001101, 6'b010101, 6'b010101
};

assign {RED,GREEN,BLUE} = (VBLANK | VBLANK) ? 6'b000000 : rgb;

always @(posedge CLK) begin

	localparam  BEGIN_VBORDER = (8 - 4) * 8;		// OK validated 32
	localparam  END_VBORDER = (8 + 25 + 4) * 8;	// KO missing 4 chars OK corrected. 296
	// 64-46=18 carac16(2 carac) => 16 (????)
	// 296-32=296 296*2=528 720x528 does exists...
	
	localparam  BEGIN_HBORDER = (16 - 2 - 2 - 3) * 16;					// ko missing 3 char 144
	localparam  END_HBORDER = (16 + 40 + 2 - 4 + 2) * 16 + 8 + 8;	// OK but -8 cause one char too late 912
	// Not 720 : 904-144 = 760
	
	// 4*16*2+640=768
	// 912 - 144=768
	
	reg [2:0] cycle;
	reg [7:0] data;
	reg       de;
	reg       vs;
	reg       hs;

	reg       reset_vborder;
	integer   vborder;		// 304 max
	integer   hborder;		// 64*16 max

	begin
		CE_PIX <= 0;
		if (CE_16) begin
			cycle = cycle + 1'd1;
			
			if (CE_4) begin
				if (phase1MHz == 2) begin
					cycle = 0;
					de = crtc_de;
					data = vram_D[7:0];
					vs = vsync;
					hs = hsync;
				end
				else if (phase1MHz == 0) data = vram_D[15:8];
			end

			VSYNC <= vs;
			HSYNC <= hs;

			hborder = hborder + 1;
			if (~vs & VSYNC) reset_vborder = 1;
			if (~hs & HSYNC) begin
				hborder = 0;
				vborder = vborder + 1;
				if(reset_vborder) vborder = 0;
				reset_vborder = 0;
			end

			VBLANK <= (vborder < BEGIN_VBORDER || vborder >= END_VBORDER);
			HBLANK <= (hborder < BEGIN_HBORDER || hborder >= END_HBORDER);

			case(vmode)
				2: CE_PIX <= 1;
				1: CE_PIX <= !cycle[0];
				0: CE_PIX <= !cycle[1:0];
			endcase
			
			casex({de,vmode})
				'b110: rgb <= palette[pen[data[~cycle]]];
				'b101: rgb <= palette[pen[{data[{1'b0,~cycle[2:1]}],data[{1'b1,~cycle[2:1]}]}]];
				'b100: rgb <= palette[pen[{data[{2'b00,~cycle[2]}],data[{2'b10,~cycle[2]}],data[{2'b01,~cycle[2]}],data[{2'b11,~cycle[2]}]}]];
				'b0xx: rgb <= palette[border];
			endcase
		end
	end
end

endmodule
