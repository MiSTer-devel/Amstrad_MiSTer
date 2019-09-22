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
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
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

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3;

`include "build_id.v"
localparam CONF_STR = {
	"Amstrad;;",
	"S0,DSK,Mount A:;",
	"S1,DSK,Mount B:;",
	"-;",
	"F,E??,Load expansion;",
	"F,CDT,Load tape;",
	"OK,Tape sound,Disabled,Enabled;",
	"-;",
	"O1,Aspect ratio,4:3,16:9;",
	"O9A,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"OBD,Display,Color(GA),Color(ASIC),Green,Amber,Cyan,White;",
	"O2,CRTC,Type 1,Type 0;",
	"O78,Stereo mix,none,25%,50%,100%;",
	"-;",
	"OI,Joysticks swap,No,Yes;",
	"OJ,Mouse,Enabled,Disabled;",
	"-;",
	"OEF,Multiface 2,Enabled,Hidden,Disabled;",
	"O6,CPU timings,Original,Fast;",
	"OGH,FDC,Original,Fast,Disabled;",
	"-;",
	"O5,Distributor,Amstrad,Schneider;",
	"O4,Model,CPC 6128,CPC 664;",
	"R0,Reset & apply model;",
	"J,Fire 1,Fire 2,Fire 3;",
	"V,v",`BUILD_DATE
};

//////////////////////////////////////////////////////////////////////////

wire clk_sys;
wire locked;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_sys),
	.outclk_1(SDRAM_CLK),
	.locked(locked)
);

reg ce_4n;
reg ce_4p, ce_ref, ce_u765;
reg ce_16;
always @(negedge clk_sys) begin
	reg [3:0] div = 0;

	div     <= div + 1'd1;

	ce_4n   <= (div == 8);
	ce_4p   <= !div;
	ce_ref  <= !div;

	ce_u765 <= !div[2:0]; //8 MHz
	ce_16   <= !div[1:0]; //16 MHz
end

//////////////////////////////////////////////////////////////////////////

wire [31:0] sd_lba;
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire        sd_ack;
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
wire        ioctl_wait = romdl_wait;

wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

wire  [1:0] buttons;
wire  [6:0] joy1;
wire  [6:0] joy2;
wire [31:0] status;

wire        forced_scandoubler;

hps_io #(.STRLEN($size(CONF_STR)>>3), .VDNUM(2)) hps_io
(
	.clk_sys(clk_sys),
	.conf_str(CONF_STR),
	.HPS_BUS(HPS_BUS),

	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_readonly(img_readonly),
	.sd_conf(0),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),

	.joystick_0(joy1),
	.joystick_1(joy2),

	.buttons(buttons),
	.status(status),
	.status_in({status[31:21],~status[20],status[19:0]}),
	.status_set(Fn[1]),
	.forced_scandoubler(forced_scandoubler),

	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_file_ext(ioctl_file_ext),
	.ioctl_wait(ioctl_wait)
);

wire        rom_download = ioctl_download && (ioctl_index[4:0] < 4);
wire        tape_download = ioctl_download && (ioctl_index == 4);

reg         boot_wr = 0;
reg  [22:0] boot_a;
reg   [1:0] boot_bank;
reg   [7:0] boot_dout;

reg         tape_wr = 0;
wire        tape_ack;

wire        rom_mask = ram_a[22] & (~rom_map[map_addr] | &{map_addr,status[15]});
reg         rom_map[256] = '{default:0};
reg   [7:0] map_addr;
always @(posedge clk_sys) map_addr <= ram_a[21:14];

