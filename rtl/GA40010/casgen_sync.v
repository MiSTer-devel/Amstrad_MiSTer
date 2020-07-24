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


module casgen_sync (
	input  clk,
	input  cen_16,
	input  RESET_N,
	input  M1_N,
	input  PHI_N,
	input  MREQ_N,
	input [7:0] S,

	output CAS_N
);

///// CAS GENERATION /////

// Mask refresh from the end of the M1 cycle (the DRAM is refreshed by CRTC address generation)
reg U708; // 0 - MREQ_N is masked (active MREQ_N doesn't generate active CAS_N)
reg M1_N_d, MREQ_N_d;
always @(posedge clk) begin : edge_detect
	M1_N_d <= M1_N;
	MREQ_N_d <= MREQ_N;
end

always @(posedge clk, negedge RESET_N) begin : mask_refresh
	if (!RESET_N) U708 <= 1;
	else begin
		if (~M1_N_d & M1_N) U708 <= 0;
		else if (~MREQ_N_d & MREQ_N) U708 <= 1;
	end
end

reg S_d1_a; // u706
reg S_d2_a; // u709
always @(posedge clk) begin
	if (cen_16) begin
		// Video cycles
		S_d1_a <= (~S[4] & S[5]) | (~S[3] & S[1]) | (S[1] & S[7]);
		S_d2_a <= S_d1_a;
	end
end
wire U710 = ~U708 | MREQ_N | ~S[4] | S[5];

wire U712;
rslatch #(0) u712_l(clk, S_d1_a, ~(S[2] & U710), U712); // CPU cycle

assign CAS_N = U712 | S_d1_a | S_d2_a;

endmodule
