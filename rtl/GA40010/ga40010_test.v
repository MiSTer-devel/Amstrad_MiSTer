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

module ga40010_test (
	input clk,
	input RESET_N,
	input [15:0] A,
	input [7:0] RAM_DIN,
	input [7:0] CPU_DIN,
	input MREQ_N,
	input M1_N,
	input RD_N,
	input WR_N,
	input IORQ_N,

	output reg CEN_16,
	output PHI_N,
	output PHI_EN_P,
	output PHI_EN_N,
	output READY,
	output INT_N,
	output RAS_N,
	output CAS_N,
	output CPU_N,
	output [15:1] VRAM_ADDR,

	output HSYNC,
	output VSYNC,
	output BLUE_OE_N,
	output BLUE,
	output GREEN_OE_N,
	output GREEN,
	output RED_OE_N,
	output RED
);


//// SIMULATION CLOCK GENERATOR
reg [1:0] div;
wire      clk_16 = div[1];

always @(posedge clk) begin
	div <= div + 1'd1;
	CEN_16 <= 0;
	if (div == 0) CEN_16 <= 1;
end

/// GA INSTANCE ////

wire CCLK_EN_P, CCLK_EN_N;
wire E244_N;
wire [7:0] D = E244_N ? RAM_DIN : CPU_DIN;

ga40010 ga40010 (
	.clk(clk),
	.cen_16(CEN_16),
	.clk_16(clk_16),
	.fast(0),
	.RESET_N(RESET_N),
	.A(A[15:14]),
	.D(D),
	.MREQ_N(MREQ_N),
	.M1_N(M1_N),
	.RD_N(RD_N),
	.IORQ_N(IORQ_N),
	.HSYNC_I(CRTC_HSYNC),
	.VSYNC_I(CRTC_VSYNC),
	.DISPEN(CRTC_DE),
	.CCLK(),
	.CCLK_EN_P(CCLK_EN_P),
	.CCLK_EN_N(CCLK_EN_N),
	.PHI_N(PHI_N),
	.PHI_EN_N(PHI_EN_N),
	.PHI_EN_P(PHI_EN_P),
	.RAS_N(RAS_N),
	.CAS_N(CAS_N),
	.READY(READY),
	.CASAD_N(),
	.CPU_N(CPU_N),
	.MWE_N(),
	.E244_N(E244_N),
	.ROMEN_N(),
	.RAMRD_N(),
	.HSYNC_O(HSYNC),
	.VSYNC_O(VSYNC),
	.SYNC_N(),
	.INT_N(INT_N),
	.BLUE_OE_N(BLUE_OE_N),
	.BLUE(BLUE),
	.GREEN_OE_N(GREEN_OE_N),
	.GREEN(GREEN),
	.RED_OE_N(RED_OE_N),
	.RED(RED),
	.VBLANK()
);

/// CRTC INSTANCE ///
wire io_rd = ~(RD_N | IORQ_N);
wire io_wr = ~(WR_N | IORQ_N);
wire [7:0] crtc_dout;
wire [13:0] MA;
wire [4:0] RA;
wire CRTC_HSYNC;
wire CRTC_VSYNC;
wire CRTC_DE;

assign VRAM_ADDR = {MA[13:12], RA[2:0], MA[9:0]};

UM6845R CRTC
(
	.CLOCK(clk),
	.CLKEN(CCLK_EN_N),
	.nRESET(RESET_N),
	.CRTC_TYPE(1'b0),

	.ENABLE(io_rd | io_wr),
	.nCS(A[14]),
	.R_nW(A[9]),
	.RS(A[8]),
	.DI(CPU_DIN),
	.DO(crtc_dout),

	.VSYNC(CRTC_VSYNC),
	.HSYNC(CRTC_HSYNC),
	.DE(CRTC_DE),
	.FIELD(),
	.CURSOR(),

	.MA(MA),
	.RA(RA)
);

endmodule
