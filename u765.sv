// ====================================================================
//
//  NEC u765 FDC
//
//  Copyright (C) 2017 Gyorgy Szombathelyi <gyurco@freemail.hu>
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

//TODO:
//GAP, CRC generation
//WRITE DELETE should write the Deleted Address Mark to the SectorInfo
//SCAN commands
//real FORMAT (but this would require squeezing/expanding the image file)

//for accurate head stepping rate, set CYCLES to cycles/ms
//8MHz = 4000 (default)
//SPECCY_SPEEDLOCK_HACK: auto mess-up weak sector on C0H0S2
module u765 #(parameter CYCLES = 27'd4000, SPECCY_SPEEDLOCK_HACK = 0)
(
	input            clk_sys,   // sys clock
	input            ce,        // chip enable
	input            reset,	    // reset
	input      [1:0] ready,     // disk is inserted in MiST(er)
	input      [1:0] motor,     // drive motor
	input      [1:0] available, // drive available (fake ready signal for SENSE DRIVE command)
	input            a0,
	input            nRD,       // i/o read
	input            nWR,       // i/o write
	input      [7:0] din,       // i/o data in
	output     [7:0] dout,      // i/o data out

	input      [1:0] img_mounted, // signaling that new image has been mounted
	input            img_wp,      // write protect. latched at img_mounted
	input     [31:0] img_size,    // size of image in bytes
	output    [31:0] sd_lba,
	output reg [1:0] sd_rd,
	output reg [1:0] sd_wr,
	input            sd_ack,
	input      [8:0] sd_buff_addr,
	input      [7:0] sd_buff_dout,
	output     [7:0] sd_buff_din,
	input            sd_buff_wr
);

//localparam OVERRUN_TIMEOUT = 26'd35000000;
localparam OVERRUN_TIMEOUT = CYCLES / 8'd10;

localparam UPD765_MAIN_D0B = 0;
localparam UPD765_MAIN_D1B = 1;
localparam UPD765_MAIN_D2B = 2;
localparam UPD765_MAIN_D3B = 3;
localparam UPD765_MAIN_CB  = 4;
localparam UPD765_MAIN_EXM = 5;
localparam UPD765_MAIN_DIO = 6;
localparam UPD765_MAIN_RQM = 7;

localparam UPD765_SD_BUFF_TRACKINFO = 1'd0;
localparam UPD765_SD_BUFF_SECTOR = 1'd1;

/*
The cycles/sector table for various track lengths are created
in Python:

for i in range(1,256):
  print ("CYCLES*%.0f/10, // %d" % (round(1500/i,0),i))
*/

