// ====================================================================
//
//  Amstrad CPC Gate Array
//  Based on 40010-simplified_V03.pdf by Gerald
//
//  Copyright (C) 2020 Gyorgy Szombathelyi <gyurco@freemail.hu>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================


module ga40010 (
	input  clk,
	input  cen_16,
	input fast, // CPU won't WAIT
`ifdef VERILATOR
	input  clk_16,
`endif
	input  RESET_N,
	input [15:14] A,
	input [7:0] D,
	input  MREQ_N,
	input  M1_N,
	input  RD_N,
	input  IORQ_N,
	input  HSYNC_I,
	input  VSYNC_I,
	input  DISPEN,

	output CCLK,
	output CCLK_EN_P,
	output CCLK_EN_N,
	output reg PHI_N,
	output reg PHI_EN_N,
	output reg PHI_EN_P,

	output reg RAS_N,
	output CAS_N,
	output READY,
	output reg CASAD_N,
	output CPU_N,
	output MWE_N,
	output E244_N,
	output ROMEN_N,
	output RAMRD_N,
	output ROM,

	output [1:0] MODE,
	output HSYNC_O,
	output VSYNC_O,
	output SYNC_N,
	output reg INT_N,
	output VBLANK,

	output BLUE_OE_N,  // BLUE   50%
	output BLUE,       // BLUE  100%
	output GREEN_OE_N, // GREEN  50%
	output GREEN,      // GREN  100%
	output RED_OE_N,   // RED    50%
	output RED         // RED   100%
);

wire reset = ~RESET_N;

////// SEQUENCER ///////

reg [7:0] S;
wire U204 = (reset & ~M1_N & ~IORQ_N & ~RD_N) | (S[6] & ~S[7]);

`ifdef VERILATOR
reg [7:0] S_a;

always @(posedge clk_16) begin
	S_a[0] <= ~S_a[7];
	S_a[1] <= S_a[0] | U204;
	S_a[2] <= S_a[1] | U204;
	S_a[3] <= S_a[2] | U204;
	S_a[4] <= S_a[3] | U204;
	S_a[5] <= S_a[4] | U204;
	S_a[6] <= S_a[5] | U204;
	S_a[7] <= S_a[6];
end
`endif

always @(posedge clk) begin
	if (cen_16) begin
		S[0] <= ~S[7];
		S[1] <= S[0] | U204;
		S[2] <= S[1] | U204;
		S[3] <= S[2] | U204;
		S[4] <= S[3] | U204;
		S[5] <= S[4] | U204;
		S[6] <= S[5] | U204;
		S[7] <= S[6];
	end
end

///// SEQUENCER DECODE /////

`ifdef VERILATOR
reg PHI_N_a, RAS_N_a, CASAD_N_a;

always @(posedge clk_16) begin
	PHI_N_a <= (S[1] ^ S[3]) | (S[5] ^ S[7]);
	RAS_N_a <= (S[6] | ~S[2]) & S[0];
	CASAD_N_a <= RAS_N_a;
end
`endif

always @(posedge clk) begin
	if (cen_16) begin
		PHI_N <= (S[1] ^ S[3]) | (S[5] ^ S[7]);
		RAS_N <= (S[6] | ~S[2]) & S[0];
		CASAD_N <= RAS_N;
	end
end

assign PHI_EN_N = cen_16 & (S == 8'hc0 || S == 8'h03 || S == 8'h3f || S == 8'hfc);
assign PHI_EN_P = cen_16 & (S == 8'h00 || S == 8'h0f || S == 8'hff || S == 8'hf0);

`ifdef VERILATOR
/* verilator lint_off UNOPTFLAT */
wire   READY_a = (~CASAD_N_a & READY_a) | (S[3] & ~S[6]);
/* verilator lint_on UNOPTFLAT */
`endif
rslatch ready_l(clk, S[3] & ~S[6], CASAD_N, READY);

