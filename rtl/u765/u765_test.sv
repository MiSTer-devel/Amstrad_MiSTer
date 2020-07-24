module u765_test
(
	input            clk_sys,   // sys clock
	input            ce,        // chip enable
	input            reset,	    // reset
	input      [1:0] ready,     // disk is inserted in MiST(er)
	input      [1:0] motor,     // drive motor
	input      [1:0] available, // drive available (fake ready signal for SENSE DRIVE command)
	input            fast,      // "Fast" mode - immediate seek and sector read/write
	input            a0,
	input            nRD,       // i/o read
	input            nWR,       // i/o write
	input      [7:0] din,       // i/o data in
	output     [7:0] dout,      // i/o data out

	input      [1:0] img_mounted, // signaling that new image has been mounted
	input            img_wp,      // write protect. latched at img_mounted
	input     [31:0] img_size,    // size of image in bytes
	output reg[31:0] sd_lba,
	output reg [1:0] sd_rd,
	output reg [1:0] sd_wr,
	input            sd_ack,
	input      [8:0] sd_buff_addr,
	input      [7:0] sd_buff_dout,
	output     [7:0] sd_buff_din,
	input            sd_buff_wr
);

u765 #(100) u765 (
	.clk_sys(clk_sys),
	.ce(ce),
	.reset(reset),
	.ready(ready),
	.motor(motor),
	.available(available),
	.fast(fast),
	.a0(a0),
	.nRD(nRD),
	.nWR(nWR),
	.din(din),
	.dout(dout),

	.img_mounted(img_mounted),
	.img_wp(img_wp),
	.img_size(img_size),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr)
);

endmodule