localparam integer RPM_TIMES[256]= '{
CYCLES,
CYCLES*1500/10, // 1
CYCLES*750/10, // 2
CYCLES*500/10, // 3
CYCLES*375/10, // 4
CYCLES*300/10, // 5
CYCLES*250/10, // 6
CYCLES*214/10, // 7
CYCLES*188/10, // 8
CYCLES*167/10, // 9
CYCLES*150/10, // 10
CYCLES*136/10, // 11
CYCLES*125/10, // 12
CYCLES*115/10, // 13
CYCLES*107/10, // 14
CYCLES*100/10, // 15
CYCLES*94/10, // 16
CYCLES*88/10, // 17
CYCLES*83/10, // 18
CYCLES*79/10, // 19
CYCLES*75/10, // 20
CYCLES*71/10, // 21
CYCLES*68/10, // 22
CYCLES*65/10, // 23
CYCLES*62/10, // 24
CYCLES*60/10, // 25
CYCLES*58/10, // 26
CYCLES*56/10, // 27
CYCLES*54/10, // 28
CYCLES*52/10, // 29
CYCLES*50/10, // 30
CYCLES*48/10, // 31
CYCLES*47/10, // 32
CYCLES*45/10, // 33
CYCLES*44/10, // 34
CYCLES*43/10, // 35
CYCLES*42/10, // 36
CYCLES*41/10, // 37
CYCLES*39/10, // 38
CYCLES*38/10, // 39
CYCLES*38/10, // 40
CYCLES*37/10, // 41
CYCLES*36/10, // 42
CYCLES*35/10, // 43
CYCLES*34/10, // 44
CYCLES*33/10, // 45
CYCLES*33/10, // 46
CYCLES*32/10, // 47
CYCLES*31/10, // 48
CYCLES*31/10, // 49
CYCLES*30/10, // 50
CYCLES*29/10, // 51
CYCLES*29/10, // 52
CYCLES*28/10, // 53
CYCLES*28/10, // 54
CYCLES*27/10, // 55
CYCLES*27/10, // 56
CYCLES*26/10, // 57
CYCLES*26/10, // 58
CYCLES*25/10, // 59
CYCLES*25/10, // 60
CYCLES*25/10, // 61
CYCLES*24/10, // 62
CYCLES*24/10, // 63
CYCLES*23/10, // 64
CYCLES*23/10, // 65
CYCLES*23/10, // 66
CYCLES*22/10, // 67
CYCLES*22/10, // 68
CYCLES*22/10, // 69
CYCLES*21/10, // 70
CYCLES*21/10, // 71
CYCLES*21/10, // 72
CYCLES*21/10, // 73
CYCLES*20/10, // 74
CYCLES*20/10, // 75
CYCLES*20/10, // 76
CYCLES*19/10, // 77
CYCLES*19/10, // 78
CYCLES*19/10, // 79
CYCLES*19/10, // 80
CYCLES*19/10, // 81
CYCLES*18/10, // 82
CYCLES*18/10, // 83
CYCLES*18/10, // 84
CYCLES*18/10, // 85
CYCLES*17/10, // 86
CYCLES*17/10, // 87
CYCLES*17/10, // 88
CYCLES*17/10, // 89
CYCLES*17/10, // 90
CYCLES*16/10, // 91
CYCLES*16/10, // 92
CYCLES*16/10, // 93
CYCLES*16/10, // 94
CYCLES*16/10, // 95
CYCLES*16/10, // 96
CYCLES*15/10, // 97
CYCLES*15/10, // 98
CYCLES*15/10, // 99
CYCLES*15/10, // 100
CYCLES*15/10, // 101
CYCLES*15/10, // 102
CYCLES*15/10, // 103
CYCLES*14/10, // 104
CYCLES*14/10, // 105
CYCLES*14/10, // 106
CYCLES*14/10, // 107
CYCLES*14/10, // 108
CYCLES*14/10, // 109
CYCLES*14/10, // 110
CYCLES*14/10, // 111
CYCLES*13/10, // 112
CYCLES*13/10, // 113
CYCLES*13/10, // 114
CYCLES*13/10, // 115
CYCLES*13/10, // 116
CYCLES*13/10, // 117
CYCLES*13/10, // 118
CYCLES*13/10, // 119
CYCLES*12/10, // 120
CYCLES*12/10, // 121
CYCLES*12/10, // 122
CYCLES*12/10, // 123
CYCLES*12/10, // 124
CYCLES*12/10, // 125
CYCLES*12/10, // 126
CYCLES*12/10, // 127
CYCLES*12/10, // 128
CYCLES*12/10, // 129
CYCLES*12/10, // 130
CYCLES*11/10, // 131
CYCLES*11/10, // 132
CYCLES*11/10, // 133
CYCLES*11/10, // 134
CYCLES*11/10, // 135
CYCLES*11/10, // 136
CYCLES*11/10, // 137
CYCLES*11/10, // 138
CYCLES*11/10, // 139
CYCLES*11/10, // 140
CYCLES*11/10, // 141
CYCLES*11/10, // 142
CYCLES*10/10, // 143
CYCLES*10/10, // 144
CYCLES*10/10, // 145
CYCLES*10/10, // 146
CYCLES*10/10, // 147
CYCLES*10/10, // 148
CYCLES*10/10, // 149
CYCLES*10/10, // 150
CYCLES*10/10, // 151
CYCLES*10/10, // 152
CYCLES*10/10, // 153
CYCLES*10/10, // 154
CYCLES*10/10, // 155
CYCLES*10/10, // 156
CYCLES*10/10, // 157
CYCLES*9/10, // 158
CYCLES*9/10, // 159
CYCLES*9/10, // 160
CYCLES*9/10, // 161
CYCLES*9/10, // 162
CYCLES*9/10, // 163
CYCLES*9/10, // 164
CYCLES*9/10, // 165
CYCLES*9/10, // 166
CYCLES*9/10, // 167
CYCLES*9/10, // 168
CYCLES*9/10, // 169
CYCLES*9/10, // 170
CYCLES*9/10, // 171
CYCLES*9/10, // 172
CYCLES*9/10, // 173
CYCLES*9/10, // 174
CYCLES*9/10, // 175
CYCLES*9/10, // 176
CYCLES*8/10, // 177
CYCLES*8/10, // 178
CYCLES*8/10, // 179
CYCLES*8/10, // 180
CYCLES*8/10, // 181
CYCLES*8/10, // 182
CYCLES*8/10, // 183
CYCLES*8/10, // 184
CYCLES*8/10, // 185
CYCLES*8/10, // 186
CYCLES*8/10, // 187
CYCLES*8/10, // 188
CYCLES*8/10, // 189
CYCLES*8/10, // 190
CYCLES*8/10, // 191
CYCLES*8/10, // 192
CYCLES*8/10, // 193
CYCLES*8/10, // 194
CYCLES*8/10, // 195
CYCLES*8/10, // 196
CYCLES*8/10, // 197
CYCLES*8/10, // 198
CYCLES*8/10, // 199
CYCLES*8/10, // 200
CYCLES*7/10, // 201
CYCLES*7/10, // 202
CYCLES*7/10, // 203
CYCLES*7/10, // 204
CYCLES*7/10, // 205
CYCLES*7/10, // 206
CYCLES*7/10, // 207
CYCLES*7/10, // 208
CYCLES*7/10, // 209
CYCLES*7/10, // 210
CYCLES*7/10, // 211
CYCLES*7/10, // 212
CYCLES*7/10, // 213
CYCLES*7/10, // 214
CYCLES*7/10, // 215
CYCLES*7/10, // 216
CYCLES*7/10, // 217
CYCLES*7/10, // 218
CYCLES*7/10, // 219
CYCLES*7/10, // 220
CYCLES*7/10, // 221
CYCLES*7/10, // 222
CYCLES*7/10, // 223
CYCLES*7/10, // 224
CYCLES*7/10, // 225
CYCLES*7/10, // 226
CYCLES*7/10, // 227
CYCLES*7/10, // 228
CYCLES*7/10, // 229
CYCLES*7/10, // 230
CYCLES*6/10, // 231
CYCLES*6/10, // 232
CYCLES*6/10, // 233
CYCLES*6/10, // 234
CYCLES*6/10, // 235
CYCLES*6/10, // 236
CYCLES*6/10, // 237
CYCLES*6/10, // 238
CYCLES*6/10, // 239
CYCLES*6/10, // 240
CYCLES*6/10, // 241
CYCLES*6/10, // 242
CYCLES*6/10, // 243
CYCLES*6/10, // 244
CYCLES*6/10, // 245
CYCLES*6/10, // 246
CYCLES*6/10, // 247
CYCLES*6/10, // 248
CYCLES*6/10, // 249
CYCLES*6/10, // 250
CYCLES*6/10, // 251
CYCLES*6/10, // 252
CYCLES*6/10, // 253
CYCLES*6/10, // 254
CYCLES*6/10 // 255
};

typedef enum
{
 COMMAND_IDLE,

 COMMAND_READ_TRACK,

 COMMAND_WRITE_DELETED_DATA,
 COMMAND_WRITE_DATA,

 COMMAND_READ_DELETED_DATA,
 COMMAND_READ_DATA,

 COMMAND_RW_DATA_EXEC,
 COMMAND_RW_DATA_EXEC1,
 COMMAND_RW_DATA_EXEC2,
 COMMAND_RW_DATA_EXEC3,
 COMMAND_RW_DATA_EXEC4,
 COMMAND_RW_DATA_EXEC5,
 COMMAND_RW_DATA_WAIT_SECTOR,
 COMMAND_RW_DATA_EXEC_WEAK,
 COMMAND_RW_DATA_EXEC6,
 COMMAND_RW_DATA_EXEC7,
 COMMAND_RW_DATA_EXEC8,

 COMMAND_READ_ID,
 COMMAND_READ_ID1,
 COMMAND_READ_ID2,
 COMMAND_READ_ID_EXEC1,
 COMMAND_READ_ID_EXEC2,

 COMMAND_FORMAT_TRACK,
 COMMAND_FORMAT_TRACK1,
 COMMAND_FORMAT_TRACK2,
 COMMAND_FORMAT_TRACK3,
 COMMAND_FORMAT_TRACK4,
 COMMAND_FORMAT_TRACK5,
 COMMAND_FORMAT_TRACK6,
 COMMAND_FORMAT_TRACK7,
 COMMAND_FORMAT_TRACK8,

 COMMAND_SCAN_EQUAL,
 COMMAND_SCAN_LOW_OR_EQUAL,
 COMMAND_SCAN_HIGH_OR_EQUAL,

 COMMAND_RECALIBRATE,

 COMMAND_SENSE_INTERRUPT_STATUS,
 COMMAND_SENSE_INTERRUPT_STATUS1,
 COMMAND_SENSE_INTERRUPT_STATUS2,

 COMMAND_SPECIFY,
 COMMAND_SPECIFY_WR,

 COMMAND_SENSE_DRIVE_STATUS,
 COMMAND_SENSE_DRIVE_STATUS_RD,

 COMMAND_SEEK,
 COMMAND_SEEK_EXEC1,

 COMMAND_SETUP,

 COMMAND_READ_RESULTS,

 COMMAND_INVALID,
 COMMAND_INVALID1,

 COMMAND_RELOAD_TRACKINFO,
 COMMAND_RELOAD_TRACKINFO1,
 COMMAND_RELOAD_TRACKINFO2,
 COMMAND_RELOAD_TRACKINFO3

} state_t;


