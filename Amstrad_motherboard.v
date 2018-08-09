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

	input   [6:0] joy1,
	input   [6:0] joy2,
	input  [10:0] ps2_key,
	input  [24:0] ps2_mouse,
	output        key_nmi,
	output  [9:0] Fn,

	input   [3:0] ppi_jumpers,
	input         crtc_type,
	input         resync,
	input         no_wait,

	input         tape_in,
	output        tape_out,
	output        tape_motor,

	output  [7:0] audio_l,
	output  [7:0] audio_r,

	input         pal,
	output        ce_pix,
	output        ce_pix_fs,
	output  [7:0] red,
	output  [7:0] green,
	output  [7:0] blue,
	output        hblank,
	output        vblank,
	output        hsync,
	output        vsync,
	output        field,

	input  [15:0] vram_din,
	output [14:0] vram_addr,

	input         ram64k,
	output [22:0] mem_addr,
	output        mem_rd,
	output        mem_wr,
	output [15:0] cpu_addr,
	output  [7:0] cpu_dout,
	input   [7:0] cpu_din,
	output        io_wr,
	output        io_rd,
	output        m1,
	input         nmi
);

assign vram_addr = {MA[13:12], RA[2:0], MA[9:0]} - crtc_shift;

assign io_rd = ~(RD_n | IORQ_n);
assign io_wr = ~(WR_n | IORQ_n);

assign mem_rd = ~(RD_n | MREQ_n);
assign mem_wr = ~(WR_n | MREQ_n);

assign cpu_dout = D;
assign cpu_addr = A;
assign m1 = ~M1_n;

reg [1:0] phase;
always @(posedge clk) if(ce_4p) phase <= phase + 1'd1;

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
	.di(crtc_dout & ppi_dout & cpu_din),

	.rd_n(RD_n),
	.wr_n(WR_n),
	.iorq_n(IORQ_n),
	.mreq_n(MREQ_n),
	.m1_n(M1_n),
	.rfsh_n(RFSH_n),

	.busrq_n(1),
	.int_n(~INT),
	.nmi_n(~nmi),
	.wait_n((phase == 0) | (IORQ_n & MREQ_n) | no_wait)
);

wire crtc_hs, crtc_vs, crtc_de;
wire [13:0] MA;
wire  [4:0] RA;
wire  [7:0] crtc_dout;
UM6845R CRTC
(
	.CLOCK(clk),
	.CLKEN((phase == 0) & ce_4p),
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
	.FIELD(field),

	.MA(MA),
	.RA(RA)
);

wire crtc_shift;
Amstrad_GA GateArray
(
	.RESET(reset),

	.CLK(clk),
	.CE_4(ce_4p),
	.CE_16(ce_16),

	.phase(phase),
	.resync(resync),

	.INTack(~M1_n & ~IORQ_n),
	.WE((A[15:14] == 1) & io_wr),
	.D(D),

	.crtc_shift(crtc_shift),
	.crtc_vs(crtc_vs),
	.crtc_hs(crtc_hs),
	.crtc_de(crtc_de),
	.vram_D(vram_din),

	.INT(INT),

	.PAL(pal),
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

i8255 PPI
(
	.reset(reset),
	.clk_sys(clk),

	.addr(A[9:8]),
	.idata(D),
	.odata(ppi_dout),
	.cs(~A[11]),
	.we(io_wr),
	.oe(io_rd),

	.ipa(portAin), 
	.opa(portAout),
	.ipb({tape_in, 2'b11, ppi_jumpers, crtc_vs}),
	.opb(),
	.ipc(8'hFF), 
	.opc(portC)
);

assign tape_motor = portC[4];
assign tape_out   = portC[5];

assign audio_l = {1'b0, ch_a[7:1]} + {2'b00, ch_b[7:2]};
assign audio_r = {1'b0, ch_c[7:1]} + {2'b00, ch_b[7:2]};

wire [7:0] ch_a, ch_b, ch_c;
YM2149 PSG
(
	.RESET(reset),

	.CLK(clk),
	.CE((phase == 0) & ce_4n),
	.SEL(0),
	.MODE(0),

	.BC(portC[6]),
	.BDIR(portC[7]),
	.DI(portAout),
	.DO(portAin),

	.CHANNEL_A(ch_a),
	.CHANNEL_B(ch_b),
	.CHANNEL_C(ch_c),

	.IOA_in(kbd_out),
	.IOB_in(8'hFF)
);

wire [7:0] kbd_out;
hid HID
(
	.reset(reset),
	.clk(clk),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),

	.joystick1(joy1),
	.joystick2(joy2),

	.Y(portC[3:0]),
	.X(kbd_out),
	.key_nmi(key_nmi),
	.Fn(Fn)
);

endmodule
