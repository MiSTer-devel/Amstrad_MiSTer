//============================================================================
//  Amstrad CPC 6128
// 
//  Port to MiST/MiSTer.
//  Copyright (C) 2018 Sorgelig
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
	inout  [44:0] HPS_BUS,

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

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
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
	output        SDRAM_nWE
);

assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VIDEO_ARX = status[4] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[4] ? 8'd9  : 8'd3;

`include "build_id.v"
localparam CONF_STR = {
	"Amstrad;;",
	"-;",
	"S,DSK,Mount Disk;",
	"-;",
	"O4,Aspect ratio,4:3,16:9;",
	"O9A,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"OBD,Colors,All,Mono-G,Mono-R,Mono-B,Mono-W;",
	"O78,Stereo mix,none,25%,50%,100%;",
	"-;",
	"O1,Model,Amstrad,Schneider;",
	"O2,CRTC,1,0;",
	"O3,Wait states,Quick,Slow;",
	"-;",
	"R0,Reset;",
	"J,Fire 1,Fire 2;",
	"V,v1.01.",`BUILD_DATE
};

//////////////////////////////////////////////////////////////////////////

wire clk_vid;
wire clk_sys;
wire locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid),
	.outclk_1(clk_sys),
	.locked(locked)
);

reg ce_4n;
reg ce_4p, ce_ref, ce_u765;
reg ce_16;
always @(negedge clk_sys) begin
	reg [3:0] div4  = 0;
	reg [1:0] div16 = 0;

	div4 <= div4 + 1'd1;

	ce_4n   <= !div4;

	ce_4p   <= (div4 == 8);
	ce_u765 <= (div4 == 8);
	ce_ref  <= (div4 == 8);

	div16 <= div16 + 1'd1;

	ce_16  <= !div16;
end

reg ce_vid;
always @(negedge clk_vid) begin
	reg [2:0] div16 = 0;

	div16 <= div16 + 1'd1;
	ce_vid <= !div16;
end

//////////////////////////////////////////////////////////////////////////

wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire [63:0] img_size;
wire        img_readonly;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
reg         ioctl_wait;

wire        ps2_clk;
wire        ps2_data;

wire  [1:0] buttons;
wire  [5:0] joy1;
wire  [5:0] joy2;
wire [31:0] status;

wire        forced_scandoubler;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.conf_str(CONF_STR),
	.HPS_BUS(HPS_BUS),

	.img_mounted(img_mounted),
	.img_size(img_size),
	.sd_conf(0),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),

	.ps2_kbd_clk_out(ps2_clk),
	.ps2_kbd_data_out(ps2_data),

	.joystick_0(joy1),
	.joystick_1(joy2),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),

	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait)
);

wire        rom_download = !ioctl_index & ioctl_download;
wire        reset = RESET | status[0] | buttons[1] | rom_download;

reg         boot_wr = 0;
reg  [22:0] boot_a;
reg   [7:0] boot_dout;

always @(posedge clk_sys) begin

	if(rom_download & ioctl_wr) begin
		ioctl_wait <= 1;
		boot_dout <= ioctl_dout;

		boot_a[13:0] <= ioctl_addr[13:0];

		case(ioctl_addr[24:14])
				  0: boot_a[22:14] <= 9'h000;
				  1: boot_a[22:14] <= 9'h100;
				  2: boot_a[22:14] <= 9'h107;
		  default: ioctl_wait    <= 0;
		endcase
	end

	if(ce_ref) begin
		boot_wr <= ioctl_wait;
		if(boot_wr & ioctl_wait) {boot_wr, ioctl_wait} <= 0;
	end
end

//////////////////////////////////////////////////////////////////////////

wire        ram_w;
wire        ram_r;
wire [22:0] ram_a;
wire  [7:0] ram_din;
wire  [7:0] ram_dout;

wire  [7:0] zram_dout;
wire [15:0] zram_addr;

assign SDRAM_CLK = clk_sys;