// sector/trackinfo buffers
reg    [7:0] buff_data_in, buff_data_out;
reg    [8:0] buff_addr;
reg          buff_wr, buff_wait;
reg          sd_buff_type;
reg          hds, ds0;

u765_dpram sbuf
(
	.clock(clk_sys),

	.address_a({ds0, sd_buff_type,hds,sd_buff_addr}),
	.data_a(sd_buff_dout),
	.wren_a(sd_buff_wr & sd_ack),
	.q_a(sd_buff_din),

	.address_b({ds0, sd_buff_type,hds,buff_addr}),
	.data_b(buff_data_out),
	.wren_b(buff_wr),
	.q_b(buff_data_in)
);

//track offset buffer
//single port buffer in RAM
logic [15:0] image_track_offsets[0:1023]; //offset of tracks * 256 * 2 drives
reg    [8:0] image_track_offsets_addr = 0;
reg          image_track_offsets_wr;
reg   [15:0] image_track_offsets_out, image_track_offsets_in;

always @(posedge clk_sys) begin
	if (image_track_offsets_wr) begin
		image_track_offsets[{ds0, image_track_offsets_addr}] <= image_track_offsets_out;
		image_track_offsets_in <= image_track_offsets_out;
	end else begin
		image_track_offsets_in <= image_track_offsets[{ds0, image_track_offsets_addr}];
	end
end

////

wire       rd = nWR & ~nRD;
wire       wr = ~nWR & nRD;
wire [7:0] i_total_sectors;

always @(posedge clk_sys) begin

   //prefix internal CE protected registers with i_, so it's easier to write constraints

	//per-drive data
	reg[31:0] image_size[2];
	reg       image_ready[2] = '{ 0, 0 };
	reg [7:0] image_tracks[2];
	reg       image_sides[2]; //1 side - 0, 2 sides - 1
	reg       image_trackinfo_dirty[2];
	reg       image_edsk[2]; //DSK - 0, EDSK - 1
	reg [1:0] image_scan_state[2] = '{ 0, 0 };
	reg [7:0] i_current_track_sectors[2][2];  //number of sectors on the current track /head/drive
	reg [7:0] i_current_sector_pos[2][2]; //sector where the head currently positioned
	reg[26:0] i_steptimer[2], i_rpm_timer[2][2];
	reg [3:0] i_step_state[2]; //counting cycles for steptimer

	reg [7:0] ncn[2]; //new cylinder number
	reg [7:0] pcn[2]; //present cylinder number
	reg [2:0] next_weak_sector[2];
	reg [1:0] seek_state[2];
	reg       int_state[2];

	reg old_wr, old_rd;
	reg [7:0] i_track_size;
	reg [31:0] i_seek_pos;
	reg [7:0] i_sector_c, i_sector_h, i_sector_r, i_sector_n;
	reg [7:0] sector_st1, sector_st2;
	reg [15:0] i_sector_size;
	reg [7:0] i_current_sector;
	reg [2:0] i_weak_sector;
	reg [14:0] i_bytes_to_read;
	reg [2:0] substate;
	reg [1:0] old_mounted;
	reg [1:0] image_wp;
	reg [15:0] i_track_offset;
	reg [5:0] ack;
	reg sd_busy;
	reg [26:0] i_timeout;
	reg [7:0] i_head_timer;
	reg i_rtrack, i_write, i_rw_deleted;
	reg [7:0] m_status;  //main status register
	reg [7:0] status[4] = '{0, 0, 0, 0}; //st0-3
	state_t state, command;
   reg i_current_drive, i_scan_lock = 0;
	reg [3:0] i_srt; //stepping rate
