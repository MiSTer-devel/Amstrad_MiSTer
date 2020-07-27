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


module casgen (
	input  clk_16,
	input  RESET_N,
	input  M1_N,
	input  PHI_N,
	input  MREQ_N,
	input [7:0] S,

	output CAS_N
);

///// CAS GENERATION /////

reg M1_N_d; // u705;
reg U708;
always @(posedge PHI_N) M1_N_d <= M1_N;
wire m1_n_rise = ~M1_N | M1_N_d; // u707

always @(posedge MREQ_N, negedge RESET_N, negedge m1_n_rise) if (~RESET_N) U708 <= 1; else if (~m1_n_rise) U708 <= 0; else U708 <= 1;

reg S_d1_a; // u706
reg S_d2_a; // u709
always @(posedge clk_16) begin
	S_d1_a <= (~S[4] & S[5]) | (~S[3] & S[1]) | (S[1] & S[7]);
	S_d2_a <= S_d1_a;
end
wire U710 = ~U708 | MREQ_N | ~S[4] | S[5];
/* verilator lint_off UNOPTFLAT */
wire U712 = U710 & S[2] & (S_d1_a | U712);
/* verilator lint_on UNOPTFLAT */
assign CAS_N = U712 | S_d1_a | S_d2_a;

endmodule
