//    {@{@{@{@{@{@
//  {@{@{@{@{@{@{@{@  This code is covered by CoreAmstrad synthesis r004
//  {@    {@{@    {@  A core of Amstrad CPC 6128 running on MiST-board platform
//  {@{@{@{@{@{@{@{@
//  {@  {@{@{@{@  {@  CoreAmstrad is implementation of FPGAmstrad on MiST-board
//  {@{@        {@{@   Contact : renaudhelias@gmail.com
//  {@{@{@{@{@{@{@{@   @see http://code.google.com/p/mist-board/
//    {@{@{@{@{@{@     @see FPGAmstrad at CPCWiki
//
//
//------------------------------------------------------------------------------
// *.v : MiST-board controllers
// This type of component is only used on my main schematic.
// DELTA_ASYNC : using Amstrad, you can read/write into RAM and read from ROM, if you write in ROM in fact you write into RAM. Address solving here does come after WR/RD signal
// Donald Duck VALIDATED : strict calibration about latency
// Daisy
//------------------------------------------------------------------------------
//
// zsdram.v
//
// sdram controller implementation for the MiST board
// http://code.google.com/p/mist-board/
// 
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
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

module zsdram (

	// interface to the MT48LC16M16 chip
	inout [15:0]  		sd_data,    // 16 bit bidirectional data bus
	output [12:0]		sd_addr,    // 13 bit multiplexed address bus
	output [1:0] 		sd_dqm,     // two byte masks
	output [1:0] 		sd_ba,      // two banks
	output 				sd_cs,      // a single chip select
	output 				sd_we,      // write enable
	output 				sd_ras,     // row address select
	output 				sd_cas,     // columns address select

	// cpu/chipset interface
	input 		 		init,			// init signal after FPGA config to initialize RAM
	input 		 		clk,			// sdram is accessed at up to 128MHz
	input					clkref,		// reference clock to sync to
	
	input [7:0]  		din,			// data input from chipset/cpu
	output reg [7:0]  dout,			// data output to chipset/cpu
	input [24:0]   	addr,       // 25 bit byte address
	input 		 		oe,         // cpu/chipset requests read
	input 		 		we,         // cpu/chipset requests write

	output reg [7:0]  zram_dout,	// data output to graphic
	input [15:0]   	zram_addr,  // 16 bit byte address
	input 		 		zram_oe     // graphic requests write (and DISP)

);

// falling edge on oe/we/rfsh starts state machine

// no burst configured
localparam RASCAS_DELAY   = 3'd3;   // tRCD=20ns -> 3 cycles@128MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
// Daisy VALIDATED
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 


// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

localparam STATE_IDLE      = 3'd0;   // first state in cycle
localparam STATE_CMD_START = 3'd1;   // state in which a new command can be started
localparam STATE_CMD_CONT  = STATE_CMD_START  + RASCAS_DELAY; // 4 command can be continued
localparam STATE_LAST      = 3'd7;   // last state in cycle

localparam DELTA_ASYNC = 2'd2;
localparam DELTA_SYNC = 2'd1;
reg rd_i=1'b0; // oe at 114MHz
reg zram_rd_i=1'b0; // oe at 114MHz
reg wr_i=1'b0; // wr at 114MHz
reg clkref_i=1'b0; // clkref at 114MHz
reg init_i=1'b0; // init at 114MHz
always @(posedge clk) begin
	rd_i<=oe;
	wr_i<=we;
	zram_rd_i<=zram_oe;
	clkref_i<=clkref;
	init_i<=init;
end

