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


module video (
	input  clk,
	input cen_16,
	input [7:0] S,
	input DISPEN_BUF,
	input PHI_N,
	input [1:0] MODE,
	input MODE_SYNC,
	input MODE_SYNC_EN,
	input [7:0] VIDEO,
	input [4:0]BORDER,
	input [4:0]INKR[16],
	input FORCE_BLANK, // u1801

	output reg BLUE_OE_N,
	output reg BLUE,
	output reg GREEN_OE_N,
	output reg GREEN,
	output reg RED_OE_N,
	output reg RED
);

//////// VIDEO CONTROL ////////

reg mode_is_0, mode_is_1, mode_is_2;
always @(posedge MODE_SYNC) begin
	if (MODE_SYNC_EN) begin
		mode_is_0 <= ~MODE[0] & ~MODE[1];
		mode_is_1 <=  MODE[0] & ~MODE[1];
		mode_is_2 <= ~MODE[0] &  MODE[1];
	end
end

reg load;
reg u1007, u1005, u1013;
reg colour_keep, ink_sel, border_sel, shift, keep;

wire u1008 = load ? DISPEN_BUF : u1005;
wire u1017 = mode_is_2 | (u1007 & u1013) | (mode_is_1 & u1013);

always @(posedge clk) begin
	if (cen_16) begin
		load <= S[5] ^ S[6];
		u1007 <= ~PHI_N;
		u1005 <= u1008;
		u1013 <= load | ~u1013;

		colour_keep <= ~(u1013 | mode_is_2);
		ink_sel <= (u1013 | mode_is_2) & u1008;
		border_sel <= (u1013 | mode_is_2) & ~u1008;

		shift <= u1017 & ~(S[5] ^ S[6]);
		keep <= ~u1017;
	end
end

///////// VIDEO SHIFT REGISTER ////////
reg [7:0] shift_reg;
wire [7:0] shift_out = { shift_reg[6:0], 1'b0 };
reg [7:0] shift_inp;
always @(*) begin
	for (integer i=0; i<8; i=i+1) begin
		shift_inp[i] = (shift & shift_out[i]) | (load & VIDEO[i]) | (keep & shift_reg[i]);
	end
end

always @(posedge clk) if (cen_16) shift_reg <= shift_inp;

wire [3:0] cidx = { shift_reg[1], shift_reg[5], shift_reg[3], shift_reg[7] };

//////////// COLOUR MUX ///////////////
wire [4:0] colour;

reg [15:0] ink_bits[5];
always @(*) begin
	for (integer i=0;i<16;i=i+1) begin
		ink_bits[0][i] = INKR[i][0];
		ink_bits[1][i] = INKR[i][1];
		ink_bits[2][i] = INKR[i][2];
		ink_bits[3][i] = INKR[i][3];
		ink_bits[4][i] = INKR[i][4];
	end
end

genvar i;
generate
	for (i=0; i<=4; i=i+1) begin : colour_mux
		color_bit_mux color_bit_mux (
			.clk(clk),
			.cen_16(cen_16),
			.COLOUR_KEEP(colour_keep),
			.BORDER_SEL(border_sel),
			.BORDER(BORDER[i]),
			.INK_SEL(ink_sel),
			.INKR(ink_bits[i]),
			.CIDX(cidx),
			.MODE_IS_0(mode_is_0),
			.MODE_IS_2(mode_is_2),
			.INK(colour[i])
		);
	end 
endgenerate

/////////// RGB DECODER ////////////

always @(posedge clk, posedge FORCE_BLANK) begin
	if (FORCE_BLANK) begin
		BLUE_OE_N <= 0;
		BLUE <= 0;
		GREEN_OE_N <= 0;
		GREEN <= 0;
		RED_OE_N <= 0;
		RED <= 0;
	end else if (cen_16) begin
		BLUE_OE_N <= ~((colour[1] | colour[2]) & (colour[3] | colour[4]));
		BLUE <= colour[0];
		GREEN_OE_N <= (colour[1] & colour[2]) | ~(colour[1] | colour[2] | colour[3] | colour[4]);
		GREEN <= (~colour[2] & colour[0]) | colour[1];
		RED_OE_N <= ~(colour[1] | colour[2] | colour[3] | colour[4]) | (colour[3] & colour[4]);
		RED <= (colour[0] & ~colour[4]) | colour[3];
	end
end

endmodule

/////// COLOR BIT MUX //////////////
module color_bit_mux (
	input clk,
	input cen_16,
	input COLOUR_KEEP,
	input BORDER_SEL,
	input BORDER,
	input INK_SEL,
	input [15:0] INKR,
	input [3:0] CIDX,
	input MODE_IS_0,
	input MODE_IS_2,

	output reg INK
);
wire u1301 = CIDX[2] & MODE_IS_0;
wire [3:0] ink_a = {
	(u1301 | INKR[1]) & (~u1301 | INKR[5]),
	(u1301 | INKR[3]) & (~u1301 | INKR[7]),
	(u1301 | INKR[0]) & (~u1301 | INKR[4]),
	(u1301 | INKR[2]) & (~u1301 | INKR[6]) };

wire [3:0] ink_b = {
	(u1301 | INKR[9]) & (~u1301 | INKR[13]),
	(u1301 | INKR[11]) & (~u1301 | INKR[15]),
	(u1301 | INKR[8]) & (~u1301 | INKR[12]),
	(u1301 | INKR[10]) & (~u1301 | INKR[14]) };

wire [3:0] ink_mux = (CIDX[3] & MODE_IS_0) ? ink_b : ink_a;

wire u1303 = CIDX[1] & ~MODE_IS_2;
wire u1318 = (u1303 | ink_mux[3]) & (~u1303 | ink_mux[2]);
wire u1319 = (u1303 | ink_mux[1]) & (~u1303 | ink_mux[0]);
wire u1320 = INK_SEL & CIDX[0] & u1318;
wire u1321 = INK_SEL & ~CIDX[0] & u1319;

always @(posedge clk) if (cen_16) INK <= (INK & COLOUR_KEEP) | (BORDER_SEL & BORDER) | u1320 | u1321;

endmodule
