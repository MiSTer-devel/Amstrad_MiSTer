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
	inout  [15:0] 		SDRAM_DQ,   // 16 bit bidirectional data bus
	output [12:0]		SDRAM_A,    // 13 bit multiplexed address bus
	output      		SDRAM_DQML, // byte mask
	output      		SDRAM_DQMH, // byte mask
	output [1:0] 		SDRAM_BA,   // two banks
	output 				SDRAM_nCS,  // a single chip select
	output 				SDRAM_nWE,  // write enable
	output 				SDRAM_nRAS, // row address select
	output 				SDRAM_nCAS, // columns address select
	output 				SDRAM_CKE,

	// cpu/chipset interface
	input 		 		init,			// init signal after FPGA config to initialize RAM
	input 		 		clk,			// sdram is accessed at up to 128MHz
	input					clkref,		// reference clock to sync to
	
	input [1:0]  		bank,
	input [7:0]  		din,			// data input from chipset/cpu
	output reg [7:0]  dout,			// data output to chipset/cpu
	input [22:0]   	addr,       // 25 bit byte address
	input 		 		oe,         // cpu/chipset requests read
	input 		 		we,         // cpu/chipset requests write

	output  [7:0]     zram_dout,	// data output to graphic
	input  [15:0]   	zram_addr   // 16 bit byte address
);

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

reg [2:0] q;
reg wr;
reg ram_req=0;
reg zram_req=0;

always @(posedge clk) begin
	reg [15:0] old_addr;
	reg old_rd, old_we, old_ref;

	old_rd<=oe;
	old_we<=we;
	old_ref<=clkref;

	if(q==STATE_IDLE) begin
		ram_req <= 0;
		zram_req <= 0;

		if((~old_rd & oe) | (~old_we & we)) begin
			ram_req <= 1;
			wr <= we;
		end
		else begin
			old_addr <= zram_addr;
			if(old_addr[15:1] != zram_addr[15:1]) zram_req <= 1;
		end
	end

	q <= q + 3'd1;
	if(~old_ref & clkref) q <= 0;
end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [4:0] reset=5'h1f; // do reset also at boot time (please do not sleep !)
always @(posedge clk) begin
	reg init_old=1'b0;
	init_old <= init;

	if(init_old & ~init) reset <= 5'h1f;
	else if((q == STATE_LAST) && (reset != 0)) reset <= reset - 5'd1;
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
assign SDRAM_nCS  = sd_cmd[3];
assign SDRAM_nRAS = sd_cmd[2];
assign SDRAM_nCAS = sd_cmd[1];
assign SDRAM_nWE  = sd_cmd[0];
assign SDRAM_CKE  = ~init;

// drive ram data lines when writing, set them as inputs otherwise
// the eight bits are sent on both bytes ports. Which one's actually
// written depends on the state of dqm of which only one is active
// at a time when writing
assign SDRAM_DQ = (wr && ram_req) ? {din, din}:16'bZZZZZZZZZZZZZZZZ;

//The output buffers are High-Z (two-clock latency) during a READ cycle.
//Input data is masked during a WRITE cycle
//LDQM corresponds to DQ[7:0], and UDQM corresponds to DQ[15:8]. LDQM and UDQM are considered same-state when referenced as DQM.
assign {SDRAM_DQMH,SDRAM_DQML} = (wr && ram_req) ? { ~addr[0], addr[0] }:2'b00;

reg addr0;
always @(posedge clk) begin
	//Daisy
	if(q == STATE_CMD_START && ram_req) addr0 <= addr[0];
end

assign zram_dout = zram_addr[0] ? zram_data[15:8] : zram_data[7:0];

reg [15:0] zram_data;
always @(posedge clk) begin
	//The CAS latency (CL) is the delay, in clock cycles, between the registration of a READ command and the availability of the output data. The latency can be set to two or three clocks.
	//Daisy VALIDATED
	if (!wr && ram_req & q == STATE_CMD_CONT+CAS_LATENCY+1) begin
		if (addr0) dout<=SDRAM_DQ[15:8];
		else dout<=SDRAM_DQ[7:0];
	end
	else if (zram_req & q == STATE_CMD_CONT+CAS_LATENCY+1) zram_data<=SDRAM_DQ;
end

wire [3:0] reset_cmd = 
	((q == STATE_CMD_START) && (reset == 13))?CMD_PRECHARGE:
	((q == STATE_CMD_START) && (reset ==  2))?CMD_LOAD_MODE:
	CMD_INHIBIT;

// CMD_WRITE : The DQM signal must be de-asserted prior to the WRITE command (DQM latency is zero clocks for input buffers)
wire [3:0] run_cmd =
	(ram_req        && (q == STATE_CMD_START))?CMD_ACTIVE:
	(zram_req       && (q == STATE_CMD_START))?CMD_ACTIVE:
	(ram_req &&  wr && (q == STATE_CMD_CONT ))?CMD_WRITE:
	(ram_req && !wr && (q == STATE_CMD_CONT ))?CMD_READ:
	(zram_req       && (q == STATE_CMD_CONT ))?CMD_READ:
	(!(ram_req || zram_req) && (q == STATE_CMD_START))?CMD_AUTO_REFRESH:
	CMD_INHIBIT;
	
assign sd_cmd = reset ? reset_cmd : run_cmd;

//When all banks are to be precharged (A10 = HIGH), inputs BA0 and BA1 are treated as "Don't Care."
wire [12:0] reset_addr = (reset == 13) ? 13'b0010000000000 : MODE;
//    START            CONT             LAST
//      1      2   3    1+3=4   5   6    4+3=7
// CMD_ACTIVE NOP NOP CMD_READ NOP NOP NOP     NOP
//   addressH         addressL
//                    DATA_WR          DATA_RD DATA_RD

//vram_A_isValid<= init_done and not(A(22)) and not(A(21)) and not(A(20)) and not(A(19)) and not(A(18)) and A(17) and not(A(16));
//0000010
wire [12:0] run_addr = 
	//Daisy
	(q == STATE_CMD_START && ram_req )? addr[21:9]                       :
	(q == STATE_CMD_START && zram_req)? {6'b000010, zram_addr[15:9]}     :
	(q == STATE_CMD_CONT  && ram_req )? {  4'b0010, addr[22], addr[8:1]} :
	(q == STATE_CMD_CONT  && zram_req)? { 5'b00100, zram_addr[8:1]}      :
	13'b0000000000000;

assign SDRAM_A = reset ? reset_addr : run_addr;
assign SDRAM_BA = bank;

endmodule
