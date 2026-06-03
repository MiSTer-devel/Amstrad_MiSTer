//============================================================================
//  Amstrad CPC 6128
//  Copyright (C) 2018-2019 Sorgelig
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

module emu
(
	`include "sys/emu_ports.vh"
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;

assign LED_USER  = mf2_en | ioctl_download | tape_led | tape_adc_act;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

// Status Bit Map:
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXX X XXXXXXXXXXXXXXXXXXXXXXXXX  X         XXX

`include "build_id.v"
localparam CONF_STR = {
	"Amstrad;;",
	"S0,DSK,Mount A:;",
	"S1,DSK,Mount B:;",
	"-;",
	"FC0,ROM,Load Main ROM;",
	"FC3,E??,Load expansion;",
	"-;",
	"F4,CDT,Load tape;",
	"F5,ROM,Load Dandanator ROM;",
	"F6,SNA,Load snapshot;",
	"F7,E??,Load CPC464 ROM;",
	"OK,Tape sound,Disabled,Enabled;",
	"-;",
	"O[62:61],SNAC,Off,Player 1,Player 2;",
	"-;",
	"OI,Joysticks swap,No,Yes;",
	"-;",
	
	"P1,Audio & Video;",
	"P1-;",
	"P1OPQ,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O9A,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"P1-;",
	"d1P1OR,Vertical Crop,No,Yes;",
	"P1OST,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1OU,Pixel Clock,16MHz,Adaptive;",
	"P1-;",
	"P1O2,CRTC,Type 1,Type 0;",
	"P1OBD,Display,Color(GA),Color(ASIC),Green,Amber,Cyan,White;",
	"P1-;",
	"P1O78,Stereo mix,none,25%,50%,100%;",
	"P1OO,Playcity,Disabled,Enabled;",

	"P2,Hardware;",
	"P2-;",
	"P2OJ,Mouse,Enabled,Disabled;",
	"P2OL,AMX Mouse,Disabled,Joystick 1;",
	"P2OM,Right Shift,Backslash,Shift;",
	"P2ON,Keypad,Numbers,Symbols;",
	"P2-;",
	"P2OEF,Multiface 2,Enabled,Hidden,Disabled;",
	"P2O6,CPU timings,Original,Fast;",
	"P2OGH,FDC,Original,Fast,Disabled;",
	"P2-;",
	"P2oAC,Distributor,Amstrad,Orion,Schneider,Awa,Solavox,Saisho,Triumph,Isp;",
	"P2O[5:4],Model,CPC 6128,CPC 664,CPC 464;",
	"P2OV,Tape progressbar,Off,On;",

	"-;",
	"R0,Reset & apply model;",
	"R[32],Reset & Detach Cartridge;",
	"J,Fire 1,Fire 2,Fire 3;",
	"V,v",`BUILD_DATE
};

//////////////////////////////////////////////////////////////////////////

wire clk_sys;
wire locked;
wire st_right_shift_mod = status[22];
wire st_keypad_mod = status[23];
wire st_progressbar = status[31];

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_sys),
	.locked(locked)
);

reg ce_ref, ce_u765;
reg ce_16;
always @(posedge clk_sys) begin
	reg [2:0] div = 0;

	div     <= div + 1'd1;

	ce_ref  <= !div;
	ce_u765 <= !div[2:0]; //8 MHz
	ce_16   <= !div[1:0]; //16 MHz
end

//////////////////////////////////////////////////////////////////////////

wire [31:0] sd_lba;
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire  [1:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire  [1:0] img_mounted;
wire [63:0] img_size;
wire        img_readonly;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire [31:0] ioctl_file_ext;
wire        ioctl_wait;

wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

wire  [1:0] buttons;
wire  [6:0] joy1_usb;
wire  [6:0] joy2_usb;
wire [63:0] status;

wire        forced_scandoubler;
wire [21:0] gamma_bus;

wire  [1:0] snac_player = status[62:61];
wire [15:0] joydb_1;
wire [15:0] joydb_2;
wire        joydb_1ena;
wire        joydb_2ena;

joydb joydb
(
	.USER_IN(USER_IN),
	.snac_player(snac_player),
	.joystick1(joydb_1),
	.joystick2(joydb_2),
	.joystick1_en(joydb_1ena),
	.joystick2_en(joydb_2ena)
);

wire [6:0] joy1_db9 = OSD_STATUS ? 7'd0 : {joydb_1[10], joydb_1[6], joydb_1[4], joydb_1[3:0]};
wire [6:0] joy2_db9 = OSD_STATUS ? 7'd0 : {joydb_2[10], joydb_2[6], joydb_2[4], joydb_2[3:0]};
wire [6:0] joy1     = joydb_1ena ? joy1_db9 : joy1_usb;
wire [6:0] joy2     = joydb_2ena ? joy2_db9 : joydb_1ena ? joy1_usb : joy2_usb;

hps_io #(.CONF_STR(CONF_STR), .VDNUM(2)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_readonly(img_readonly),
	.sd_lba('{sd_lba,sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din,sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),

	.joystick_0(joy1_usb),
	.joystick_1(joy2_usb),

	.buttons(buttons),
	.status(status),
	.status_in({status[31:21],~status[20],status[19:0]}),
	.status_set(Fn[1]),
	.status_menumask({en270p,1'b0}),

	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_file_ext(ioctl_file_ext),
	.ioctl_wait(ioctl_wait)
);

wire        rom_download = ioctl_download && ((ioctl_index[4:0] < 4) || (ioctl_index == 7));
wire        tape_download = ioctl_download && (ioctl_index == 4);
wire        dan_download = ioctl_download && (ioctl_index == 5);
wire        sna_download = ioctl_download && (ioctl_index == 6);
wire [24:0] sna_mem_addr = ioctl_addr - 25'h100;
wire [15:0] sna_std_mem_size = (sna_mem_size > 16'd128) ? 16'd128 : sna_mem_size;
wire [24:0] sna_chunk_start = 25'h100 + {sna_std_mem_size[14:0], 10'd0};

reg [211:0] sna_cpu_dir = 212'd0;
reg   [4:0] sna_crtc_addr = 5'd0;
reg [143:0] sna_crtc_regs = 144'd0;
reg   [4:0] sna_ga_inksel = 5'd0;
reg [135:0] sna_ga_palette = 136'd0;
reg   [7:0] sna_ga_config = 8'd0;
reg   [7:0] sna_ram_config = 8'd0;
reg   [7:0] sna_rom_select = 8'd0;
reg   [7:0] sna_ppi_a = 8'd0;
reg   [7:0] sna_ppi_b = 8'd0;
reg   [7:0] sna_ppi_c = 8'd0;
reg   [7:0] sna_ppi_control = 8'h9b;
reg   [3:0] sna_psg_addr = 4'd0;
reg [127:0] sna_psg_regs = 128'd0;
reg  [15:0] sna_mem_size = 16'd64;
reg   [1:0] sna_model = 2'd0;
reg   [2:0] sna_apply_cnt = 3'd0;
reg         sna_finish_pending = 1'b0;
reg         old_sna_download_reset = 1'b0;
wire        sna_load = (sna_apply_cnt == 3'd1);
wire        sna_mem_wr = sna_download && ioctl_wr && (ioctl_addr >= 25'h100) &&
                         (ioctl_addr < sna_chunk_start) && ({9'd0, sna_mem_addr[16:10]} < sna_std_mem_size);
reg  [31:0] sna_chunk_name = 32'd0;
reg  [31:0] sna_chunk_len = 32'd0;
reg  [31:0] sna_chunk_rem = 32'd0;
reg   [2:0] sna_chunk_hdr = 3'd0;
reg         sna_chunk_data = 1'b0;
reg         sna_chunk_mem = 1'b0;
reg         sna_chunk_rle = 1'b0;
reg         sna_chunk_finish = 1'b0;
reg   [3:0] sna_chunk_bank = 4'd0;
reg  [15:0] sna_chunk_out = 16'd0;
reg   [1:0] sna_rle_state = 2'd0;
reg   [7:0] sna_rle_count = 8'd0;
reg   [7:0] sna_rle_value = 8'd0;

assign ioctl_wait = romdl_wait | (sna_download && |sna_rle_count && (sna_rle_state == 2'd0));

function automatic [1:0] valid_model(input [1:0] requested);
	begin
		valid_model = (requested == 2'd3) ? 2'd0 : requested;
	end
endfunction

wire [1:0] menu_model = valid_model(status[5:4]);

// A 8MB bank is split to 2 halves
// Fist 4 MB is OS ROM + RAM pages + MF2 ROM
// Second 4 MB is max. 256 pages of HI rom

reg         boot_wr = 0;
reg  [22:0] boot_a;
reg   [1:0] boot_bank;
reg   [7:0] boot_dout;

reg [255:0] rom_map = '0;

reg         romdl_wait = 0;
always @(posedge clk_sys) begin
	reg [8:0] page = 0;
	reg       combo = 0;
	reg       old_download;
	reg 	  old_dan_download;
	reg       old_sna_download;
	reg  	  old_st0 = 0;

	if(!romdl_wait && sna_rle_count && (sna_rle_state == 2'd0) && sna_chunk_mem && (sna_chunk_bank < 4'd2)) begin
		romdl_wait <= 1;
		boot_dout <= sna_rle_value;
		boot_bank <= sna_model;
		boot_a[22:14] <= 9'd8 + {5'd0, sna_chunk_bank[1:0], sna_chunk_out[15:14]};
		boot_a[13:0] <= sna_chunk_out[13:0];
		sna_chunk_out <= sna_chunk_out + 1'd1;
		sna_rle_count <= sna_rle_count - 1'd1;
		if((sna_rle_count == 8'd1) && sna_chunk_finish) begin
			sna_chunk_data <= 1'b0;
			sna_chunk_hdr <= 3'd0;
			sna_chunk_name <= 32'd0;
			sna_chunk_len <= 32'd0;
			sna_chunk_mem <= 1'b0;
			sna_chunk_rle <= 1'b0;
			sna_chunk_finish <= 1'b0;
			sna_rle_state <= 2'd0;
		end
	end
	else if((rom_download | dan_download | sna_mem_wr)  & ioctl_wr) begin
		romdl_wait <= 1;
		boot_dout <= ioctl_dout;

		boot_a[13:0] <= ioctl_addr[13:0];

		if (sna_mem_wr) begin
			boot_bank <= sna_model;
			boot_a[22:14] <= 9'd8 + {6'd0, sna_mem_addr[16:14]};
			boot_a[13:0] <= sna_mem_addr[13:0];
		end
		else if (dan_download) begin
			boot_bank <= 2'b11;
			boot_a[22:14] <= ioctl_addr[22:14];
		end 
		else if(ioctl_index) begin
			boot_a[22]    <= page[8];
			boot_a[21:14] <= page[7:0] + ioctl_addr[21:14];
			boot_bank     <= (ioctl_index == 7) ? 2'd2 : {1'b0, &ioctl_index[7:6]};
		end
		else begin
			case(ioctl_addr[24:14])
					0,4: boot_a[22:14] <= 9'h000; //OS
					1,5: boot_a[22:14] <= 9'h100; //BASIC
					2,6: boot_a[22:14] <= 9'h107; //AMSDOS
					3,7: boot_a[22:14] <= 9'h0ff; //MF2
					8:   boot_a[22:14] <= 9'h000; //CPC464 OS
					9:   boot_a[22:14] <= 9'h100; //CPC464 BASIC
			  default:    romdl_wait <= 0;
			endcase

			case(ioctl_addr[24:14])
			  0,1,2,3: boot_bank <= 0; //CPC6128
			  4,5,6,7: boot_bank <= 1; //CPC664
			  8,9:     boot_bank <= 2; //CPC464
			endcase
		end
	end

	if(ce_ref) begin
		boot_wr <= romdl_wait;
		if(boot_wr & romdl_wait) begin
			boot_wr <= 0;
			// load expansion ROM into both banks if manually loaded or boot name is boot.eXX
			if(rom_download && (ioctl_index[7:6]==1 || ioctl_index[5:0]) && !boot_bank) boot_bank <= 1;
			else begin
				{boot_wr, romdl_wait} <= 0;
				if(boot_a[22]) rom_map[boot_a[21:14]] <= 1;
				if(combo && &boot_a[13:0]) begin
					combo <= 0;
					page  <= 9'h1FF;
				end
			end
		end
	end

	old_download <= ioctl_download;
	if(~old_download & ioctl_download & rom_download) begin
		if(ioctl_index) begin
			page <= 9'h1EE; // some unused page for malformed file extension
			combo <= 0;
			if(ioctl_file_ext[15:8] >= "0" && ioctl_file_ext[15:8] <= "9") page[7:4] <= ioctl_file_ext[11:8];
			if(ioctl_file_ext[15:8] >= "A" && ioctl_file_ext[15:8] <= "F") page[7:4] <= ioctl_file_ext[11:8]+4'd9;
			if(ioctl_file_ext[7:0]  >= "0" && ioctl_file_ext[7:0]  <= "9") page[3:0] <= ioctl_file_ext[3:0];
			if(ioctl_file_ext[7:0]  >= "A" && ioctl_file_ext[7:0]  <= "F") page[3:0] <= ioctl_file_ext[3:0] +4'd9;
			if(ioctl_file_ext[15:0] == "ZZ") page <= 0;
			if(ioctl_file_ext[15:0] == "Z0") begin page <= 0; combo <= 1; end
		end
	end
	old_dan_download <= dan_download;
    if (old_dan_download & ~dan_download)  begin
        dan_eeprom_loaded <= 1'b1;
    end
	if(sna_download && ioctl_wr && (ioctl_addr < 25'h100)) begin
		case(ioctl_addr[7:0])
			8'h11: sna_cpu_dir[15:8]    <= ioctl_dout;          // F
			8'h12: sna_cpu_dir[7:0]     <= ioctl_dout;          // A
			8'h13: sna_cpu_dir[87:80]   <= ioctl_dout;          // C
			8'h14: sna_cpu_dir[95:88]   <= ioctl_dout;          // B
			8'h15: sna_cpu_dir[103:96]  <= ioctl_dout;          // E
			8'h16: sna_cpu_dir[111:104] <= ioctl_dout;          // D
			8'h17: sna_cpu_dir[119:112] <= ioctl_dout;          // L
			8'h18: sna_cpu_dir[127:120] <= ioctl_dout;          // H
			8'h19: sna_cpu_dir[47:40]   <= ioctl_dout;          // R
			8'h1a: sna_cpu_dir[39:32]   <= ioctl_dout;          // I
			8'h1b: sna_cpu_dir[210]     <= ioctl_dout[0];       // IFF1
			8'h1c: sna_cpu_dir[211]     <= ioctl_dout[0];       // IFF2
			8'h1d: sna_cpu_dir[135:128] <= ioctl_dout;          // IX low
			8'h1e: sna_cpu_dir[143:136] <= ioctl_dout;          // IX high
			8'h1f: sna_cpu_dir[199:192] <= ioctl_dout;          // IY low
			8'h20: sna_cpu_dir[207:200] <= ioctl_dout;          // IY high
			8'h21: sna_cpu_dir[55:48]   <= ioctl_dout;          // SP low
			8'h22: sna_cpu_dir[63:56]   <= ioctl_dout;          // SP high
			8'h23: sna_cpu_dir[71:64]   <= ioctl_dout;          // PC low
			8'h24: sna_cpu_dir[79:72]   <= ioctl_dout;          // PC high
			8'h25: sna_cpu_dir[209:208] <= ioctl_dout[1:0];     // IM
			8'h26: sna_cpu_dir[31:24]   <= ioctl_dout;          // F'
			8'h27: sna_cpu_dir[23:16]   <= ioctl_dout;          // A'
			8'h28: sna_cpu_dir[151:144] <= ioctl_dout;          // C'
			8'h29: sna_cpu_dir[159:152] <= ioctl_dout;          // B'
			8'h2a: sna_cpu_dir[167:160] <= ioctl_dout;          // E'
			8'h2b: sna_cpu_dir[175:168] <= ioctl_dout;          // D'
			8'h2c: sna_cpu_dir[183:176] <= ioctl_dout;          // L'
			8'h2d: sna_cpu_dir[191:184] <= ioctl_dout;          // H'
			8'h2e: sna_ga_inksel        <= ioctl_dout[4:0];
			8'h40: sna_ga_config        <= ioctl_dout;
			8'h41: sna_ram_config       <= ioctl_dout;
			8'h42: sna_crtc_addr        <= ioctl_dout[4:0];
			8'h55: sna_rom_select       <= ioctl_dout;
			8'h56: sna_ppi_a            <= ioctl_dout;
			8'h57: sna_ppi_b            <= ioctl_dout;
			8'h58: sna_ppi_c            <= ioctl_dout;
			8'h59: sna_ppi_control      <= ioctl_dout;
			8'h5a: sna_psg_addr         <= ioctl_dout[3:0];
			8'h6b: sna_mem_size[7:0]    <= ioctl_dout;
			8'h6c: begin
				sna_mem_size[15:8] <= ioctl_dout;
				if({ioctl_dout, sna_mem_size[7:0]} > 16'd64) sna_model <= 2'd0;
				else if(sna_cpu_dir[79:64] == 16'h0038) sna_model <= 2'd2;
			end
			8'h6d: begin
				if(sna_mem_size > 16'd64) sna_model <= 2'd0;
				else begin
					case(ioctl_dout)
						8'd0: sna_model <= 2'd2; // CPC464
						8'd1: sna_model <= 2'd1; // CPC664
						8'd2, 8'd4, 8'd6: sna_model <= 2'd0; // 6128/Plus/GX snapshots need the 128K map.
					endcase
				end
			end
		endcase

		if(ioctl_addr[7:0] >= 8'h2f && ioctl_addr[7:0] <= 8'h3f)
			sna_ga_palette[((ioctl_addr[7:0] - 8'h2f) * 8) +: 8] <= ioctl_dout;
		if(ioctl_addr[7:0] >= 8'h43 && ioctl_addr[7:0] <= 8'h54)
			sna_crtc_regs[((ioctl_addr[7:0] - 8'h43) * 8) +: 8] <= ioctl_dout;
		if(ioctl_addr[7:0] >= 8'h5b && ioctl_addr[7:0] <= 8'h6a)
			sna_psg_regs[((ioctl_addr[7:0] - 8'h5b) * 8) +: 8] <= ioctl_dout;
	end
	if(~old_download & ioctl_download & sna_download) begin
		sna_cpu_dir <= 212'd0;
		sna_crtc_regs <= 144'd0;
		sna_ga_palette <= 136'd0;
		sna_psg_regs <= 128'd0;
		sna_mem_size <= 16'd64;
		sna_model <= menu_model;
		sna_ppi_control <= 8'h9b;
		sna_chunk_name <= 32'd0;
		sna_chunk_len <= 32'd0;
		sna_chunk_rem <= 32'd0;
		sna_chunk_hdr <= 3'd0;
		sna_chunk_data <= 1'b0;
		sna_chunk_mem <= 1'b0;
		sna_chunk_rle <= 1'b0;
		sna_chunk_finish <= 1'b0;
		sna_chunk_bank <= 4'd0;
		sna_chunk_out <= 16'd0;
		sna_rle_state <= 2'd0;
		sna_rle_count <= 8'd0;
		sna_rle_value <= 8'd0;
		sna_finish_pending <= 1'b0;
	end
	if(sna_download && ioctl_wr && !romdl_wait && (!sna_rle_count || (sna_rle_state == 2'd2)) && (ioctl_addr >= sna_chunk_start)) begin
		if(!sna_chunk_data) begin
			case(sna_chunk_hdr)
				3'd0: sna_chunk_name[31:24] <= ioctl_dout;
				3'd1: sna_chunk_name[23:16] <= ioctl_dout;
				3'd2: sna_chunk_name[15:8]  <= ioctl_dout;
				3'd3: sna_chunk_name[7:0]   <= ioctl_dout;
				3'd4: sna_chunk_len[7:0]    <= ioctl_dout;
				3'd5: sna_chunk_len[15:8]   <= ioctl_dout;
				3'd6: sna_chunk_len[23:16]  <= ioctl_dout;
				3'd7: begin
					reg [31:0] next_name;
					reg [31:0] next_len;
					next_name = sna_chunk_name;
					next_len = {ioctl_dout, sna_chunk_len[23:0]};
					sna_chunk_len[31:24] <= ioctl_dout;
					sna_chunk_rem <= {ioctl_dout, sna_chunk_len[23:0]};
					sna_chunk_data <= |next_len;
					sna_chunk_mem <= (next_name[31:24] == "M") && (next_name[23:16] == "E") &&
					                 (next_name[15:8] == "M") && (next_name[7:0] >= "0") &&
					                 (next_name[7:0] <= "1");
					sna_chunk_rle <= (next_len != 32'd65536);
					sna_chunk_finish <= 1'b0;
					sna_chunk_bank <= next_name[3:0];
					if((next_name[31:24] == "M") && (next_name[23:16] == "E") &&
					   (next_name[15:8] == "M") && (next_name[7:0] == "1")) sna_model <= 2'd0;
					sna_chunk_out <= 16'd0;
					sna_rle_state <= 2'd0;
					sna_rle_count <= 8'd0;
				end
			endcase
			sna_chunk_hdr <= sna_chunk_hdr + 1'd1;
		end
		else begin
			reg [31:0] next_rem;
			next_rem = sna_chunk_rem - 1'd1;
			sna_chunk_rem <= next_rem;
			if(sna_chunk_mem && (sna_chunk_bank < 4'd2)) begin
				if(!sna_chunk_rle) begin
					romdl_wait <= 1;
					boot_dout <= ioctl_dout;
					boot_bank <= sna_model;
					boot_a[22:14] <= 9'd8 + {5'd0, sna_chunk_bank[1:0], sna_chunk_out[15:14]};
					boot_a[13:0] <= sna_chunk_out[13:0];
					sna_chunk_out <= sna_chunk_out + 1'd1;
				end
				else begin
					case(sna_rle_state)
						2'd0: begin
							if(ioctl_dout == 8'he5) sna_rle_state <= 2'd1;
							else begin
								romdl_wait <= 1;
								boot_dout <= ioctl_dout;
								boot_bank <= sna_model;
								boot_a[22:14] <= 9'd8 + {5'd0, sna_chunk_bank[1:0], sna_chunk_out[15:14]};
								boot_a[13:0] <= sna_chunk_out[13:0];
								sna_chunk_out <= sna_chunk_out + 1'd1;
							end
						end
						2'd1: begin
							if(ioctl_dout == 8'd0) begin
								romdl_wait <= 1;
								boot_dout <= 8'he5;
								boot_bank <= sna_model;
								boot_a[22:14] <= 9'd8 + {5'd0, sna_chunk_bank[1:0], sna_chunk_out[15:14]};
								boot_a[13:0] <= sna_chunk_out[13:0];
								sna_chunk_out <= sna_chunk_out + 1'd1;
								sna_rle_state <= 2'd0;
							end
							else begin
								sna_rle_count <= ioctl_dout;
								sna_rle_state <= 2'd2;
							end
						end
						2'd2: begin
							sna_rle_value <= ioctl_dout;
							romdl_wait <= 1;
							boot_dout <= ioctl_dout;
							boot_bank <= sna_model;
							boot_a[22:14] <= 9'd8 + {5'd0, sna_chunk_bank[1:0], sna_chunk_out[15:14]};
							boot_a[13:0] <= sna_chunk_out[13:0];
							sna_chunk_out <= sna_chunk_out + 1'd1;
							sna_rle_count <= sna_rle_count - 1'd1;
							sna_rle_state <= 2'd0;
						end
					endcase
				end
			end
			if(next_rem == 32'd0 && sna_chunk_rle && sna_chunk_mem && (sna_chunk_bank < 4'd2) &&
			   (sna_rle_state == 2'd2) && (sna_rle_count > 8'd1)) begin
				sna_chunk_finish <= 1'b1;
			end
			else if(next_rem == 32'd0) begin
				sna_chunk_data <= 1'b0;
				sna_chunk_hdr <= 3'd0;
				sna_chunk_name <= 32'd0;
				sna_chunk_len <= 32'd0;
				sna_chunk_mem <= 1'b0;
				sna_chunk_rle <= 1'b0;
				sna_chunk_finish <= 1'b0;
				sna_rle_state <= 2'd0;
			end
		end
	end
	old_sna_download <= sna_download;
	if(old_sna_download & ~sna_download) sna_finish_pending <= 1'b1;
	if(sna_finish_pending && !romdl_wait && !boot_wr && !sna_rle_count) begin
		sna_finish_pending <= 1'b0;
		sna_apply_cnt <= 3'd5;
	end
	else if(sna_apply_cnt) sna_apply_cnt <= sna_apply_cnt - 1'd1;
	old_st0 <= status[32];
	if (~old_st0 & status[32]) dan_eeprom_loaded <= 0;
end


//////////////////////////////////////////////////////////////////////////

wire        mem_wr;
wire        mem_rd;
wire [22:0] ram_a;
wire  [7:0] ram_dout;

wire [15:0] vram_dout;
wire [14:0] vram_addr;

sdram sdram
(
	.*,

	.init(~locked),
	.clk(clk_sys),
	.clkref(ce_ref),

	.oe  (reset ? 1'b0      : mem_rd & ~mf2_ram_en),
	.we  (reset ? boot_wr   : mem_wr & ~mf2_ram_en & ~mf2_rom_en),
	.addr(reset ? boot_a    : mf2_rom_en ? {9'h0ff, cpu_addr[13:0]} : dan_ena ? {4'd0, dan_bank, cpu_addr[13:0]} : ram_a),
	.bank(reset ? boot_bank : dan_ena ? 2'b11 : model),
	.din (reset ? boot_dout : cpu_dout),
	.dout(ram_dout),
	.vram_bank(model),
	.vram_addr({2'b10,vram_addr,1'b0}),
	.vram_dout(vram_dout),

	.tape_addr(tape_download ? tape_last_addr : tape_play_addr),
	.tape_din(tape_din),
	.tape_dout(tape_dout),
	.tape_wr(tape_wr),
	.tape_wr_ack(tape_wr_ack),
	.tape_rd(tape_data_req ^ tape_data_ack),
	.tape_rd_ack(tape_data_ack)
);

reg [1:0] model = 2'd0;
reg reset;

always @(posedge clk_sys) begin
	if(sna_load) model <= sna_model;
	else if(reset) model <= menu_model;
	old_sna_download_reset <= sna_download;
	reset <= RESET | status[0] | status[32] | buttons[1] | rom_download | key_reset | dan_download |
	         sna_download | sna_finish_pending | (old_sna_download_reset & ~sna_download) | (sna_apply_cnt > 3'd2);
end

////////////////////// CDT playback ///////////////////////////////

reg  [22:0] tape_last_addr;
reg   [7:0] tape_din;
reg         tape_wr = 0;
wire        tape_wr_ack;
wire        tape_read;
wire        tape_running;
wire        tape_data_req;
wire        tape_data_ack;
reg         tape_reset;
wire  [7:0] tape_dout;
reg  [22:0] tape_play_addr;
wire        tape_motor;

always @(posedge clk_sys) begin
	reg old_tape_ack;
	reg old_dan_download;

	if(tape_wr_ack | reset) tape_wr <= 0;
	if(tape_download && ioctl_wr) begin
		tape_wr <= 1;
		tape_din <= ioctl_dout;
		tape_last_addr <= ioctl_addr[22:0];
	end

	old_tape_ack <= tape_data_ack;

	if (reset | Fn[2]) begin
		tape_play_addr <= 0;
		tape_last_addr <= 0;
		tape_reset <= 1;
	end
	else begin
		tape_reset <= 0;
		if (tape_download) begin
			tape_play_addr <= 0;
			tape_reset <= 1;
		end
		else if ((old_tape_ack ^ tape_data_ack) && (tape_play_addr < tape_last_addr)) begin
			tape_play_addr <= tape_play_addr + 1'd1;
		end
	end
end

tzxplayer #(
	.NORMAL_PILOT_LEN(2000),
	.NORMAL_SYNC1_LEN(855),
	.NORMAL_SYNC2_LEN(855),
	.NORMAL_ZERO_LEN(855),
	.NORMAL_ONE_LEN(1710),
	.HEADER_PILOT_PULSES(4095),
	.NORMAL_PILOT_PULSES(4095)
)
tzxplayer (
	.clk(clk_sys),
	.ce(1),
	.restart_tape(tape_reset),
	.host_tap_in(tape_dout),
	.tzx_req(tape_data_req),
	.tzx_ack(tape_data_ack),
	.cass_read(tape_read),
	.cass_motor(tape_motor),
	.cass_running(tape_running)
);

wire progress_pix;

progressbar progressbar(
	.clk(clk_sys),
	.ce_pix(ce_16),
	.hblank(hbl),
	.vblank(vbl),
	.enable(tape_running & st_progressbar),
	.current(tape_play_addr),
	.max(tape_last_addr),
	.pix(progress_pix)
);

wire tape_ready = tape_last_addr && (tape_play_addr <= tape_last_addr);
wire tape_led = act_cnt[24] ? act_cnt[23:16] > act_cnt[7:0] : act_cnt[23:16] <= act_cnt[7:0];

reg [24:0] act_cnt;
always @(posedge clk_sys) if((tape_ready & tape_motor) || ~act_cnt[24] || act_cnt[23:0]) act_cnt <= act_cnt + 1'd1;

//////////////////////////////////////////////////////////////////////////

wire [3:0] fdc_sel = {cpu_addr[10],cpu_addr[8],cpu_addr[7],cpu_addr[0]};
wire [7:0] fdc_dout = (u765_sel & io_rd) ? u765_dout : 8'hFF;

reg motor = 0;
always @(posedge clk_sys) begin
	reg old_wr;
	
	old_wr <= io_wr;
	if(~old_wr && io_wr && !fdc_sel[3:1]) begin
		motor <= cpu_dout[0];
	end
end

wire [7:0] u765_dout;
wire       u765_sel = (fdc_sel[3:1] == 'b010) & ~status[17];

reg  [1:0] u765_ready = 0;
always @(posedge clk_sys) if(img_mounted[0]) u765_ready[0] <= |img_size;
always @(posedge clk_sys) if(img_mounted[1]) u765_ready[1] <= |img_size;

u765 u765
(
	.reset(status[0]),

	.clk_sys(clk_sys),
	.ce(ce_u765),
	
	.fast(status[16]),

	.a0(fdc_sel[0]),
	.ready(u765_ready),
	.motor({motor,motor}),
	.available(2'b11),
	.nRD(~(u765_sel & io_rd)),
	.nWR(~(u765_sel & io_wr)),
	.din(cpu_dout),
	.dout(u765_dout),

	.img_mounted(img_mounted),
	.img_size(img_size[31:0]),
	.img_wp(img_readonly),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(|sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr)
);

/////////////////////////////////////////////////////////////////////////
///////////////////////////// Multiface Two /////////////////////////////
/////////////////////////////////////////////////////////////////////////

wire  [7:0] mf2_dout = (mf2_ram_en & mem_rd) ? mf2_ram_out : 8'hFF;

reg         mf2_nmi = 0;
reg         mf2_en = 0;
reg         mf2_hidden = 0;
reg   [7:0] mf2_ram[8192];
wire        mf2_ram_en = mf2_en & cpu_addr[15:13] == 3'b001;
wire        mf2_rom_en = mf2_en & cpu_addr[15:13] == 3'b000;
reg   [4:0] mf2_pen_index;
reg   [3:0] mf2_crtc_register;
wire [12:0] mf2_store_addr;
reg  [12:0] mf2_ram_a;
reg         mf2_ram_we;
reg   [7:0] mf2_ram_in, mf2_ram_out;

always_comb begin
	casex({ cpu_addr[15:8], cpu_dout[7:6] })
		{ 8'h7f, 2'b00 }: mf2_store_addr = 13'h1fcf;  // pen index
		{ 8'h7f, 2'b01 }: mf2_store_addr = mf2_pen_index[4] ? 13'h1fdf : { 9'h1f9, mf2_pen_index[3:0] }; // border/pen color
		{ 8'h7f, 2'b10 }: mf2_store_addr = 13'h1fef; // screen mode
		{ 8'h7f, 2'b11 }: mf2_store_addr = 13'h1fff; // banking
		{ 8'hbc, 2'bXX }: mf2_store_addr = 13'h1cff; // CRTC register select
		{ 8'hbd, 2'bXX }: mf2_store_addr = { 9'h1db, mf2_crtc_register[3:0] }; // CRTC register value
		{ 8'hf7, 2'bXX }: mf2_store_addr = 13'h17ff; //8255
		{ 8'hdf, 2'bXX }: mf2_store_addr = 13'h1aac; //upper rom
		default: mf2_store_addr = 0;
	endcase
end

always @(posedge clk_sys) begin
	if (mf2_ram_we) begin
		mf2_ram[mf2_ram_a] <= mf2_ram_in;
		mf2_ram_out <= mf2_ram_in;
	end
	else mf2_ram_out <= mf2_ram[mf2_ram_a];
end

always @(posedge clk_sys) begin
	reg old_key_nmi, old_m1, old_io_wr;

	old_key_nmi <= key_nmi;
	old_m1 <= m1;
	old_io_wr <= io_wr;

	if (reset) begin
		mf2_en <= 0;
		mf2_hidden <= |status[15:14];
		mf2_nmi <= 0;
	end

	if(~old_key_nmi & key_nmi & ~mf2_en & ~status[15]) mf2_nmi <= 1;
	if (mf2_nmi & ~old_m1 & m1 & (cpu_addr == 'h66)) begin
		mf2_en <= 1;
		mf2_hidden <= 0;
		mf2_nmi <= 0;
	end
	if (mf2_en & ~old_m1 & m1 & cpu_addr == 'h65) begin
		mf2_hidden <= 1;
	end

	if (~old_io_wr & io_wr & cpu_addr[15:2] == 14'b11111110111010) begin //fee8/feea
		mf2_en <= ~cpu_addr[1] & ~mf2_hidden & ~status[15];
	end else if (~old_io_wr & io_wr & |mf2_store_addr[12:0]) begin //store hw register in MF2 RAM
		if (cpu_addr[15:8] == 8'h7f & cpu_dout[7:6] == 2'b00) mf2_pen_index <= cpu_dout[4:0];
		if (cpu_addr[15:8] == 8'hbc) mf2_crtc_register <= cpu_dout[3:0];
		mf2_ram_a <= mf2_store_addr;
		mf2_ram_in <= cpu_dout;
		mf2_ram_we <= 1;
	end else if (mem_wr & mf2_ram_en) begin //normal MF2 RAM write
		mf2_ram_a <= ram_a[12:0];
		mf2_ram_in <= cpu_dout;
		mf2_ram_we <= 1;
	end else begin //MF2 RAM read
		mf2_ram_a <= ram_a[12:0];
		mf2_ram_we <=0;
	end

end

//////////////////////////////////////////////////////////////////////

wire        playcity_ena = status[24];
wire  [7:0] playcity_dout;
wire  [7:0] playcity_audio_l, playcity_audio_r;
wire        playcity_int_n, playcity_nmi;

playcity playcity
(
	.clock(clk_sys),
	.reset(reset),
	.ena(playcity_ena),
	.phi_n(phi_n),
	.phi_en(phi_en_n),
	.addr(cpu_addr),
	.din(cpu_dout),
	.dout(playcity_dout),
	.cpu_di(cpu_din),
	.m1_n(~m1),
	.iorq_n(~iorq),
	.rd_n(~rd),
	.wr_n(~wr),
	.int_n(playcity_int_n),
	.nmi(playcity_nmi),
	.cursor(cursor),
	.audio_l(playcity_audio_l),
	.audio_r(playcity_audio_r)
);

//////////////////////////////////////////////////////////////////////

wire mouse_rd = io_rd & ~status[19];

wire [7:0] kmouse_dout;
kempston_mouse kmouse
(
	.clk_sys(clk_sys),
	.reset(reset),
	.ps2_mouse(ps2_mouse),
	.addr({cpu_addr[0], ~cpu_addr[4] & ~cpu_addr[10] & mouse_rd, cpu_addr[8]}),
	.dout(kmouse_dout)
);

wire [7:0] smouse_dout;
symbiface_mouse smouse
(
	.clk_sys(clk_sys),
	.reset(reset),
	.ps2_mouse(ps2_mouse),
	.sel((cpu_addr == 16'hFD10) & mouse_rd),
	.dout(smouse_dout)
);

wire [7:0] mmouse_dout;
multiplay_mouse mmouse
(
	.clk_sys(clk_sys),
	.reset(reset),
	.ps2_mouse(ps2_mouse),
	.sel((cpu_addr[15:4] == 12'hF99) & ~cpu_addr[3] & mouse_rd),
	.addr(cpu_addr[2:0]),
	.dout(mmouse_dout)
);

wire [6:0] amouse_dout;
amx_mouse amx_mouse
(
	.clk_sys(clk_sys),
	.reset(reset),
	.ps2_mouse(ps2_mouse),
	.sel(joy1_sel),
	.dout(amouse_dout)
);

/////////////////////////////////////////////////////////////////////////

wire [15:0] cpu_addr;
wire  [7:0] cpu_dout;
wire        phi_n, phi_en_p, phi_en_n;
wire        m1, key_nmi, key_reset;
wire        rd, wr, iorq;
wire        mreq;
wire        field;
wire        cursor;
wire  [9:0] Fn;
wire        tape_rec;
wire  [1:0] mode;
wire        joy1_sel;

wire  [7:0] cpu_din = ram_dout & mf2_dout & fdc_dout & kmouse_dout & smouse_dout & mmouse_dout & playcity_dout;
wire NMI = playcity_nmi | mf2_nmi;
wire        IRQ = ~playcity_int_n;

wire io_rd = rd & iorq;
wire io_wr = wr & iorq;
wire romen;
wire ready;

Amstrad_motherboard motherboard
(
	.reset(reset),
	.clk(clk_sys),
	.ce_16(ce_16),

	.right_shift_mod(st_right_shift_mod),
	.keypad_mod(st_keypad_mod),
	.ps2_key(ps2_key),
	.joy1_sel(joy1_sel),
	.Fn(Fn),

	.no_wait(status[6] & ~tape_motor),
	.ppi_jumpers({1'b1, ~status[44:42]}),
	.crtc_type(~status[2]),
	.sync_filter(1),

	.sna_load(sna_load),
	.sna_cpu_dir(sna_cpu_dir),
	.sna_crtc_addr(sna_crtc_addr),
	.sna_crtc_regs(sna_crtc_regs),
	.sna_ga_inksel(sna_ga_inksel),
	.sna_ga_palette(sna_ga_palette),
	.sna_ga_config(sna_ga_config),
	.sna_ram_config(sna_ram_config),
	.sna_rom_select(sna_rom_select),
	.sna_ppi_a(sna_ppi_a),
	.sna_ppi_b(sna_ppi_b),
	.sna_ppi_c(sna_ppi_c),
	.sna_ppi_control(sna_ppi_control),
	.sna_psg_addr(sna_psg_addr),
	.sna_psg_regs(sna_psg_regs),

	.joy1((status[21] ? amouse_dout : 7'd0) | (status[18] ? joy2 : joy1)),
	.joy2(status[18] ? joy1 : joy2),

	.tape_in(tape_play),
	.tape_out(tape_rec),
	.tape_motor(tape_motor),

	.audio_l(audio_l),
	.audio_r(audio_r),

	.mode(mode),

	.hblank(hbl),
	.vblank(vbl),
	.hsync(hs),
	.vsync(vs),
	.red(r),
	.green(g),
	.blue(b),
	.field(VGA_F1),

	.vram_din(vram_dout),
	.vram_addr(vram_addr),

	.rom_map(rom_map),
	.ram64k(model != 2'd0),
	.mem_rd(mem_rd),
	.mem_wr(mem_wr),
	.mem_addr(ram_a),
	.romen(romen),

	.phi_n(phi_n),
	.phi_en_n(phi_en_n),
	.phi_en_p(phi_en_p),
	.cpu_addr(cpu_addr),
	.cpu_dout(cpu_dout),
	.cpu_din(cpu_din),
	.iorq(iorq),
	.mreq(mreq),
	.rd(rd),
	.wr(wr),
	.m1(m1),
	.ga_ready(ready),
	.nmi(NMI),
	.irq(IRQ),
	.cursor(cursor),

	.key_nmi(key_nmi),
	.key_reset(key_reset)
);

/////////////////////////////////Dandanator/////////////////////
wire [4:0] dan_bank;
wire dan_romdis;
wire dan_ramdis;
//wire [7:0] dan_databus;
wire dan_eeprom_nce;
wire dan_eeprom_nwr;
//wire dan_nnmi;
reg dan_eeprom_loaded = 1'b0;
wire dan_ena = ~dan_eeprom_nce & dan_eeprom_loaded;

CPC_Dandanator dandanator(
    .clk(clk_sys),
    .nRst(~reset),
    .ceP(phi_en_p),
    .ceN(phi_en_n),
    
    .Button(1'b1),
    .Button2(1'b1),
    
    .nRomEn(~romen),
    .nM1(~m1),
    .nMreq(~mreq),
    .nWr(~wr),
    .nRd(~rd),
    .Rdy(ready),
    .A15(cpu_addr[15]),
    .A14(cpu_addr[14]),
    .A13(cpu_addr[13]),
    .DataBusIn(cpu_din),
    //.DataBusOut(dan_databus),
    .DataBusOut(),
    .EXP(),
    
    //.nNMI(dan_nnmi),
	.nNMI(),
    .Romdis(dan_romdis),
    .Ramdis(dan_ramdis),
    .nEp_Ce(dan_eeprom_nce),
    .nEp_Wr(dan_eeprom_nwr),
    .Ep_A18_14(dan_bank),
    
    .CHG_Txd(1'b1),
    .CHG_Rxd(1'b1)
);
//////////////////////////////////////////////////////////////////////

assign CLK_VIDEO = clk_sys;

reg ce_pix_fs;
always @(posedge CLK_VIDEO) begin
	reg [1:0] mode_fs;
	reg [1:0] mode_next;
	reg [1:0] cycle;
	reg       old_vsync;

	ce_pix_fs <= 0;

	if (ce_16) begin
		cycle <= cycle + 1'd1;

		case(mode_fs)
			2:   ce_pix_fs <= 1;
			1:   ce_pix_fs <= !cycle[0];
			0,3: ce_pix_fs <= !cycle[1:0];
		endcase

		old_vsync <= vs;
		if(~old_vsync & vs) begin
			mode_fs <= mode_next; //HQ2x friendly vmode
			mode_next <= 0;
			cycle <= 0;
		end

		// choose highest pixel rate during the whole active time
		if (~hbl && ~vbl && ~&mode && mode > mode_next) mode_next <= mode;
	end
end

wire ce_pix = (hq2x | status[30]) ? ce_pix_fs : ce_16;

wire [1:0] b, g, r;
wire       hs, vs, hbl, vbl;

color_mix color_mix
(
	.clk_vid(CLK_VIDEO),
	.ce_pix(ce_pix),
	.mix(status[13:11]),

	.HSync_in(hs),
	.VSync_in(vs),
	.HBlank_in(hbl),
	.VBlank_in(vbl),
	.B_in(b),
	.G_in(g),
	.R_in(r),

	.HSync_out(HSync),
	.VSync_out(VSync),
	.HBlank_out(HBlank),
	.VBlank_out(VBlank),
	.B_out(B),
	.G_out(G),
	.R_out(R)
);

wire [7:0] B, G, R;
wire       HSync, VSync, HBlank, VBlank;

wire [1:0] scale = status[10:9];
wire       hq2x = (scale == 1);

assign VGA_SL = scale[1] ? scale : 2'b00;

reg [2:0] interlace;
always @(posedge CLK_VIDEO) begin
	reg old_vs;
	
	old_vs <= vs;
	if(~old_vs & vs) interlace <= {interlace[1:0], VGA_F1};
end

video_mixer #(.LINE_LENGTH(800), .GAMMA(1)) video_mixer
(
	.*,
	.R(R[7:0] | {8{progress_pix}}),
	.G(G[7:0] | {8{progress_pix}}),
	.B(B[7:0] | {8{progress_pix}}),
	.VGA_DE(vga_de),
	.freeze_sync(),
	.scandoubler((scale || forced_scandoubler) && !interlace)
);

reg en270p;
always @(posedge CLK_VIDEO) begin
	en270p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
end

wire [1:0] ar = status[26:25];
wire vcrop_en = status[27];
wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),

	.ARX((!ar) ? 12'd4 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd3 : 12'd0),
	.CROP_SIZE((en270p & vcrop_en) ? 10'd270 : 10'd0),
	.CROP_OFF(0),
	.SCALE(status[29:28])
);

//////////////////////////////////////////////////////////////////////

wire [7:0] audio_l, audio_r;

wire [8:0] audio_sys_l = audio_l + {tape_rec, 1'b0, tape_play & status[20], 3'd0};
wire [8:0] audio_sys_r = audio_r + {tape_rec, 1'b0, tape_play & status[20], 3'd0};

assign AUDIO_S   = 0;
assign AUDIO_MIX = status[8:7];
assign AUDIO_L   = {audio_sys_l + (playcity_ena ? playcity_audio_l : audio_sys_l), 7'd0};
assign AUDIO_R   = {audio_sys_r + (playcity_ena ? playcity_audio_r : audio_sys_r), 7'd0};

//////////////////////////////////////////////////////////////////////

wire tape_play = tape_ready ? tape_read : tape_adc;

wire tape_adc, tape_adc_act;
ltc2308_tape ltc2308_tape
(
	.clk(CLK_50M),
	.ADC_BUS(ADC_BUS),
	.dout(tape_adc),
	.active(tape_adc_act)
);

endmodule