//	reg [3:0] i_hut; //head unload time
//	reg [6:0] i_hlt; //head load time
	reg [7:0] i_c;
	reg [7:0] i_h;
	reg [7:0] i_r;
	reg [7:0] i_n;
	reg [7:0] i_eot;
	//reg [7:0] i_gpl;
	reg [7:0] i_dtl;
	reg [7:0] i_sc;
	//reg [7:0] i_d;
	reg old_hds;

	reg i_mt;
	//reg i_mfm;
	reg i_sk;

	buff_wait <= 0;
	i_total_sectors = i_current_track_sectors[ds0][hds];

	//new image mounted
	for(int i=0;i<2;i++) begin 
		old_mounted[i] <= img_mounted[i];
		if(old_mounted[i] & ~img_mounted[i]) begin
			image_wp[i] <= img_wp;
			image_size[i] <= img_size;
			image_scan_state[i] <= |img_size; //hacky
			image_ready[i] <= 0;
			int_state[i] <= 0;
			seek_state[i] <= 0;
			next_weak_sector[i] <= 0;
			i_current_sector_pos[i] <= '{ 0, 0 };
		end
	end

	if (ce) begin
		i_current_drive <= ~i_current_drive;
	end

   //Process the image file
	if (ce) begin
		case (image_scan_state[i_current_drive])
			0: ;//no new image
			1: //read the first 512 byte
				if (~sd_busy & ~i_scan_lock & state == COMMAND_IDLE) begin
					sd_buff_type <= UPD765_SD_BUFF_SECTOR;
					i_scan_lock <= 1;
					ds0 <= i_current_drive;
					sd_rd[i_current_drive] <= 1;
					sd_lba <= 0;
					sd_busy <= 1;
					i_track_offset<= 16'h1; //offset 100h
					image_track_offsets_addr <= 0;
					buff_addr <= 0;
					buff_wait <= 1;
					image_scan_state[i_current_drive] <= 2;
				end
			2: //process the header
				if (~sd_busy & ~buff_wait) begin
					if (buff_addr == 0) begin
						if (buff_data_in == "E")
							image_edsk[i_current_drive] <= 1;
						else if (buff_data_in == "M")
							image_edsk[i_current_drive] <= 0;
						else begin
							image_ready[i_current_drive] <= 0;
							image_scan_state[i_current_drive] <= 0;
							i_scan_lock <= 0;
						end
					end else if (buff_addr == 9'h30) image_tracks[i_current_drive] <= buff_data_in;
					else if (buff_addr == 9'h31) image_sides[i_current_drive] <= buff_data_in[1];
					else if (buff_addr == 9'h33) i_track_size <= buff_data_in;
					else if (buff_addr >= 9'h34) begin
						if (image_track_offsets_addr[8:1] != image_tracks[i_current_drive]) begin
							image_track_offsets_wr <= 1;
							if (image_edsk[i_current_drive]) begin
								image_track_offsets_out <= buff_data_in ? i_track_offset : 16'd0;
								i_track_offset <= i_track_offset + buff_data_in;
							end else begin
								image_track_offsets_out <= i_track_offset;
								i_track_offset <= i_track_offset + i_track_size;
							end
							image_scan_state[i_current_drive] <= 3;
						end else begin
							image_ready[i_current_drive] <= 1;
							image_scan_state[i_current_drive] <= 0;
							image_trackinfo_dirty[i_current_drive] <= 1;
							i_scan_lock <= 0;
						end
					end
					buff_addr <= buff_addr + 1'd1;
					buff_wait <= 1;
				end
			3: begin
					image_track_offsets_wr <= 0;
					image_track_offsets_addr <= image_track_offsets_addr + { ~image_sides[i_current_drive], image_sides[i_current_drive] };
					image_scan_state[i_current_drive] <= 2;
				end
		endcase
	end

	//the FDC
   if (reset) begin
		m_status <= 8'h80;
		state <= COMMAND_IDLE;
		status[0] <= 0;
		status[1] <= 0;
		status[2] <= 0;
		ncn <= '{ 0, 0 };
		pcn <= '{ 0, 0 };
		int_state <= '{ 0, 0 };
		seek_state <= '{ 0, 0 };
		image_trackinfo_dirty <= '{ 1, 1 };
		{ ack, sd_busy } <= 0;
		sd_rd <= 0;
		sd_wr <= 0;
		image_track_offsets_wr <= 0;
		//restart "mounting" of image(s)
		if (image_scan_state[0]) image_scan_state[0] <= 1;
		if (image_scan_state[1]) image_scan_state[1] <= 1;
		i_scan_lock <= 0;
		i_srt <= 4;
	end else if (ce) begin

		ack <= {ack[4:0], sd_ack};
		if(ack[5:4] == 'b01)	begin
			sd_rd <= 0;
			sd_wr <= 0;
		end
		if(ack[5:4] == 'b10) sd_busy <= 0;

		old_wr <= wr;
		old_rd <= rd;

		//seek
		case(seek_state[i_current_drive])
			0: ;//no seek in progress
			1: if (pcn[i_current_drive] == ncn[i_current_drive]) begin
					int_state[i_current_drive] <= 1;
					seek_state[i_current_drive] <= 0;
				end else begin
					if (pcn[i_current_drive] > ncn[i_current_drive]) pcn[i_current_drive] <= pcn[i_current_drive] - 1'd1;
					if (pcn[i_current_drive] < ncn[i_current_drive]) pcn[i_current_drive] <= pcn[i_current_drive] + 1'd1;
					image_trackinfo_dirty[i_current_drive] <= 1;
					i_step_state[i_current_drive] <= i_srt;
					i_steptimer[i_current_drive] <= CYCLES;
					seek_state[i_current_drive] <= 2;
				end
			2: if(i_steptimer[i_current_drive]) begin
					i_steptimer[i_current_drive] <= i_steptimer[i_current_drive] - 1'd1;
				end else if (~&i_step_state[i_current_drive]) begin
					i_step_state[i_current_drive] <= i_step_state[i_current_drive] + 1'd1;
					i_steptimer[i_current_drive] <= CYCLES;
				end else begin
					seek_state[i_current_drive] <= 1;
				end
		endcase

		//disk rotation
		if (motor[i_current_drive] & ~image_trackinfo_dirty[i_current_drive]) begin
			for (int i=0; i<2 ;i++) begin
				if (i_rpm_timer[i_current_drive][i] == RPM_TIMES[i_current_track_sectors[i_current_drive][i]]) begin
					i_current_sector_pos[i_current_drive][i] <=
					i_current_sector_pos[i_current_drive][i] == i_current_track_sectors[i_current_drive][i] - 1'd1 ?
						8'd0 : i_current_sector_pos[i_current_drive][i] + 1'd1;
					i_rpm_timer[i_current_drive][i] <= 0;
				end else begin
					i_rpm_timer[i_current_drive][i] <= i_rpm_timer[i_current_drive][i] + 1'd1;
				end
			end
		end

		m_status[UPD765_MAIN_D0B] <= |seek_state[0];
		m_status[UPD765_MAIN_D1B] <= |seek_state[1];
		m_status[UPD765_MAIN_CB] <= state != COMMAND_IDLE;

		case(state)
			COMMAND_IDLE:
			begin
				m_status[UPD765_MAIN_DIO] <= 0;
				m_status[UPD765_MAIN_RQM] <= !image_scan_state[0] & !image_scan_state[1];

				if (~old_wr & wr & a0 & !image_scan_state[0] & !image_scan_state[1]) begin
					i_mt <= din[7];
					//i_mfm <= din[6];
					i_sk <= din[5];

					substate <= 0;
					casex (din[7:0])
						8'bXXX_00110: state <= COMMAND_READ_DATA;
						8'bXXX_01100: state <= COMMAND_READ_DELETED_DATA;
						8'bXX0_00101: state <= COMMAND_WRITE_DATA;
						8'bXX0_01001: state <= COMMAND_WRITE_DELETED_DATA;
						8'b0XX_00010: state <= COMMAND_READ_TRACK;
						8'b0X0_01010: state <= COMMAND_READ_ID;
						8'b0X0_01101: state <= COMMAND_FORMAT_TRACK;
						8'bXXX_10001: state <= COMMAND_SCAN_EQUAL;
						8'bXXX_11001: state <= COMMAND_SCAN_LOW_OR_EQUAL;
						8'bXXX_11101: state <= COMMAND_SCAN_HIGH_OR_EQUAL;
						8'b000_00111: state <= COMMAND_RECALIBRATE;
						8'b000_01000: state <= COMMAND_SENSE_INTERRUPT_STATUS;
						8'b000_00011: state <= COMMAND_SPECIFY;
						8'b000_00100: state <= COMMAND_SENSE_DRIVE_STATUS;
						8'b000_01111: state <= COMMAND_SEEK;
						default: state <= COMMAND_INVALID;
					endcase
				end else if(~old_rd & rd & a0) begin
					dout <= 8'hff;
				end
			end

			COMMAND_SENSE_INTERRUPT_STATUS:
			begin
				m_status[UPD765_MAIN_DIO] <= 1;
				state <= COMMAND_SENSE_INTERRUPT_STATUS1;
			end

			COMMAND_SENSE_INTERRUPT_STATUS1:
			if (~old_rd & rd & a0) begin
				if (int_state[0]) begin
					dout <= ( ncn[0] == pcn[0] && ready[0] && image_ready[0] ) ? 8'h20 : 8'he8; //drive A: interrupt
					state <= COMMAND_SENSE_INTERRUPT_STATUS2;
				end else if (int_state[1]) begin
					dout <= ( ncn[1] == pcn[1] && ready[1] && image_ready[1] ) ? 8'h21 : 8'he9; //drive B: interrupt
					state <= COMMAND_SENSE_INTERRUPT_STATUS2;
				end else begin
					dout <= 8'h80;
					state <= COMMAND_IDLE;
				end;
			end

			COMMAND_SENSE_INTERRUPT_STATUS2:
			if (~old_rd & rd & a0) begin
				dout <= int_state[0] ? pcn[0] : pcn[1];
				int_state[int_state[0] ? 0 : 1] <= 0;
				state <= COMMAND_IDLE;
			end

			COMMAND_SENSE_DRIVE_STATUS:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
					state <= COMMAND_SENSE_DRIVE_STATUS_RD;
					m_status[UPD765_MAIN_DIO] <= 1;
					ds0 <= din[0];
				end
			end

			COMMAND_SENSE_DRIVE_STATUS_RD:
			if (~old_rd & rd & a0) begin
				dout <= { 1'b0,
							ready[ds0] & image_wp[ds0],         //write protected
							available[ds0],                     //ready
							image_ready[ds0] & !pcn[ds0],       //track 0
							image_ready[ds0] & image_sides[ds0],//two sides
							image_ready[ds0] & hds,             //head address
							1'b0,                               //us1
							ds0 };                              //us0
				state <= COMMAND_IDLE;
			end

			COMMAND_SPECIFY:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
//					i_hut <= din[3:0];
					i_srt <= din[7:4];
					state <= COMMAND_SPECIFY_WR;
				end
			end

			COMMAND_SPECIFY_WR:
			if (~old_wr & wr & a0) begin
//				i_hlt <= din[7:1];
				state <= COMMAND_IDLE;
			end

			COMMAND_RECALIBRATE:
			begin
				if (~old_wr & wr & a0) begin
					ds0 <= din[0];
					int_state[din[0]] <= 0;
					ncn[din[0]] <= 0;
					seek_state[din[0]] <= 1;
					state <= COMMAND_IDLE;
				end
			end

			COMMAND_SEEK:
			begin
				if (~old_wr & wr & a0) begin
					ds0 <= din[0];
					int_state[din[0]] <= 0;
					state <= COMMAND_SEEK_EXEC1;
				end
			end

			COMMAND_SEEK_EXEC1:
			if (~old_wr & wr & a0) begin
				ncn[ds0] <= din;
				if ((motor[ds0] && ready[ds0] && image_ready[ds0] && din<image_tracks[ds0]) || !din) begin
					seek_state[ds0] <= 1;
				end else begin
					//Seek error
					int_state[ds0] <= 1;
				end
				state <= COMMAND_IDLE;
			end

			COMMAND_READ_ID:
			begin
				int_state <= '{ 0, 0 };
				state <= COMMAND_READ_ID1;
			end

			COMMAND_READ_ID1:
			if (~old_wr & wr & a0) begin
				ds0 <= din[0];
				if (~motor[din[0]] | ~ready[din[0]] | ~image_ready[din[0]]) begin
					status[0] <= 8'h40;
					status[1] <= 8'b101;
					status[2] <= 0;
					state <= COMMAND_READ_RESULTS;
				end else	if (din[2] & ~image_sides[din[0]]) begin
					status[0] <= 8'h48; //no side B
					status[1] <= 0;
					status[2] <= 0;
					state <= COMMAND_READ_RESULTS;
				end else begin
					hds <= din[2];
					m_status[UPD765_MAIN_RQM] <= 0;
					command <= COMMAND_READ_ID2;
					state <= COMMAND_RELOAD_TRACKINFO;
				end
			end

			COMMAND_READ_ID2:
			begin
				image_track_offsets_addr <= { pcn[ds0], hds };
				buff_wait <= 1;
				state <= COMMAND_READ_ID_EXEC1;
			end

			COMMAND_READ_ID_EXEC1:
			if (~sd_busy & ~buff_wait) begin
				if (image_track_offsets_in) begin
					sd_buff_type <= UPD765_SD_BUFF_TRACKINFO;
					buff_addr <= { image_track_offsets_in[0], 8'h18 + (i_current_sector_pos[ds0][hds] << 3) }; //choose the next sector
					buff_wait <= 1;
					state <= COMMAND_READ_ID_EXEC2;
				end else begin
					status[0] <= 8'h40;
					status[1] <= 8'b101;
					status[2] <= 0;
					state <= COMMAND_READ_RESULTS;
				end
			end

			COMMAND_READ_ID_EXEC2:
			if (~buff_wait) begin
				if (buff_addr[2:0] == 8'h00) i_sector_c <= buff_data_in;
				else if (buff_addr[2:0] == 8'h01) i_sector_h <= buff_data_in;
				else if (buff_addr[2:0] == 8'h02) i_sector_r <= buff_data_in;
				else if (buff_addr[2:0] == 8'h03) begin
					i_sector_n <= buff_data_in;
					status[0] <= 0;
					status[1] <= 0;
					status[2] <= 0;
					state <= COMMAND_READ_RESULTS;
				end
				buff_addr <= buff_addr + 1'd1;
				buff_wait <= 1;
			end

			COMMAND_READ_TRACK:
			begin
				int_state <= '{ 0, 0 };
				command <= COMMAND_RW_DATA_EXEC;
				state <= COMMAND_SETUP;
				{i_rtrack, i_write, i_rw_deleted} <= 3'b100;
			end

			COMMAND_WRITE_DATA:
			begin
				int_state <= '{ 0, 0 };
				command <= COMMAND_RW_DATA_EXEC;
				state <= COMMAND_SETUP;
				{i_rtrack, i_write, i_rw_deleted} <= 3'b010;
			end

			COMMAND_WRITE_DELETED_DATA:
			begin
				int_state <= '{ 0, 0 };
				command <= COMMAND_RW_DATA_EXEC;
				state <= COMMAND_SETUP;
				{i_rtrack, i_write, i_rw_deleted} <= 3'b011;
			end

			COMMAND_READ_DATA:
			begin
				int_state <= '{ 0, 0 };
				command <= COMMAND_RW_DATA_EXEC;
				state <= COMMAND_SETUP;
				{i_rtrack, i_write, i_rw_deleted} <= 3'b000;
			end

			COMMAND_READ_DELETED_DATA:
			begin
				int_state <= '{ 0, 0 };
				command <= COMMAND_RW_DATA_EXEC;
				state <= COMMAND_SETUP;
				{i_rtrack, i_write, i_rw_deleted} <= 3'b001;
			end

			COMMAND_RW_DATA_EXEC:
			if (i_write & image_wp[ds0]) begin
				status[0] <= 8'h40;
				status[1] <= 8'h02; //not writeable
				status[2] <= 0;
				state <= COMMAND_READ_RESULTS;
			end else begin
				m_status[UPD765_MAIN_RQM] <= 0;
				command <= COMMAND_RW_DATA_EXEC1;
				state <= COMMAND_RELOAD_TRACKINFO;
			end

			COMMAND_RW_DATA_EXEC1:
			begin
				m_status[UPD765_MAIN_EXM] <= 1;
				m_status[UPD765_MAIN_DIO] <= ~i_write;
				if (i_rtrack) i_r <= 1;
				// Read from the track stored at the last seek
				// even if different one is given in the command
				image_track_offsets_addr <= { pcn[ds0], hds };
				buff_wait <= 1;
				state <= COMMAND_RW_DATA_EXEC2;
			end

			COMMAND_RW_DATA_EXEC2:
			if (~sd_busy & ~buff_wait) begin
				i_current_sector <= 1'd1;
				sd_buff_type <= UPD765_SD_BUFF_TRACKINFO;
				i_seek_pos <= {image_track_offsets_in+1'd1,8'd0}; //TrackInfo+256bytes
				buff_addr <= {image_track_offsets_in[0], 8'h14}; //sector size
				buff_wait <= 1;
				state <= COMMAND_RW_DATA_EXEC3;
			end

			//process trackInfo + sectorInfo
			COMMAND_RW_DATA_EXEC3:
			if (~sd_busy & ~buff_wait) begin
				if (buff_addr[7:0] == 8'h14) begin
					if (!image_edsk[ds0]) i_sector_size <= 8'h80 << buff_data_in[2:0];
					buff_addr[7:0] <= 8'h18; //sector info list
					buff_wait <= 1;
				end else if (i_current_sector > i_total_sectors) begin
					m_status[UPD765_MAIN_EXM] <= 0;
					//sector not found or end of track
					status[0] <= i_rtrack ? 8'h00 : 8'h40;
					status[1] <= i_rtrack ? 8'h00 : 8'h04;
					status[2] <= 0;
					state <= COMMAND_READ_RESULTS;
				end else begin
					//process sector info list
					case (buff_addr[2:0])
						0: i_sector_c <= buff_data_in;
						1: i_sector_h <= buff_data_in;
						2: i_sector_r <= buff_data_in;
						3: i_sector_n <= buff_data_in;
						4: sector_st1 <= buff_data_in;
						5: sector_st2 <= buff_data_in;
						6: if (image_edsk[ds0]) i_sector_size[7:0] <= buff_data_in;
						7: begin
								if (image_edsk[ds0]) i_sector_size[15:8] <= buff_data_in;
								state <= COMMAND_RW_DATA_EXEC4;
							end
					endcase
					buff_addr <= buff_addr + 1'd1;
					buff_wait <= 1;
				end
			end

			//found the sector?
			COMMAND_RW_DATA_EXEC4:
			if (i_sector_c != i_c && ~i_rtrack) begin
				m_status[UPD765_MAIN_EXM] <= 0;
				status[0] <= 8'h40;
				status[1] <= 8'h04; //no data
				status[2] <= i_sector_c == 8'hff ? 8'h02 : 8'h10; //bad/wrong cylinder
				state <= COMMAND_READ_RESULTS;
			end else if ((i_rtrack && i_current_sector == i_r) || 
							(~i_rtrack && i_sector_r == i_r && i_sector_h == i_h && (i_sector_n == i_n || !i_n))) begin
				//sector found in the sector info list
				if (i_sk & ~i_rtrack & (i_rw_deleted ^ sector_st2[6])) begin
					state <= COMMAND_RW_DATA_EXEC8;
				end else begin
					i_bytes_to_read <= i_n ? (8'h80 << i_n[2:0]) : i_dtl;
					i_timeout <= OVERRUN_TIMEOUT;
					i_weak_sector <= 0;
					state <= COMMAND_RW_DATA_WAIT_SECTOR;
				end
			end else begin
				//try the next sector in the sectorinfo list
				i_current_sector <= i_current_sector + 1'd1;
				i_seek_pos <= i_seek_pos + i_sector_size;
				state <= COMMAND_RW_DATA_EXEC3;
			end

			//wait for the sector needed for positioning at the head
			COMMAND_RW_DATA_WAIT_SECTOR:
			if (i_current_sector_pos[ds0][hds] == i_current_sector - 1'd1)
				state <= COMMAND_RW_DATA_EXEC_WEAK;

			COMMAND_RW_DATA_EXEC_WEAK:
			if (image_edsk[ds0] &&
				(i_sector_size == { i_bytes_to_read, 1'b0 } || // 2 weak sectors
				(i_sector_size == ({ i_bytes_to_read, 1'b0 } + i_bytes_to_read)) || // 3 weak sectors
				(i_sector_size == { i_bytes_to_read, 2'b00 } ))) begin // 4 weak sectors
				//if sector data == 2,3,4x sector size, then handle multiple version of the same sector (weak sectors)
				//otherwise extra data is considered as GAP data
				if (i_weak_sector != next_weak_sector[ds0]) begin
					i_seek_pos <= i_seek_pos + i_bytes_to_read;
					i_sector_size <= i_sector_size - i_bytes_to_read;
					i_weak_sector <= i_weak_sector + 1'd1;
				end else begin
					next_weak_sector[ds0] <= next_weak_sector[ds0] + 1'd1;
					state <= COMMAND_RW_DATA_EXEC5;
				end
			end else begin
				next_weak_sector[ds0] <= 0;
				state <= COMMAND_RW_DATA_EXEC5;
			end

			//Read the LBA for the sector into the RAM
			COMMAND_RW_DATA_EXEC5:
			if (~sd_busy) begin
				sd_buff_type <= UPD765_SD_BUFF_SECTOR;
				sd_rd[ds0] <= 1;
				sd_lba <= i_seek_pos[31:9];
				sd_busy <= 1;
				buff_addr <= i_seek_pos[8:0];
				buff_wait <= 1;
				state <= COMMAND_RW_DATA_EXEC6;
			end

			//Read from/write to Speccy
			COMMAND_RW_DATA_EXEC6:
			if (~sd_busy & ~buff_wait) begin
				if (!i_bytes_to_read) begin
					//end of the current sector
					m_status[UPD765_MAIN_RQM] <= 0;
					if (i_write && buff_addr && i_seek_pos < image_size[ds0]) begin
						sd_lba <= i_seek_pos[31:9];
						sd_wr[ds0] <= 1;
						sd_busy <= 1;
					end
					state <= COMMAND_RW_DATA_EXEC8;
				end else if (!i_timeout) begin
					m_status[UPD765_MAIN_EXM] <= 0;
					status[0] <= 8'h40;
					status[1] <= 8'h10; //overrun
					status[2] <= sector_st2 | (i_rw_deleted ? 8'h40 : 8'h0);
					state <= COMMAND_READ_RESULTS;
				end else if (~i_write & ~old_rd & rd & a0) begin
					if (&buff_addr) begin
						//sector continues on the next LBA
						state <= COMMAND_RW_DATA_EXEC5;
					end
					//Speedlock: randomize 'weak' sectors last bytes
					//weak sector is cyl 0, head 0, sector 2
					dout <= (SPECCY_SPEEDLOCK_HACK &
								i_current_sector == 2 & !pcn[ds0] & ~hds &
					         sector_st1[5] & sector_st2[5] & !i_bytes_to_read[14:2]) ?
								i_timeout[7:0] :
								buff_data_in;
					buff_addr <= buff_addr + 1'd1;
					buff_wait <= 1;
					m_status[UPD765_MAIN_RQM] <= 0;
					i_bytes_to_read <= i_bytes_to_read - 1'd1;
					i_seek_pos <= i_seek_pos + 1'd1;
					i_timeout <= OVERRUN_TIMEOUT;
				end else if (i_write & ~old_wr & wr & a0) begin
					buff_wr <= 1;
					buff_data_out <= din;
					i_timeout <= OVERRUN_TIMEOUT;
					m_status[UPD765_MAIN_RQM] <= 0;
					state <= COMMAND_RW_DATA_EXEC7;
				end else begin
					m_status[UPD765_MAIN_RQM] <= 1;
					i_timeout <= i_timeout - 1'd1;
				end
			end else begin
				m_status[UPD765_MAIN_RQM] <= 0;
			end

			COMMAND_RW_DATA_EXEC7:
			begin
				buff_wr <= 0;
				buff_addr <= buff_addr + 1'd1;
				i_bytes_to_read <= i_bytes_to_read - 1'd1;
				i_seek_pos <= i_seek_pos + 1'd1;
				if (&buff_addr) begin
					//sector continues on the next LBA
					//so write out the current before reading the next
					if (i_seek_pos < image_size[ds0]) begin
						sd_lba <= i_seek_pos[31:9];
						sd_wr[ds0] <= 1;
						sd_busy <= 1;
					end
					state <= COMMAND_RW_DATA_EXEC5;
				end else begin
					state <= COMMAND_RW_DATA_EXEC6;
				end
			end

			//End of reading/writing sector, what's next?
			COMMAND_RW_DATA_EXEC8:
			if (~sd_busy) begin
				if (~i_rtrack & ~(i_sk & (i_rw_deleted ^ sector_st2[6])) &
					((sector_st1[5] & sector_st2[5]) | (i_rw_deleted ^ sector_st2[6]))) begin
					//deleted mark or crc error
					m_status[UPD765_MAIN_EXM] <= 0;
					status[0] <= 8'h40;
					status[1] <= sector_st1;
					status[2] <= sector_st2 | (i_rw_deleted ? 8'h40 : 8'h0);
					state <= COMMAND_READ_RESULTS;
				end else	if ((i_rtrack ? i_current_sector : i_sector_r) == i_eot) begin
					//end of cylinder
					m_status[UPD765_MAIN_EXM] <= 0;
					status[0] <= i_rtrack ? 8'h00 : 8'h40;
					status[1] <= 8'h80;
					status[2] <= i_rw_deleted ? 8'h40 : 8'h0;
					state <= COMMAND_READ_RESULTS;
				end else begin
					//read the next sector (multi-sector transfer)
					if (i_mt & image_sides[ds0]) begin
						hds <= ~hds;
						i_h <= ~i_h;
						image_track_offsets_addr <= { pcn[ds0], ~hds };
						buff_wait <= 1;
					end
					if (~i_mt | hds | ~image_sides[ds0]) i_r <= i_r + 1'd1;
					state <= COMMAND_RW_DATA_EXEC2;
				end
			end

			COMMAND_FORMAT_TRACK:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
					ds0 <= din[0];
					state <= COMMAND_FORMAT_TRACK1;
				end
			end

			COMMAND_FORMAT_TRACK1: //doesn't modify the media
			if (~old_wr & wr & a0) begin
				i_n <= din;
				state <= COMMAND_FORMAT_TRACK2;
			end

			COMMAND_FORMAT_TRACK2:
			if (~old_wr & wr & a0) begin
				i_sc <= din;
				state <= COMMAND_FORMAT_TRACK3;
			end

			COMMAND_FORMAT_TRACK3:
			if (~old_wr & wr & a0) begin
				//i_gpl <= din;
				state <= COMMAND_FORMAT_TRACK4;
			end

			COMMAND_FORMAT_TRACK4:
			if (~old_wr & wr & a0) begin
				//i_d <= din;
				m_status[UPD765_MAIN_EXM] <= 1;
				state <= COMMAND_FORMAT_TRACK5;
			end

			COMMAND_FORMAT_TRACK5:
			if (!i_sc) begin
				m_status[UPD765_MAIN_EXM] <= 0;
				status[0] <= 0;
				status[1] <= 0;
				status[2] <= 0;
				state <= COMMAND_READ_RESULTS;
			end else	if (~old_wr & wr & a0) begin
				i_c <= din;
				state <= COMMAND_FORMAT_TRACK6;
			end

			COMMAND_FORMAT_TRACK6:
			if (~old_wr & wr & a0) begin
				i_h <= din;
				state <= COMMAND_FORMAT_TRACK7;
			end

			COMMAND_FORMAT_TRACK7:
			if (~old_wr & wr & a0) begin
				i_r <= din;
				state <= COMMAND_FORMAT_TRACK8;
			end

			COMMAND_FORMAT_TRACK8:
			if (~old_wr & wr & a0) begin
				i_n <= din;
				i_sc <= i_sc - 1'd1;
				i_r <= i_r + 1'd1;
				state <= COMMAND_FORMAT_TRACK5;
			end

			COMMAND_SCAN_EQUAL:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
					state <= COMMAND_IDLE;
				end
			end

			COMMAND_SCAN_HIGH_OR_EQUAL:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
					state <= COMMAND_IDLE;
				end
			end

			COMMAND_SCAN_LOW_OR_EQUAL:
			begin
				int_state <= '{ 0, 0 };
				if (~old_wr & wr & a0) begin
					state <= COMMAND_IDLE;
				end
			end

			COMMAND_SETUP:
			if (!old_wr & wr & a0) begin
				case (substate)
					0: begin
							ds0 <= din[0];
							hds <= din[2];
							substate <= 1;
						end
					1: begin
							i_c <= din;
							substate <= 2;
						end
					2:	begin
							i_h <= din;
							substate <= 3;
						end
					3: begin
							i_r <= din;
							substate <= 4;
						end
					4: begin
							i_n <= din;
							substate <= 5;
						end
					5: begin
							i_eot <= din;
							substate <= 6;
						end
					6:	begin
							//i_gpl <= din;
							substate <= 7;
						end
					7: begin
							i_dtl <= din;
							substate <= 0;
							if (~motor[ds0] | ~ready[ds0] | ~image_ready[ds0]) begin
								status[0] <= 8'h40;
								status[1] <= 8'b101;
								status[2] <= 0;
								state <= COMMAND_READ_RESULTS;
							end else if (hds & ~image_sides[ds0]) begin
								hds <= 0;
								status[0] <= 8'h48; //no side B
								status[1] <= 0;
								status[2] <= 0;
								state <= COMMAND_READ_RESULTS;
							end else begin
								state <= command;
							end
						end
				endcase
			end

			COMMAND_READ_RESULTS:
			begin
				m_status[UPD765_MAIN_RQM] <= 1;
				m_status[UPD765_MAIN_DIO] <= 1;
				if (~old_rd & rd & a0) begin
					case (substate)
						0: begin
								dout <= { status[0][7:3], hds, 1'b0, ds0 };
								substate <= 1;
							end
						1: begin
								dout <= status[1];
								substate <= 2;
							end
						2: begin
								dout <= status[2];
								substate <= 3;
							end
						3: begin
								dout <= i_sector_c;
								substate <= 4;
							end
						4: begin
								dout <= i_sector_h;
								substate <= 5;
							end
						5: begin
								dout <= i_sector_r;
								substate <= 6;
							end
						6: begin
								dout <= i_sector_n;
								state <= COMMAND_IDLE;
							end
						7: ;//not happen
					endcase
				end
			end

			COMMAND_INVALID:
			begin
				int_state <= '{ 0, 0 };
				m_status[UPD765_MAIN_DIO] <= 1;
				status[0] <= 8'h80;
				state <= COMMAND_INVALID1;
			end

			COMMAND_INVALID1:
			if (~old_rd & rd & a0) begin
				state <= COMMAND_IDLE;
				dout <= status[0];
			end

			COMMAND_RELOAD_TRACKINFO:
			if (image_ready[ds0] & image_trackinfo_dirty[ds0]) begin
				i_rpm_timer[ds0] <= '{ 0, 0 };
				next_weak_sector[ds0] <= 0;
				image_track_offsets_addr <= { pcn[ds0], 1'b0 };
				old_hds <= hds;
				hds <= 0;
				buff_wait <= 1;
				state <= COMMAND_RELOAD_TRACKINFO1;
			end else begin
				state <= command;
			end

			COMMAND_RELOAD_TRACKINFO1:
			if (~buff_wait& ~sd_busy) begin
				if (image_ready[ds0] && image_track_offsets_in) begin
					sd_buff_type <= UPD765_SD_BUFF_TRACKINFO;
					sd_rd[ds0] <= 1;
					sd_lba <= image_track_offsets_in[15:1];
					sd_busy <= 1;
					state <= COMMAND_RELOAD_TRACKINFO2;
				end else begin
					image_trackinfo_dirty[ds0] <= 0;
					hds <= old_hds;
					state <= command;
				end
			end

			COMMAND_RELOAD_TRACKINFO2:
			if (~sd_busy) begin
				buff_addr <= {image_track_offsets_in[0], 8'h15}; //number of sectors
				buff_wait <= 1;
				state <= COMMAND_RELOAD_TRACKINFO3;
			end

			COMMAND_RELOAD_TRACKINFO3:
			if (~sd_busy & ~buff_wait) begin
				i_current_track_sectors[ds0][hds] <= buff_data_in;
				//assume the head position is at the middle of a track after a seek
				i_current_sector_pos[ds0][hds] <= buff_data_in[7:1];

				if (hds == image_sides[ds0]) begin
					image_trackinfo_dirty[ds0] <= 0;
					hds <= old_hds;
					state <= command;
				end else begin //read TrackInfo from the other head if 2 sided
					image_track_offsets_addr <= { pcn[ds0], 1'b1 };
					hds <= 1;
					buff_wait <= 1;
					state <= COMMAND_RELOAD_TRACKINFO1;
				end
			end

		endcase //status

		if (~old_rd & rd & ~a0) begin //read main status register
			dout <= m_status;
		end
	end
end

endmodule

module u765_dpram #(parameter DATAWIDTH=8, ADDRWIDTH=12)
(
	input	                clock,

	input	[ADDRWIDTH-1:0] address_a,
	input	[DATAWIDTH-1:0] data_a,
	input	                wren_a,
	output reg [DATAWIDTH-1:0] q_a,

	input	[ADDRWIDTH-1:0] address_b,
	input	[DATAWIDTH-1:0] data_b,
	input	                wren_b,
	output reg [DATAWIDTH-1:0] q_b
);

logic [DATAWIDTH-1:0] ram[0:(1<<ADDRWIDTH)-1];

always_ff@(posedge clock) begin
	if(wren_a) begin
		ram[address_a] <= data_a;
		q_a <= data_a;
	end else begin
		q_a <= ram[address_a];
	end
end

always_ff@(posedge clock) begin
	if(wren_b) begin
		ram[address_b] <= data_b;
		q_b <= data_b;
	end else begin
		q_b <= ram[address_b];
	end
end

endmodule