reg [2:0] q /* synthesis noprune */;
reg [2:0] delay;
reg clkref_i_old=1'b0;
reg [1:0] operation_wait=0;
reg [1:0] zram_operation_wait=0;
reg operation_launch=1'b0;
reg zram_operation_launch=1'b0;
always @(posedge clk) begin
	// 112Mhz counter synchronous to <whatever> Mhz clock (here 4MHz)
   // does insert STATE_IDLE when needed
	// operation_wait=2 : do ignore next 2 operations before running one operation (only one)
	// operations not covered are simply running "REFRESH" operation
	if ((clkref_i_old==0) && (clkref_i==1))
		begin
			operation_wait<=DELTA_ASYNC;
			if (zram_rd_i)
				zram_operation_wait<=DELTA_SYNC;
		end
	else if (q == STATE_LAST) //(operation_wait!=0 && (q == STATE_LAST))
		begin
			if (operation_wait!=0)
				begin
					operation_wait<=operation_wait-2'd1;
					if (operation_wait==2'd1)
						operation_launch<=(wr_i || rd_i);
					//Daisy VALIDATED
					else operation_launch<=0;
				end
			else if (operation_launch)
				operation_launch<=0;
			if (zram_operation_wait!=0)
				begin
					zram_operation_wait<=zram_operation_wait-2'd1;
					if (zram_operation_wait==2'd1)
						zram_operation_launch<=zram_rd_i;
					//Daisy VALIDATED
					else zram_operation_launch<=0;
				end
			else if (zram_operation_launch)
				begin
					zram_operation_launch<=0;
				end
		end
	
	if ((clkref_i_old==0) && (clkref_i==1) && (q != STATE_IDLE))
		// some synchro by here
		//delay <= ((q+4'd7)%4'd8);
		begin
			delay <= q;
			q <= q + 3'd1;
		end
	else if ((q == STATE_IDLE) && (delay!=0))
		delay <= delay - 3'd1;
	else
		q <= q + 3'd1;
	clkref_i_old<=clkref_i;
end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [4:0] reset=5'h1f; // do reset also at boot time (please do not sleep !)
reg init_old=1'b0;
always @(posedge clk) begin
	if(init_old && !init_i)
		// do reset also at end of inits.
		reset <= 5'h1f;
	else if((q == STATE_LAST) && (reset != 0))
		reset <= reset - 5'd1;
	init_old <= init_i;
end

// ---------------------------------------------------------------------
// ------------------ generate ram control signals ---------------------
// ---------------------------------------------------------------------

// all possible commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

wire [3:0] sd_cmd;   // current command sent to sd ram

// drive control signals according to current command
assign sd_cs  = sd_cmd[3];
assign sd_ras = sd_cmd[2];
assign sd_cas = sd_cmd[1];
assign sd_we  = sd_cmd[0];

// drive ram data lines when writing, set them as inputs otherwise
// the eight bits are sent on both bytes ports. Which one's actually
// written depends on the state of dqm of which only one is active
// at a time when writing
assign sd_data = (wr_i && operation_launch) ?{din, din}:16'bZZZZZZZZZZZZZZZZ;

reg addr0;
always @(posedge clk) begin
	//Daisy
	//if((q == STATE_CMD_START) && rd_i && !wr_i && !zram_operation_launch) addr0 <= addr[0];
	//if((q == STATE_CMD_START) && zram_operation_launch) addr0 <= zram_addr[0];
	if(q == STATE_CMD_START && operation_launch) addr0 <= addr[0];
	else if(q == STATE_CMD_START && zram_operation_launch) addr0 <= zram_addr[0];
end

always @(posedge clk) begin
	//The CAS latency (CL) is the delay, in clock cycles, between the registration of a READ command and the availability of the output data. The latency can be set to two or three clocks.
	//Daisy VALIDATED
	if (rd_i && !wr_i && operation_launch & q == STATE_CMD_CONT+CAS_LATENCY+1)
		if (addr0)
			dout<=sd_data[7:0];
		else
			dout<=sd_data[15:8];
	else if (zram_rd_i && zram_operation_launch & q == STATE_CMD_CONT+CAS_LATENCY+1)
		if (addr0)
			zram_dout<=sd_data[7:0];
		else
			zram_dout<=sd_data[15:8];
end

wire [3:0] reset_cmd = 
	((q == STATE_CMD_START) && (reset == 13))?CMD_PRECHARGE:
	((q == STATE_CMD_START) && (reset ==  2))?CMD_LOAD_MODE:
	CMD_INHIBIT;

// CMD_WRITE : The DQM signal must be de-asserted prior to the WRITE command (DQM latency is zero clocks for input buffers)
wire [3:0] run_cmd =
	(operation_launch && (wr_i || rd_i) && (q == STATE_CMD_START))?CMD_ACTIVE:
	//Daisy
	//(zram_operation_launch && (q == STATE_CMD_START))?CMD_ACTIVE:
	(zram_operation_launch && zram_rd_i && (q == STATE_CMD_START))?CMD_ACTIVE:
	(operation_launch &&  wr_i && 			 (q == STATE_CMD_CONT ))?CMD_WRITE:
	(operation_launch && !wr_i &&  rd_i && (q == STATE_CMD_CONT ))?CMD_READ:
	//Daisy
	//(zram_operation_launch && (q == STATE_CMD_CONT ))?CMD_READ:
	(zram_operation_launch && zram_rd_i && (q == STATE_CMD_CONT ))?CMD_READ:
	(!(operation_launch || zram_operation_launch) && (q == STATE_CMD_START))?CMD_AUTO_REFRESH:
	CMD_INHIBIT;
	
assign sd_cmd = (reset != 0)?reset_cmd:run_cmd;

//When all banks are to be precharged (A10 = HIGH), inputs BA0 and BA1 are treated as "Don't Care."
wire [12:0] reset_addr = (reset == 13)?13'b0010000000000:MODE;
//    START            CONT             LAST
//      1      2   3    1+3=4   5   6    4+3=7
// CMD_ACTIVE NOP NOP CMD_READ NOP NOP NOP     NOP
//   addressH         addressL
//                    DATA_WR          DATA_RD DATA_RD

//vram_A_isValid<= init_done and not(A(22)) and not(A(21)) and not(A(20)) and not(A(19)) and not(A(18)) and A(17) and not(A(16));
//0000010
wire [12:0] run_addr = 
	//Daisy
	//(q == STATE_CMD_START && !zram_operation_launch)?addr[21:9]:
	//(q == STATE_CMD_START && zram_operation_launch)?{6'b000010, zram_addr[15:9]}:
	//(!zram_operation_launch)?{ 4'b0010, addr[24], addr[8:1]}:{ 5'b00100, zram_addr[8:1]};
	(q == STATE_CMD_START && operation_launch)?addr[21:9]:
	(q == STATE_CMD_START && zram_operation_launch)?{6'b000010, zram_addr[15:9]}:
	(q == STATE_CMD_CONT && operation_launch)?{ 4'b0010, addr[24], addr[8:1]}:
	(q == STATE_CMD_CONT && zram_operation_launch)?{ 5'b00100, zram_addr[8:1]}:
	13'b0000000000000;

assign sd_addr = (reset != 0)?reset_addr:run_addr;

// bank address (CMD_ACTIVE)
//Daisy
//assign sd_ba = (!zram_operation_launch)?addr[23:22]:2'b00;
assign sd_ba = ((q == STATE_CMD_START || q == STATE_CMD_CONT) && operation_launch)?addr[23:22]:
((q == STATE_CMD_START || q == STATE_CMD_CONT) && zram_operation_launch)?2'b00:
2'b00;

//The output buffers are High-Z (two-clock latency) during a READ cycle.
//Input data is masked during a WRITE cycle
//LDQM corresponds to DQ[7:0], and UDQM corresponds to DQ[15:8]. LDQM and UDQM are considered same-state when referenced as DQM.
assign sd_dqm = (wr_i && operation_launch)?{ addr[0], ~addr[0] }:2'b00;

endmodule