assign CPU_N = ~(S[1] & ~S[7]);
assign CCLK = ~(S[2] | S[5]);
assign CCLK_EN_P = cen_16 & (S == 8'he0);
assign CCLK_EN_N = cen_16 & (S == 8'h03);
assign MWE_N = ~(RD_N & S[0] & S[5]);
assign E244_N = ~(~IORQ_N & S[2] & S[3]);

///// CAS GENERATION /////

`ifdef VERILATOR
wire CAS_N_a;
casgen casgen(.*, .CAS_N(CAS_N_a));
`endif
casgen_sync casgen_sync(.*);

///// SYNC AND IRQ GEN /////

`ifdef VERILATOR
wire HSYNC_O_a, VSYNC_O_a, INT_N_a, HCNTLT28_a;
syncgen syncgen(.*, .VSYNC_O(VSYNC_O_a), .HSYNC_O(HSYNC_O_a), .INT_N(INT_N_a), .HCNTLT28(HCNTLT28_a));
wire MODE_SYNC = ~HSYNC_O;
`endif
wire HCNTLT28, mode_sync_en;
syncgen_sync syncgen_sync(.*);
assign VBLANK = HCNTLT28;

////// REGISTERS /////

reg  [4:0] inksel;
reg  [4:0] border;
reg  [4:0] inkr[16];
wire       irq_reset;
reg        hromen;
reg        lromen;
reg        mode1;
reg        mode0;

wire       reg_latch = (S[0] & S[7]) | (fast & ~E244_N);
wire       reg_sel   = reg_latch & ~IORQ_N & ~A[15] & A[14] & M1_N;
wire       ink_en    = reg_sel & ~D[7] & ~D[6];
wire       border_en = reg_sel & ~D[7] &  D[6] &  inksel[4];
wire       ctrl_en   = reg_sel &  D[7] & ~D[6];
wire       inkr_en   = reg_sel & ~D[7] &  D[6] & ~inksel[4];

assign     irq_reset = ctrl_en & D[4];

always @(posedge clk) begin
	if (ink_en) inksel <= D[4:0];
	if (reset) border <= 5'b10000; else if (border_en) border <= D[4:0];
	if (reset) {hromen, lromen, mode1, mode0} <= 0;
	else if (ctrl_en) {hromen, lromen, mode1, mode0} <= D[3:0];
	if (inkr_en) inkr[inksel[3:0]] <= D[4:0];
end

assign MODE = {mode1, mode0};

/////// ROM/RAM MAPPING /////////

wire rom = (~lromen & ~A[15] & ~A[14]) | (~hromen & A[15] & A[14]);
assign ROM = rom;
assign ROMEN_N = ~rom | MREQ_N | RD_N;
assign RAMRD_N =  rom | MREQ_N | RD_N;

////// VIDEO DATA BUFFER ///////

`ifdef VERILATOR
wire vidbuf_clk = S_a[3] | CAS_N_a;
reg DISPEN_BUF_a;
reg [7:0] VIDEO_BUF_a;
always @(posedge vidbuf_clk) begin
	DISPEN_BUF_a <= DISPEN;
	VIDEO_BUF_a <= D;
end
`endif

wire vidbuf_clk_en = cen_16 & (S == 8'he0 || S == 8'h03);
reg DISPEN_BUF;
reg [7:0] VIDEO_BUF;
always @(posedge clk) begin
	if (vidbuf_clk_en) begin
		DISPEN_BUF <= DISPEN;
		VIDEO_BUF <= D;
	end
end

//////// VIDEO CONTROL ////////

`ifdef VERILATOR
video video(
	.clk(clk_16),
	.cen_16(1'b1),
	.S(S_a),
	.DISPEN_BUF(DISPEN_BUF_a),
	.PHI_N(PHI_N_a),
	.MODE({mode1, mode0}),
	.MODE_SYNC(MODE_SYNC),
	.MODE_SYNC_EN(1'b1),
	.VIDEO(VIDEO_BUF_a),
	.BORDER(border),
	.INKR(inkr),
	.FORCE_BLANK(HCNTLT28 | HSYNC_I),
	.BLUE_OE_N(),
	.BLUE(),
	.GREEN_OE_N(),
	.GREEN(),
	.RED_OE_N(),
	.RED()
);
`endif

video video_sync(
	.clk(clk),
	.cen_16(cen_16),
	.S(S),
	.DISPEN_BUF(DISPEN_BUF),
	.PHI_N(PHI_N),
	.MODE({mode1, mode0}),
	.MODE_SYNC(clk),
	.MODE_SYNC_EN(mode_sync_en),
//	.MODE_SYNC(~HSYNC_O),
//	.MODE_SYNC_EN(1'b1),
	.VIDEO(VIDEO_BUF),
	.BORDER(border),
	.INKR(inkr),
	.FORCE_BLANK(HCNTLT28 | HSYNC_I),
	.BLUE_OE_N(BLUE_OE_N),
	.BLUE(BLUE),
	.GREEN_OE_N(GREEN_OE_N),
	.GREEN(GREEN),
	.RED_OE_N(RED_OE_N),
	.RED(RED)
);

endmodule
