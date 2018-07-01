//
//
// Copyright (c) 2018 Sorgelig
//
// This program is GPL v2+ Licensed.
//
//
////////////////////////////////////////////////////////////////////////////////////////////////////////

module color_mix
(
	input            clk_vid,
	input            ce_pix,
	input      [2:0] mono,

	input      [1:0] R_in,
	input      [1:0] G_in,
	input      [1:0] B_in,
	input            HSync_in,
	input            VSync_in,
	input            HBlank_in,
	input            VBlank_in,

	output reg [7:0] R_out,
	output reg [7:0] G_out,
	output reg [7:0] B_out,
	output reg       HSync_out,
	output reg       VSync_out,
	output reg       HBlank_out,
	output reg       VBlank_out
);

wire [7:0] rw[3:0] = '{8'd054, 8'd036, 8'd018, 8'd000};
wire [7:0] gw[3:0] = '{8'd183, 8'd122, 8'd061, 8'd000}; 
wire [7:0] bw[3:0] = '{8'd018, 8'd012, 8'd006, 8'd000};
wire [7:0] px = rw[R_in] + gw[G_in] + bw[B_in];

always @(posedge clk_vid) begin
	if(ce_pix) begin
		if(!mono) begin
			R_out <= {4{R_in}};
			G_out <= {4{G_in}};
			B_out <= {4{B_in}};
		end else begin
			{R_out, G_out, B_out} <= 0;
			case(mono)
				      1: G_out <= px;
				      2: R_out <= px;
				      3: B_out <= px;
				default: {R_out, G_out, B_out} <= {px,px,px};
			endcase
		end
		
		HSync_out  <= HSync_in;
		VSync_out  <= VSync_in;
		HBlank_out <= HBlank_in;
		VBlank_out <= VBlank_in;
	end
end

endmodule