reg         romdl_wait = 0;
always @(posedge clk_sys) begin
	reg [8:0] page = 0;
	reg       combo = 0;
	reg       old_download;
	reg       old_tape_ack;

	if(rom_download & ioctl_wr) begin
		romdl_wait <= 1;
		boot_dout <= ioctl_dout;

		boot_a[13:0] <= ioctl_addr[13:0];

		if(ioctl_index) begin
			boot_a[22]    <= page[8];
			boot_a[21:14] <= page[7:0] + ioctl_addr[21:14];
			boot_bank     <= {1'b0, &ioctl_index[7:6]};
		end
		else begin
			case(ioctl_addr[24:14])
					0,4: boot_a[22:14] <= 9'h000;
					1,5: boot_a[22:14] <= 9'h100;
					2,6: boot_a[22:14] <= 9'h107;
					3,7: boot_a[22:14] <= 9'h1ff; //MF2
			  default:    romdl_wait <= 0;
			endcase

			case(ioctl_addr[24:14])
			  0,1,2,3: boot_bank <= 0;
			  4,5,6,7: boot_bank <= 1;
			endcase
		end
	end

	if(ce_ref) begin
		boot_wr <= romdl_wait;
		if(boot_wr & romdl_wait) begin
			boot_wr <= 0;
			// load expansion ROM into both banks if manually loaded or boot name is boot.eXX
			if((ioctl_index[7:6]==1 || ioctl_index[5:0]) && !boot_bank) boot_bank <= 1;
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

	old_tape_ack <= tape_ack;
	if(tape_download) begin
		if(old_tape_ack ^ tape_ack) tape_wr <= 0;
		if(ioctl_wr) begin
			tape_wr <= 1;
			boot_dout <= ioctl_dout;
			boot_a <= ioctl_addr[22:0];
		end
	end
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

	.oe  (reset ? 1'b0      : mem_rd & ~mf2_ram_en & ~rom_mask),
	.we  (reset ? boot_wr   : mem_wr & ~mf2_ram_en & ~mf2_rom_en),
	.addr(reset ? boot_a    : mf2_rom_en ? { 9'h1ff, cpu_addr[13:0] }: ram_a),
	.bank(reset ? boot_bank : { 1'b0, model } ),
	.din (reset ? boot_dout : cpu_dout),
	.dout(ram_dout),

	.vram_addr({2'b10,vram_addr,1'b0}),
	.vram_dout(vram_dout),

	.tape_addr(tape_download ? boot_a : tape_play_addr),
	.tape_din(boot_dout),
	.tape_dout(tape_dout),
	.tape_wr(tape_wr),
	.tape_rd(tape_rd),
	.tape_ack(tape_ack)
);

reg model = 0;
reg reset;

always @(posedge clk_sys) begin
	if(reset) model <= status[4];
	reset <= RESET | status[0] | buttons[1] | rom_download;
end

////////////////////// CDT playback ///////////////////////////////

wire        tape_read;
wire        tape_data_req;
reg         tape_data_ack;
reg         tape_reset;
reg         tape_rd;
reg   [7:0] tape_dout;
reg  [22:0] tape_play_addr;
reg  [22:0] tape_last_addr;
wire        tape_motor;

always @(posedge clk_sys) begin
    reg old_tape_ack;

    if (reset | Fn[2]) begin
        tape_play_addr <= 0;
        tape_last_addr <= 0;
        tape_rd <= 0;
        tape_reset <= 1;
    end else begin
        old_tape_ack <= tape_ack;
        tape_reset <= 0;
        if (tape_download) begin
            tape_play_addr <= 0;
            tape_last_addr <= boot_a;
            tape_reset <= 1;
        end
        if (!ioctl_download && tape_rd && tape_ack ^ old_tape_ack) begin
            tape_data_ack <= tape_data_req;
            tape_rd <= 0;
            tape_play_addr <= tape_play_addr + 1'd1;
        end else if (!ioctl_download && tape_play_addr <= tape_last_addr && !tape_rd && (tape_data_req ^ tape_data_ack)) begin
            tape_rd <= 1;
        end
    end
end

tzxplayer tzxplayer
(
    .clk(clk_sys),
    .ce(1),
    .restart_tape(tape_reset),
    .host_tap_in(tape_dout),
    .tzx_req(tape_data_req),
    .tzx_ack(tape_data_ack),
    .cass_read(tape_read),
    .cass_motor(tape_motor)
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
	
	if(img_mounted) motor <= 0;
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
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr)
);

/////////////////////////////////////////////////////////////////////////
///////////////////////////// Multiface Two /////////////////////////////
/////////////////////////////////////////////////////////////////////////

wire  [7:0] mf2_dout = (mf2_ram_en & mem_rd) ? mf2_ram_out : 8'hFF;

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
		NMI <= 0;
	end

	if(~old_key_nmi & key_nmi & ~mf2_en & ~status[15]) NMI <= 1;
	if (NMI & ~old_m1 & m1 & (cpu_addr == 'h66)) begin
		mf2_en <= 1;
		mf2_hidden <= 0;
		NMI <= 0;
	end
	if (mf2_en & ~old_m1 & m1 & cpu_addr == 'h65) begin
		mf2_hidden <= 1;
	end

	if (~old_io_wr & io_wr & cpu_addr[15:2] == 14'b11111110111010) begin //fee8/feea
		mf2_en <= ~cpu_addr[1] & ~mf2_hidden;
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

/////////////////////////////////////////////////////////////////////////

wire [15:0] cpu_addr;
wire  [7:0] cpu_dout;
wire        m1, key_nmi, NMI;
wire        io_wr, io_rd;
wire        ce_pix_fs;
wire        field;
wire  [9:0] Fn;
wire        tape_rec;

Amstrad_motherboard motherboard
(
	.reset(reset),
	.clk(clk_sys),
	.ce_4p(ce_4p),
	.ce_4n(ce_4n),
	.ce_16(ce_16),

	.ps2_key(ps2_key),
	.Fn(Fn),

	.no_wait(status[6]),
	.ppi_jumpers({2'b11, ~status[5], 1'b1}),
	.crtc_type(~status[2]),
	.resync(1),

	.joy1(status[18] ? joy2 : joy1),
	.joy2(status[18] ? joy1 : joy2),

	.tape_in(tape_play),
	.tape_out(tape_rec),
	.tape_motor(tape_motor),

	.audio_l(audio_l),
	.audio_r(audio_r),

	.pal(|status[13:11]),
	.ce_pix_fs(ce_pix_fs),
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

	.ram64k(model),
	.mem_rd(mem_rd),
	.mem_wr(mem_wr),
	.mem_addr(ram_a),
	.cpu_addr(cpu_addr),
	.cpu_dout(cpu_dout),
	.cpu_din(ram_dout & mf2_dout & fdc_dout & kmouse_dout & smouse_dout & mmouse_dout),
	.io_wr(io_wr),
	.io_rd(io_rd),
	.m1(m1),
	.nmi(NMI),

	.key_nmi(key_nmi)
);

//////////////////////////////////////////////////////////////////////

wire ce_pix = hq2x ? ce_pix_fs : ce_16;

wire [7:0] b, g, r;
wire       hs, vs, hbl, vbl;

color_mix color_mix
(
	.clk_vid(clk_sys),
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
always @(posedge clk_sys) begin
	reg old_vs;
	
	old_vs <= vs;
	if(~old_vs & vs) interlace <= {interlace[1:0], VGA_F1};
end

video_mixer #(800) video_mixer
(
	.*,

	.ce_pix_out(CE_PIXEL),

	.scanlines(0),
	.scandoubler((scale || forced_scandoubler) && !interlace),
	.mono(0)
);

assign CLK_VIDEO = clk_sys;

//////////////////////////////////////////////////////////////////////

wire [7:0] audio_l, audio_r;

assign AUDIO_S   = 0;
assign AUDIO_MIX = status[8:7];

assign AUDIO_L = {audio_l - audio_l[7:2] + {tape_rec, 1'b0, tape_play & status[20], 3'd0},8'd0};
assign AUDIO_R = {audio_r - audio_r[7:2] + {tape_rec, 1'b0, tape_play & status[20], 3'd0},8'd0};

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