zsdram zsdram
(
	.*,

	.init(~locked),
	.clk(clk_sys),
	.clkref(ce_ref),

	.oe  (reset ? 1'b0      : ram_r),
	.we  (reset ? boot_wr   : ram_w),
	.addr(reset ? boot_a    : ram_a),
	.din (reset ? boot_dout : ram_din),
	.dout(ram_dout),

	.zram_addr(zram_addr),
	.zram_dout(zram_dout)
);

reg [7:0] rom_mask;
always_comb begin
	casex(ram_a[22:14])
	  'h0XX: rom_mask = 0;
	  'h100: rom_mask = 0;
	  'h107: rom_mask = 0;
	default: rom_mask = 'hFF;
	endcase
end

//////////////////////////////////////////////////////////////////////////

wire [3:0] fdc_sel;
wire       fdc_wr;
wire       fdc_rd;
wire [7:0] fdc_din;

reg  [7:0] fdc_dout;
always_comb begin
	case({fdc_rd,fdc_sel[3:1]})
		'b1_000: fdc_dout = motor;     // motor read 
		'b1_010: fdc_dout = u765_dout; // u765 read 
		default: fdc_dout = 8'hFF;
	endcase
end

reg motor = 0;
always @(posedge clk_sys) begin
	reg old_wr;
	
	old_wr <= fdc_wr;
	if(~old_wr && fdc_wr && !fdc_sel[3:1]) begin
		motor <= fdc_din[0];
	end
	
	if(img_mounted) motor <= 0;
end

wire [7:0] u765_dout;
wire       u765_sel = (fdc_sel[3:1] == 'b010);

reg u765_ready = 0;
always @(posedge clk_sys) if(img_mounted) u765_ready <= |img_size;

u765 u765
(
	.reset(status[0]),

	.clk_sys(clk_sys),
	.ce(ce_u765),

	.a0(fdc_sel[0]),
	.ready(u765_ready), // & motor),
	.nRD(~(u765_sel & fdc_rd)),
	.nWR(~(u765_sel & fdc_wr)),
	.din(fdc_din),
	.dout(u765_dout),

	.img_mounted(img_mounted),
	.img_size(img_size[19:0]),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr)
);

//////////////////////////////////////////////////////////////////////////

wire  [3:0] ppi_jumpers = {2'b11, ~status[1], 1'b1};
wire        crtc_type = ~status[2];
wire        wait_time = status[3];

Amstrad_motherboard motherboard
(
	.RESET_n(~reset),
	.CLK4MHz(clk_sys & ce_4p),
	.nCLK4MHz(clk_sys & ce_4n),

	.PS2_CLK(ps2_clk),
	.PS2_DATA(ps2_data),

	.CLK16MHz(clk_sys & ce_16),

	.ga_shunt(wait_time),
	.ppi_jumpers(ppi_jumpers),
	.crtc_type(crtc_type),

	.JOYSTICK1(joy1),
	.JOYSTICK2(joy2),

	.fdc_sel(fdc_sel),
	.fdc_wr(fdc_wr),
	.fdc_rd(fdc_rd),
	.fdc_din(fdc_dout),
	.fdc_dout(fdc_din),

	.audio_AB(audio_l),
	.audio_BC(audio_r),

	.VMODE(vmode),
	.HBLANK(hbl),
	.VBLANK(vbl),
	.HSYNC(hs),
	.VSYNC(vs),
	.RED(r),
	.GREEN(g),
	.BLUE(b),

	.ram_R(ram_r),
	.ram_W(ram_w),
	.ram_A(ram_a),
	.ram_Din(ram_dout | rom_mask),
	.ram_Dout(ram_din),

	.zram_din(zram_dout),
	.zram_addr(zram_addr)
);

//////////////////////////////////////////////////////////////////////

wire [1:0] b, g, r;
wire       hs, vs, hbl, vbl;

color_mix color_mix
(
	.clk_vid(clk_vid),
	.ce_pix(ce_vid),
	.mono(status[13:11]),

	.HSync_in(hs),
	.VSync_in(vs),
	.HBlank_in(hbl),
	.VBlank_in(vbl),
	.B_in(b),
	.G_in(g),
	.R_in(r),

	.HSync_out(HS),
	.VSync_out(VS),
	.HBlank_out(HBL),
	.VBlank_out(VBL),
	.B_out(mb),
	.G_out(mg),
	.R_out(mr)
);

wire [7:0] mb, mg, mr;
wire       HS, VS, HBL, VBL;

wire [1:0] vmode;
reg        ce_pix;
always @(posedge clk_vid) begin
	reg       old_vs;
	reg [1:0] pxsz;
	reg [1:0] cnt;
	
	ce_pix <= 0;
	if(ce_vid) begin
		cnt <= cnt + 1'd1;
		if(cnt == pxsz) begin
			cnt    <= 0;
			ce_pix <= 1;
		end
		
		old_vs <= VS;
		if(old_vs & ~VS) begin
			cnt <= 0;
			pxsz <= {hq2x,hq2x} >> vmode;
		end
	end
end

video_cleaner video_cleaner
(
	.clk_vid(clk_vid),
	.ce_pix(ce_pix),

	.B(mb),
	.G(mg),
	.R(mr),

	.HSync(HS),
	.VSync(VS),
	.HBlank(HBL),
	.VBlank(VBL),

	.VGA_R(R),
	.VGA_G(G),
	.VGA_B(B),
	.VGA_VS(VSync),
	.VGA_HS(HSync),
	.HBlank_out(HBlank),
	.VBlank_out(VBlank)
);

wire [7:0] B, G, R;
wire       HSync, VSync, HBlank, VBlank;

wire [1:0] scale = status[10:9];
wire       hq2x = (scale == 1);

video_mixer #(800) video_mixer
(
	.*,

	.clk_sys(clk_vid),
	.ce_pix_out(CE_PIXEL),

	.scanlines({scale==3, scale==2}),
	.scandoubler(scale || forced_scandoubler),
	.mono(0)
);

assign CLK_VIDEO = clk_vid;

//////////////////////////////////////////////////////////////////////////

wire [7:0] audio_l, audio_r;

assign AUDIO_S   = 0;
assign AUDIO_MIX = status[8:7];

assign AUDIO_L = {audio_l,audio_l};
assign AUDIO_R = {audio_r,audio_r};

endmodule
