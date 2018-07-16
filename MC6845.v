`timescale 1 ns / 1 ns

//  BBC Micro for Altera DE1
//
//  Copyright (c) 2011 Mike Stirling
//
//  All rights reserved
//
//  Redistribution and use in source and synthezised forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//
//  * Redistributions in synthesized form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
//  * Neither the name of the author nor the names of other contributors may
//    be used to endorse or promote products derived from this software without
//    specific prior written agreement from the author.
//
//  * License is granted for non-commercial use only.  A fee may not be charged
//    for redistributions as source code or in synthesized/hardware form without
//    specific prior written agreement from the author.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  MC6845 CRTC
//
//  Synchronous implementation for FPGA
//
//  (C) 2011 Mike Stirling
//
// Corrected cursor flash rate
// Fixed incorrect positioning of cursor when over left most character
// Fixed timing of VSYNC
// Fixed interlaced timing (add an extra line)
// Implemented r05_v_total_adj
// Implemented delay parts of r08_interlace (see Hitacht HD6845SP datasheet)
//
// (C) 2017 David Banks
// 
//------------------------------------------------------------------------------
// 
// CPC Adaptation
//
// Fix, Split, Implement Type 0/1 specific quirks
//
// (C) 2018 Sorgelig
//
//

module MC6845
(
   input            CLOCK,
   input            CLKEN,
   input            nRESET,
	input            CRTC_TYPE,

   input            ENABLE,
   input            nCS,
   input            R_nW,
   input            RS,
   input      [7:0] DI,
   output reg [7:0] DO,
	
   output           VSYNC,
   output           HSYNC,
   output           DE,
   output           CURSOR,
   input            LPSTB,
   output reg[13:0] MA,
   output reg [4:0] RA
);

//  Memory interface
reg [4:0]     addr_reg;
//  Currently addressed register

//  These are write-only
reg [7:0]     r00_h_total;
//  Horizontal total, chars
reg [7:0]     r01_h_displayed;
//  Horizontal active, chars
reg [7:0]     r02_h_sync_pos;
//  Horizontal sync position, chars
reg [3:0]     r03_v_sync_width;
//  Vertical sync width, scan lines (0=16 lines)
reg [3:0]     r03_h_sync_width;
//  Horizontal sync width, chars (0=no sync)
reg [6:0]     r04_v_total;
//  Vertical total, character rows
reg [4:0]     r05_v_total_adj;
//  Vertical offset, scan lines
reg [6:0]     r06_v_displayed;
//  Vertical active, character rows
reg [6:0]     r07_v_sync_pos;
//  Vertical sync position, character rows
reg [7:0]     r08_interlace;
reg [4:0]     r09_max_scan_line;
reg [1:0]     r10_cursor_mode;
reg [4:0]     r10_cursor_start;
//  Cursor start, scan lines
reg [4:0]     r11_cursor_end;
//  Cursor end, scan lines
reg [5:0]     r12_start_addr_h;
reg [7:0]     r13_start_addr_l;

//  These are read/write
reg [5:0]     r14_cursor_h;
reg [7:0]     r15_cursor_l;

//  These are read-only
reg [5:0]     r16_light_pen_h;
reg [7:0]     r17_light_pen_l;

//  Timing generation
//  Horizontal counter counts position on line
reg [7:0]     h_counter;

//  HSYNC counter counts duration of sync pulse
reg [3:0]     h_sync_counter;

//  Row counter counts current character row
reg [6:0]     row_counter;

//  Line counter counts current line within each character row
reg [4:0]     line_counter;

//  VSYNC counter counts duration of sync pulse
reg [3:0]     v_sync_counter;

//  Field counter counts number of complete fields for cursor flash
reg [4:0]     field_counter;

//  Internal signals
reg           h_display;
reg           hs;
reg           v_display;
reg           vs;
reg           odd_field;
reg [13:0]    ma_i;
//  Start address of current character row
reg           cursor_i;
reg           lpstb_i;
reg [13:0]    ma_row_start;
reg [4:0]     max_scan_line;
reg [4:0]     adj_scan_line;
reg           in_adj;
reg           need_adj;
reg           cursor_line;

wire          de0;
reg           de1;
reg           de2;

wire          cursor0;
reg           cursor1;
reg           cursor2;


//  Internal cursor enable signal delayed by 1 clock to line up
//  with address outputs

assign HSYNC = hs;
//  External HSYNC driven directly from internal signal
assign VSYNC = vs;
//  External VSYNC driven directly from internal signal

assign de0 = h_display & v_display;

assign DE = ((r08_interlace[5:4] == 2'b00) | CRTC_TYPE) ? de0 :
				(r08_interlace[5:4] == 2'b01) ? de1 :
				(r08_interlace[5:4] == 2'b10) ? de2 :
				1'b0;

// Cursor output generated combinatorially from the internal signal in
// accordance with the currently selected cursor mode
assign cursor0 = (r10_cursor_mode == 2'b00) ? cursor_i :
					  (r10_cursor_mode == 2'b01) ? 1'b0 :
					  (r10_cursor_mode == 2'b10) ? (cursor_i & field_counter[3]) :
					  (cursor_i & field_counter[4]);

assign CURSOR = ((r08_interlace[7:6] == 2'b00) | CRTC_TYPE) ? cursor0 :
					 (r08_interlace[7:6] == 2'b01) ? cursor1 :
					 (r08_interlace[7:6] == 2'b10) ? cursor2 :
					 1'b0;

//  Synchronous register access.  Enabled on every clock.

always @(posedge CLOCK) begin

	if (~nRESET) begin
		//  Reset registers to defaults
		addr_reg <= 0;
		r00_h_total <= 0;
		r01_h_displayed <= 0;
		r02_h_sync_pos <= 0;
		r03_v_sync_width <= 0;
		r03_h_sync_width <= 0;
		r04_v_total <= 0;
		r05_v_total_adj <= 0;
		r06_v_displayed <= 0;
		r07_v_sync_pos <= 0;
		r08_interlace <= 0;
		r09_max_scan_line <= 0;
		r10_cursor_mode <= 0;
		r10_cursor_start <= 0;
		r11_cursor_end <= 0;
		r12_start_addr_h <= 0;
		r13_start_addr_l <= 0;
		r14_cursor_h <= 0;
		r15_cursor_l <= 0;
		DO <= 8'hFF;
	end
	else begin
		if (ENABLE & ~nCS) begin
			if (R_nW) begin

				//  Read
				if (~RS) DO <= ~CRTC_TYPE ? 8'hFF : v_display ? 8'h20 : 8'h00; // status
				else begin
					case (addr_reg)
							10: DO <= {r10_cursor_mode, r10_cursor_start};
							11: DO <= r11_cursor_end;
							12: DO <= CRTC_TYPE ? 8'h00 : r12_start_addr_h;
							13: DO <= CRTC_TYPE ? 8'h00 : r13_start_addr_l;
							14: DO <= r14_cursor_h;
							15: DO <= r15_cursor_l;
							16: DO <= r16_light_pen_h;
							17: DO <= r17_light_pen_l;
							31: DO <= CRTC_TYPE ? 8'hFF : 8'h00;
					 default: DO <= 0;
					endcase
				end
			end
			else begin
				//  Write
				if (~RS) addr_reg <= DI[4:0];
				else begin
					case (addr_reg)
						00: r00_h_total <= DI;
						01: r01_h_displayed <= DI;
						02: r02_h_sync_pos <= DI;
						03: begin
								r03_v_sync_width <= DI[7:4];
								r03_h_sync_width <= DI[3:0];
							end
						04: r04_v_total <= DI[6:0];
						05: r05_v_total_adj <= DI[4:0];
						06: r06_v_displayed <= DI[6:0];
						07: r07_v_sync_pos <= DI[6:0];
						08: r08_interlace <= 0; //DI[7:0];
						09: r09_max_scan_line <= DI[4:0];
						10: begin
								r10_cursor_mode <= DI[6:5];
								r10_cursor_start <= DI[4:0];
							end
						11: r11_cursor_end <= DI[4:0];
						12: r12_start_addr_h <= DI[5:0];
						13: r13_start_addr_l <= DI[7:0];
						14: r14_cursor_h <= DI[5:0];
						15: r15_cursor_l <= DI[7:0];
					endcase
				end
			end
		end
		else begin
			DO <= 8'hFF;
		end
	end
end

//  registers
always @(posedge CLOCK) begin
	reg [13:0] ma_next_start;

	if (~nRESET) begin

		//  H
		h_counter <= 0;

		//  V
		line_counter <= 0;
		row_counter <= 0;
		odd_field <= 0;

		//  Fields (cursor flash)
		field_counter <= 0;

		//  Addressing
		ma_row_start = 0;
		ma_i <= 0;
		in_adj <= 0;
	end
	else if (CLKEN) begin

		//  Horizontal counter increments on each clock, wrapping at
		//  h_total. CRTC0: 0 -> non-stop
		if ((h_counter == r00_h_total) && (CRTC_TYPE || r00_h_total)) begin

			//  h_total reached
			h_counter <= 0;

			// Compute
			need_adj = (r05_v_total_adj != 0) | odd_field;

			// Compute the max scan line for this row
			if (~in_adj) begin
				// This is a normal row, so use r09_max_scan_line
				max_scan_line = r09_max_scan_line;
			end else begin
				// This is the "adjust" row, so use r05_v_total_adj
				max_scan_line = r05_v_total_adj - 1'd1;
				// If interlaced, the odd field contains an additional scan line
				if (odd_field)
				  if (r08_interlace[1:0] == 2'b11)
					 max_scan_line = max_scan_line + 2'd2;
				  else
					 max_scan_line = max_scan_line + 1'd1;
			end
			// In interlace sync + video mode mask off the LSb of the
			// max scan line address
			if (r08_interlace[1:0] == 2'b11) max_scan_line[0] = 1'b0;

			if ((line_counter >= max_scan_line) & ((!need_adj & (row_counter >= r04_v_total)) | in_adj)) begin

				//  Next character row
				//  FIXME: No support for v_total_adj yet
				line_counter <= 0;

				// If in interlace mode we toggle to the opposite field.
				// Save on some logic by doing this here rather than at the
				// end of v_total_adj - it shouldn't make any difference to the
				// output
				odd_field <= (r08_interlace[0]) ? !odd_field : 1'b0;

				// Address is loaded from start address register at the top of
				// each field and the row counter is reset
				ma_row_start = {r12_start_addr_h, r13_start_addr_l};
				row_counter <= 0;

				// Increment field counter
				field_counter <= field_counter + 1'd1;

				// Reset the in extra time flag
				in_adj <= 0;

			end else if (!in_adj & (line_counter >= max_scan_line)) begin
				// Scan line counter increments, wrapping at max_scan_line_addr
				// Next character row
				line_counter <= 0;
				// On all other character rows within the field the row start address is
				// increased by h_displayed and the row counter is incremented
				ma_row_start = ma_next_start;
				row_counter <= row_counter + 1'd1;
				// Test if we are entering the adjust phase, and set
				// in_adj accordingly
				if (row_counter >= r04_v_total & need_adj) in_adj <= 1'b1;
			end
			else begin
			  //  Next scan line.  Count in twos in interlaced sync+video mode
				if (r08_interlace[1:0] == 2'b11) begin
					line_counter <= line_counter + 2'd2;
					line_counter[0] <= 0;
					//  Force to even
				end
				else begin
					line_counter <= line_counter + 1'd1;
				end
			end

			//  Memory address preset to row start at the beginning of each
			//  scan line
			ma_i <= ma_row_start;
			ma_next_start <= ma_row_start;
		end
		else begin
			// Increment horizontal counter
			h_counter <= h_counter + 1'd1;

			// Increment memory address
			ma_i <= ma_i + 1'd1;

			// ma_row_start won't be updated if h_displayed is not reached!
			if((h_counter + 1'd1) == r01_h_displayed) ma_next_start <= ma_row_start + r01_h_displayed;
		end
	end
end


//  Video timing and sync counters
always @(posedge CLOCK) begin

	if (~nRESET) begin

		//  H
		h_display <= 0;
		hs <= 0;
		h_sync_counter <= 0;

		//  V
		v_display <= 0;
		vs <= 0;
		v_sync_counter <= 0;
	end
	else if (CLKEN) begin

		//  Horizontal active video
		if(h_counter == 0) h_display <= 1;
		if(h_counter == r01_h_displayed) h_display <= 0;

		//  Horizontal sync
		if ((h_counter == r02_h_sync_pos) || hs) begin

			//  In horizontal sync
			hs <= 1;
			h_sync_counter <= h_sync_counter + 1'd1;
		end
		else begin
			h_sync_counter <= 0;
		end

		if (h_sync_counter == r03_h_sync_width) begin

			//  Terminate hsync after h_sync_width (0 means no hsync so this
			//  can immediately override the setting above)
			hs <= 0;
		end

		//  Vertical active video
		if(row_counter == 0) v_display <= 1;
		if(row_counter == r06_v_displayed) v_display <= 0;

		//  Vertical sync occurs either at the same time as the horizontal sync (even fields)
		//  or half a line later (odd fields)
		if ((~odd_field & (h_counter == 0)) | (odd_field & (h_counter == {1'b0, r00_h_total[7:1]}))) begin
			if (((row_counter == r07_v_sync_pos) & (line_counter == 0)) | vs) begin
				//  In vertical sync
				vs <= 1;
				v_sync_counter <= v_sync_counter + 1'd1;
			end
			else begin
				v_sync_counter <= 0;
			end

			if ((v_sync_counter == (CRTC_TYPE ? 4'd0 : r03_v_sync_width)) & vs) begin

				//  Terminate vsync after v_sync_width (0 means 16 lines so this is
				//  masked by 'vs' to ensure a full turn of the counter in this case)
				vs <= 0;
			end
		end
	end
end

//  Address generation
always @(posedge CLOCK) begin
	if (~nRESET) begin
		RA <= 0;
		MA <= 0;
	end
	else if (CLKEN) begin

		//  Character row address is just the scan line counter delayed by
		//  one clock to line up with the syncs.
		if (r08_interlace[1:0] == 2'b11) begin

			//  In interlace sync and video mode the LSb is determined by the
			//  field number.  The line counter counts up in 2s in this case.
			RA <= {line_counter[4:1], (line_counter[0] | odd_field)};
		end
		else begin
			RA <= line_counter;
		end

		//  Internal memory address delayed by one cycle as well
		MA <= ma_i;
	end
end

//  Cursor control
always @(posedge CLOCK) begin

	if (~nRESET) begin
		cursor_i <= 0;
		cursor_line = 0;
	end
	else if (CLKEN) begin
		if ((h_counter < r01_h_displayed) & (row_counter < r06_v_displayed) & (ma_i == {r14_cursor_h, r15_cursor_l})) begin
			if (line_counter == 0) begin

				//  Suppress wrap around if last line is > max scan line
				cursor_line = 0;
			end

			if (line_counter === r10_cursor_start) begin

				//  First cursor scanline
				cursor_line = 1;
			end

			//  Cursor output is asserted within the current cursor character
			//  on the selected lines only
			cursor_i <= cursor_line;
			if (line_counter == r11_cursor_end) begin

				//  Last cursor scanline
				cursor_line = 0;
			end

			//  Cursor is off in all character positions apart from the
			//  selected one
		end
		else begin
			cursor_i <= 0;
		end
	end
end

//  Light pen capture
//  Host-accessible registers
always @(posedge CLOCK) begin

	if (~nRESET) begin
		lpstb_i <= 0;
		r16_light_pen_h <= 0;
		r17_light_pen_l <= 0;
	end
	else if (CLKEN) begin

		//  Register light-pen strobe input
		lpstb_i <= LPSTB;

		if (LPSTB & ~lpstb_i) begin
			//  Capture address on rising edge
			r16_light_pen_h <= ma_i[13:8];
			r17_light_pen_l <= ma_i[7:0];
		end
	end
end

// Delayed CURSOR and DE (selected by R08)
always @(posedge CLOCK) begin
	if (CLKEN) begin
		de1     <= de0;
		de2     <= de1;
		cursor1 <= cursor0;
		cursor2 <= cursor1;
	end
end

endmodule
