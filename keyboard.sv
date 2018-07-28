//============================================================================
//
// Keyboard for Amstrad CPC
// (c) 2018 Sorgelig
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
//============================================================================

module keyboard
(
	input        reset,
   input        clk,

   input [10:0] ps2_key,

   input  [5:0] joystick1,
   input  [5:0] joystick2,

   input  [3:0] Y,
   output [7:0] X,
   output reg   key_nmi
);

reg [7:0] key[16] = '{default:0};

wire [7:0] joy1 = (Y == 9) ? {2'b00, joystick1[5], joystick1[4], joystick1[0], joystick1[1], joystick1[2], joystick1[3]} : 8'h00;
wire [7:0] joy2 = (Y == 6) ? {2'b00, joystick2[5], joystick2[4], joystick2[0], joystick2[1], joystick2[2], joystick2[3]} : 8'h00;

assign X = ~(key[Y] | joy1 | joy2);

wire press = ps2_key[9];
always @(posedge clk) begin
	reg old_flg, old_reset;

	old_flg <= ps2_key[10];
	old_reset <= reset;

	if(old_reset & ~reset) key <= '{default:0};

	if(old_flg ^ ps2_key[10]) begin

		if(ps2_key[7:0] == 8'h78) key_nmi <= press; // F11

		case(ps2_key[7:0])
			//  19: up right down 9 6 3 Enter(End)
			8'h75: key[0][0] <= press;
			8'h74: key[0][1] <= press;
			8'h72: key[0][2] <= press;
			8'h01: key[0][3] <= press;
			8'h0B: key[0][4] <= press;
			8'h04: key[0][5] <= press;
			8'h69: key[0][6] <= press;
			8'h7A: key[0][7] <= press;   

			//  18: left copy 7 8 5 1 2 0
			8'h6B: key[1][0] <= press;
			8'h70: key[1][1] <= press;
			8'h83: key[1][2] <= press;
			8'h0A: key[1][3] <= press;
			8'h03: key[1][4] <= press;
			8'h05: key[1][5] <= press;
			8'h06: key[1][6] <= press;
			8'h09: key[1][7] <= press;

			//  17: CLR, Enter 4 SHIFT_LEFT \ CRTL_LEFT
			8'h71: key[2][0] <= press;
			8'h5B: key[2][1] <= press; 
			8'h5A: key[2][2] <= press; 
			8'h5D: key[2][3] <= press; 
			8'h0C: key[2][4] <= press;
			8'h12: key[2][5] <= press;
			8'h59: key[2][6] <= press;
			8'h14: key[2][7] <= press;

			//  16: _(RShift) - @ P + : ? >
			8'h55: key[3][0] <= press;
			8'h4E: key[3][1] <= press;
			8'h54: key[3][2] <= press;
			8'h4D: key[3][3] <= press;
			8'h52: key[3][4] <= press;
			8'h4C: key[3][5] <= press;
			8'h4A: key[3][6] <= press;
			8'h49: key[3][7] <= press;   

			//  15: 0_ 9_ O I L K M <
			8'h45: key[4][0] <= press;
			8'h46: key[4][1] <= press;
			8'h44: key[4][2] <= press;
			8'h43: key[4][3] <= press;
			8'h4B: key[4][4] <= press;
			8'h42: key[4][5] <= press;
			8'h3A: key[4][6] <= press;
			8'h41: key[4][7] <= press;

			//  14: 8_ 7_ U Y H J N SPACE
			8'h3E: key[5][0] <= press;
			8'h3D: key[5][1] <= press;
			8'h3C: key[5][2] <= press;
			8'h35: key[5][3] <= press;
			8'h33: key[5][4] <= press;
			8'h3B: key[5][5] <= press;
			8'h31: key[5][6] <= press;
			8'h29: key[5][7] <= press;

			//  13: 6_ 5_ R T G F B V
			8'h36: key[6][0] <= press;
			8'h2E: key[6][1] <= press;
			8'h2D: key[6][2] <= press;
			8'h2C: key[6][3] <= press;
			8'h34: key[6][4] <= press;
			8'h2B: key[6][5] <= press;
			8'h32: key[6][6] <= press;
			8'h2A: key[6][7] <= press;

			//  12: 4_ 3_ E W S D C X
			8'h25: key[7][0] <= press;
			8'h26: key[7][1] <= press;
			8'h24: key[7][2] <= press;
			8'h1D: key[7][3] <= press;
			8'h1B: key[7][4] <= press;
			8'h23: key[7][5] <= press;
			8'h21: key[7][6] <= press;
			8'h22: key[7][7] <= press;

			//  11: 1_ 2_ ESC Q TAB A CAPSLOCK Z
			8'h16: key[8][0] <= press;
			8'h1E: key[8][1] <= press;
			8'h76: key[8][2] <= press;
			8'h15: key[8][3] <= press;
			8'h0D: key[8][4] <= press;
			8'h1C: key[8][5] <= press;
			8'h58: key[8][6] <= press;
			8'h1A: key[8][7] <= press;

			//  2: DEL
			8'h66: key[9][7] <= press;
		endcase
	end
end

endmodule
