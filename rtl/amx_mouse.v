////////////////////////////////////////////////////////////////////////////////
//
//  PS2-to-AMX Mouse v2
//  (C) 2025 Sorgelig
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
////////////////////////////////////////////////////////////////////////////////

module amx_mouse
(
	input        clk_sys,
	input        reset,

	input [24:0] ps2_mouse,
	
	input        sel,
	output [6:0] dout
);

assign dout = data;
reg [6:0] data;

reg [11:0] dx;
reg [11:0] dy;

always @(posedge clk_sys) begin
	reg old_sel, old_stb;
	
	data[6:4] <= {ps2_mouse[2],ps2_mouse[0],ps2_mouse[1]};

	old_stb <= ps2_mouse[24];
	if(old_stb != ps2_mouse[24]) begin
		dx <= dx + {{4{ps2_mouse[4]}},ps2_mouse[15:8]};
		dy <= dy + {{4{ps2_mouse[5]}},ps2_mouse[23:16]};
	end
	else begin
		if(!data[1:0] && dx) begin
			if(dx[11]) begin
				data[1:0] <= 2'b10;
				dx <= ($signed(dx) > -12'd4) ? 12'd0 : (dx+12'd4);
			end
			else begin
				data[1:0] <= 2'b01;
				dx <= ($signed(dx) <  12'd4) ? 12'd0 : (dx-12'd4);
			end
		end

		if(!data[3:2] && dy) begin
			if(dy[11]) begin
				data[3:2] <= 2'b01;
				dy <= ($signed(dy) > -12'd4) ? 12'd0 : (dy+12'd4);
			end
			else begin
				data[3:2] <= 2'b10;
				dy <= ($signed(dy) <  12'd4) ? 12'd0 : (dy-12'd4);
			end
		end
	end

	old_sel <= sel;
	if(old_sel & ~sel) data <= 0;

	if(reset) {data,dx,dy} <= 0;
end


endmodule
