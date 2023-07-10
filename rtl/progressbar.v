/*
	A simple progressbar overlay
*/

module progressbar (
	input        clk,
	input        ce_pix,
	input        HSync,
	input        VSync,
	input        enable,
	input  [6:0] progress, // 0-127
	output       pix
);

parameter X_OFFSET = 11'd200;
parameter Y_OFFSET = 11'd40;

// *********************************************************************************
// video timing and sync polarity anaylsis
// *********************************************************************************

// horizontal counter
reg  [10:0] h_cnt;
reg  [10:0] hs_low, hs_high;
wire        hs_pol = hs_high < hs_low;

// vertical counter
reg  [10:0] v_cnt;
reg  [10:0] vs_low, vs_high;
wire        vs_pol = vs_high < vs_low;

always @(posedge clk) begin
	reg hsD;
	reg vsD;

	if(ce_pix) begin
		// bring hsync into local clock domain
		hsD <= HSync;

		// falling edge of HSync
		if(!HSync && hsD) begin
			h_cnt <= 0;
			hs_high <= h_cnt;
		end

		// rising edge of HSync
		else if(HSync && !hsD) begin
			h_cnt <= 0;
			hs_low <= h_cnt;
			v_cnt <= v_cnt + 1'd1;
		end else begin
			h_cnt <= h_cnt + 1'd1;
		end

		vsD <= VSync;

		// falling edge of VSync
		if(!VSync && vsD) begin
			v_cnt <= 0;
			// if the difference is only one line, that might be interlaced picture
			if (vs_high != v_cnt + 1'd1) vs_high <= v_cnt;
		end

		// rising edge of VSync
		else if(VSync && !vsD) begin
			v_cnt <= 0;
			// if the difference is only one line, that might be interlaced picture
			if (vs_low != v_cnt + 1'd1) vs_low <= v_cnt;
		end
	end
end

// area in which OSD is being displayed
wire [10:0] h_osd_start = X_OFFSET;
wire [10:0] h_osd_end   = h_osd_start + 8'd132;
wire [10:0] v_osd_start = Y_OFFSET;
wire [10:0] v_osd_end   = v_osd_start + 8'd8;

wire [10:0] osd_hcnt    = h_cnt - h_osd_start;
wire  [3:0] osd_vcnt    = v_cnt - v_osd_start;
reg         osd_de;
reg         osd_pixel;

always @(posedge clk) begin
	if(ce_pix) begin
		case (osd_vcnt)
		0,7: osd_pixel <= 1;
		2,3,4,5: osd_pixel <= osd_hcnt == 0 || osd_hcnt == 130 || ((osd_hcnt - 2'd2) < progress);
		default: osd_pixel <= osd_hcnt == 0 || osd_hcnt == 130;
		endcase

		osd_de <=
		    (HSync != hs_pol) && (h_cnt >= h_osd_start) && ((h_cnt + 1'd1) < h_osd_end) &&
		    (VSync != vs_pol) && (v_cnt >= v_osd_start) && (v_cnt < v_osd_end);
	end
end

assign pix = enable & osd_pixel & osd_de;

endmodule
