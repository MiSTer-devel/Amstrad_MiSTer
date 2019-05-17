//
// Tape implementation for Amstrad CPC
// Copyright (c) 2018 Sorgelig
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
///////////////////////////////////////////////////////////////////////////////

module tape #(parameter CLOCK)
(
	input         clk_sys,
	input         ce,

	input         key_pause,
	input         key_play,
	input         tape_motor,

	output        led,
	output reg    active,
	output reg    available,

	input         tape_ready,
	input  [24:0] tape_size,

	output reg    audio_out,

	input         rd_en,
	output        rd,
	output [24:0] addr,
	input   [7:0] din
);

assign led  = act_cnt[24] ? act_cnt[23:16] > act_cnt[7:0] : act_cnt[23:16] <= act_cnt[7:0];
assign rd   = ~read_done;
assign addr = size - read_cnt;

reg [24:0] act_cnt;
always @(posedge clk_sys) if(active || ~(available ^ act_cnt[24]) || act_cnt[23:0]) act_cnt <= act_cnt + 1'd1;

reg  [24:0] read_cnt;
reg         read_done;
reg   [7:0] data;
reg  [24:0] size;

localparam MOTOR_TIMEOUT = CLOCK/20;

always @(posedge clk_sys) begin
	reg old_kpause, old_kplay, old_ready, old_rden;

	reg        pause;
	reg  [5:0] hdrsz;
	reg [31:0] bitcnt,tmp;
	reg [15:0] freq;
	reg  [2:0] reload32;
	reg [31:0] clk_play_cnt;
	reg  [7:0] din_r;

	reg        old_motor;
	reg [31:0] clk_motor_cnt;
	reg        motor_r;
	reg        motor_d;

	old_rden <= rd_en;
	if(~old_rden & rd_en & rd) begin
		din_r <= din;
		read_done <= 1;
	end

	active <= !pause && read_cnt;
	available <= (read_cnt != 0);

	old_ready <= tape_ready;
	if(tape_ready & ~old_ready) begin
		read_cnt <= tape_size;
		size <= tape_size;
		if(tape_size) begin
			hdrsz <= 32;
			read_done <= 0;
		end
	end

	if(~tape_ready) begin
		old_motor  <= 0;
		old_kpause <= 0;
		old_kplay  <= 0;
		read_cnt   <= 0;
		size       <= 0;
		read_done  <= 1;
		pause      <= 1;
		hdrsz      <= 0;
		reload32   <= 0;
		bitcnt     <= 1;
		audio_out  <= 1;
	end else if(ce) begin

		motor_r <= tape_motor;
		if(motor_r ^ tape_motor) clk_motor_cnt <= MOTOR_TIMEOUT;
		else if(clk_motor_cnt) clk_motor_cnt <= clk_motor_cnt - 1;
		else motor_d <= tape_motor;

		{old_motor,old_kpause,old_kplay} <= {motor_d,key_pause,key_play};
		if((~old_motor & motor_d) | (key_play & ~old_kplay))   pause <= 0;
		if(((old_motor & ~motor_d) | (key_pause & ~old_kpause)) && read_cnt > 100) pause <= 1;

		if(hdrsz && read_done) begin
			if(hdrsz == 7) freq[ 7:0] <= din_r;
			if(hdrsz == 6) freq[15:8] <= din_r;
			read_done <= 0;
			read_cnt  <= read_cnt - 1'd1;
			hdrsz <= hdrsz - 1'd1;
		end

		if(!hdrsz && read_cnt && !pause) begin
			if((bitcnt <= 1) || (reload32 != 0)) begin

				if(read_done) begin
					if(reload32 != 0) begin
						bitcnt <= {din_r, bitcnt[31:8]};
						reload32 <= reload32 - 1'd1;
					end else begin
						if(din_r != 0) bitcnt <= din_r;
						else reload32 <= 4;
						audio_out <= ~audio_out;
					end

					read_done <= 0;
					read_cnt  <= read_cnt - 1'd1;
				end
			end else begin
				clk_play_cnt <= clk_play_cnt + freq;
				if(clk_play_cnt > CLOCK) begin	
					clk_play_cnt <= clk_play_cnt - CLOCK;
					bitcnt <= bitcnt - 1'd1;
				end
			end
		end
	end
end

endmodule
