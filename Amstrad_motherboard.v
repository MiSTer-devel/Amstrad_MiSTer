/*

	Converted to verilog optimized and simplified
	(C) 2018 Sorgelig


--    {@{@{@{@{@{@
--  {@{@{@{@{@{@{@{@  This code is covered by CoreAmstrad synthesis r004
--  {@    {@{@    {@  A core of Amstrad CPC 6128 running on MiST-board platform
--  {@{@{@{@{@{@{@{@
--  {@  {@{@{@{@  {@  CoreAmstrad is implementation of FPGAmstrad on MiST-board
--  {@{@        {@{@   Contact : renaudhelias@gmail.com
--  {@{@{@{@{@{@{@{@   @see http://code.google.com/p/mist-board/
--    {@{@{@{@{@{@     @see FPGAmstrad at CPCWiki
--
*/

module Amstrad_motherboard
(
	input         reset,

	input         clk,
	input         ce_4p,
	input         ce_4n,
	input         ce_16,

	input   [5:0] joy1,
	input   [5:0] joy2,
	input  [10:0] ps2_key,
	output        key_nmi,

	input   [3:0] ppi_jumpers,
	input         crtc_type,
	input         no_wait,

	output  [7:0] audio_l,
	output  [7:0] audio_r,

	output        ce_pix,
	output        ce_pix_fs,
	output  [7:0] red,
	output  [7:0] green,
	output  [7:0] blue,
	output        hblank,
	output        vblank,
	output        hsync,
	output        vsync,

	input  [15:0] vram_din,
	output [14:0] vram_addr,

	input         ram64k,
	output [22:0] mem_addr,
	output  [7:0] mem_dout,
	input   [7:0] mem_din,
	output        mem_rd,
	output        mem_wr,
	output [15:0] cpu_addr,
	output  [7:0] io_dout,
	input   [7:0] io_din,
	output        io_wr,
	output        io_rd,
	output        m1,
	input         nmi
);

assign vram_addr = {MA[13:12], RA[2:0], MA[9:0]};

assign io_rd = (~RD_n) & (~IORQ_n);
assign io_wr = (~WR_n) & (~IORQ_n);
assign io_dout = D;

assign mem_rd = (~RD_n) & (~MREQ_n);
assign mem_wr = (~WR_n) & (~MREQ_n);
assign mem_dout = D;

assign cpu_addr = A;
assign m1 = (~M1_n);


wire [15:0] A;
wire  [7:0] D;
wire RD_n;
wire WR_n;
wire MREQ_n;
wire IORQ_n;
wire RFSH_n;
wire INT;
wire M1_n;

T80pa CPU
(
	.reset_n(~reset),
	
	.clk(clk),
	.cen_p(ce_4p),
	.cen_n(ce_4n),

	.a(A),
	.do(D),
	.di(crtc_dout & ppi_dout & (mem_rd ? mem_din : 8'hFF) & io_din),

	.rd_n(RD_n),
	.wr_n(WR_n),
	.iorq_n(IORQ_n),
	.mreq_n(MREQ_n),
	.m1_n(M1_n),
	.rfsh_n(RFSH_n),

	.busrq_n(1),
	.int_n(~INT),
	.nmi_n(~nmi),
	.wait_n(cyc1MHz | (IORQ_n & MREQ_n) | no_wait)
);

wire crtc_hs, crtc_vs, crtc_de;
wire [13:0] MA;
wire  [4:0] RA;
wire  [7:0] crtc_dout;
MC6845 CRTC
(
	.CLOCK(clk),
	.CLKEN(cyc1MHz & ce_4p),
	.nRESET(~reset),
	.CRTC_TYPE(crtc_type),

	.ENABLE(io_rd | io_wr),
	.nCS(A[14]),
	.R_nW(A[9]),
	.RS(A[8]),
	.DI(~RD_n ? 8'hFF : D),
	.DO(crtc_dout),

	.VSYNC(crtc_vs),
	.HSYNC(crtc_hs),
	.DE(crtc_de),
	.LPSTB(0),

	.MA(MA),
	.RA(RA)
);

wire cyc1MHz;
Amstrad_GA GateArray
(
	.RESET(reset),

	.CLK(clk),
	.CE_4(ce_4p),
	.CE_16(ce_16),

	.cyc1MHz(cyc1MHz),

	.INTack(~M1_n & ~IORQ_n),
	.WE((A[15:14] == 1) & io_wr),
	.D(D),

	.crtc_vs(crtc_vs),
	.crtc_hs(crtc_hs),
	.crtc_de(crtc_de),
	.vram_D(vram_din),

	.INT(INT),

	.CE_PIX(ce_pix),
	.CE_PIX_FS(ce_pix_fs),
	.RED(red),
	.GREEN(green),
	.BLUE(blue),
	.VBLANK(vblank),
	.HBLANK(hblank),
	.HSYNC(hsync),
	.VSYNC(vsync)
);

Amstrad_MMU MMU
(
	.CLK(clk),
	.reset(reset),
	.ram64k(ram64k),
	.A(A),
	.D(D),
	.io_WR(io_wr),
	.mem_WR(mem_wr),
	.ram_A(mem_addr)
);

wire [7:0] ppi_dout;
wire [7:0] portC;
wire [7:0] portAout;
wire [7:0] portAin;
pio PPI
(
	.addr(A[9:8]),
	.datain(D),
	.cs(A[11]),
	.iowr(~io_wr),
	.iord(~io_rd),
	.cpuclk(clk),  // (no clocked this component normaly, so let's overclock it)

	.pbi({3'b111, ppi_jumpers, crtc_vs}),
	.pai(portAin),
	.pao(portAout),
	.pco(portC),
	.do(ppi_dout)
);

YM2149 PSG
(
	.reset_l(~reset),

	.clk(clk),
	.ena(cyc1MHz & ce_4n),
	.i_sel_l(1),

	.i_a8(1),
	.i_a9_l(0),
	.i_bc1(portC[6]),
	.i_bc2(1),
	.i_bdir(portC[7]),
	.i_da(portAout),
	.o_da(portAin),

	.o_audio_l(audio_l),
	.o_audio_r(audio_r),

	.i_ioa(kbd_out),
	.i_iob(8'hFF)
);

wire [7:0] kbd_out;
keyboard KBD
(
	.clk(clk),
	.ce(ce_4p),
	.joystick1(joy1),
	.joystick2(joy2),
	.portc(portC[3:0]),
	.ps2_key(ps2_key),
	.key_nmi(key_nmi),
	.porta(kbd_out)
);

endmodule
