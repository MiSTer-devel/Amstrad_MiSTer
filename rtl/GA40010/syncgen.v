// ====================================================================
//
//  Amstrad CPC Gate Array
//  Based on 40010-simplified_V03.pdf by Gerald
//
//  Copyright (C) 2020 Gyorgy Szombathelyi <gyurco@freemail.hu>
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

// Original sync+int generator from reverse engineered schematics
module syncgen (
	input  CCLK,
	input  RESET_N,
	input  MREQ_N,
	input  M1_N,
	input  RD_N,
	input  IORQ_N,
	input  HSYNC_I,
	input  VSYNC_I,
	input  irq_reset,

	output HSYNC_O,
	output VSYNC_O,
	output SYNC_N,
	output reg INT_N,
	output HCNTLT28
);

/* verilator lint_off MULTIDRIVEN */
/* verilator lint_off UNOPTFLAT */
reg [5:0] intcnt;
reg [4:0] hcnt;
reg [3:0] hdelay;

/* verilator lint_on MULTIDRIVEN */
/* verilator lint_on UNOPTFLAT */

reg       vsync_d; // u803
wire      hsync_n = ~HSYNC_I; // u801
reg       vsync_o_d; // u812
/* verilator lint_off UNOPTFLAT */
wire      irqack_rst;
/* verilator lint_on UNOPTFLAT */

always @(negedge CCLK) begin
	vsync_d <= VSYNC_I;
	vsync_o_d <= VSYNC_O;
end

assign VSYNC_O = hcnt[2] & ~hcnt[3] & ~hcnt[4]; // u806

/* verilator lint_off UNOPTFLAT */
wire intcntclr_52 = hsync_n & ((intcnt[2] & intcnt[4] & intcnt[5]) | intcntclr_52); // u816
/* verilator lint_on UNOPTFLAT */
wire intcntclr_4  = VSYNC_O & ~vsync_o_d; // u817
wire intcnt_res0 = intcntclr_52 | intcntclr_4 | irq_reset; // u831
wire intcnt_res1 = intcnt_res0 | irqack_rst; // u833

always @(posedge hsync_n, posedge intcnt_res0) if (intcnt_res0) intcnt[0] <= 0; else intcnt[0] <= ~intcnt[0];
always @(negedge intcnt[0], posedge intcnt_res0) if (intcnt_res0) intcnt[1] <= 0; else intcnt[1] <= ~intcnt[1];
always @(negedge intcnt[1], posedge intcnt_res0) if (intcnt_res0) intcnt[2] <= 0; else intcnt[2] <= ~intcnt[2];
always @(negedge intcnt[2], posedge intcnt_res0) if (intcnt_res0) intcnt[3] <= 0; else intcnt[3] <= ~intcnt[3];
always @(negedge intcnt[3], posedge intcnt_res0) if (intcnt_res0) intcnt[4] <= 0; else intcnt[4] <= ~intcnt[4];
always @(negedge intcnt[4], posedge intcnt_res1) if (intcnt_res1) intcnt[5] <= 0; else intcnt[5] <= ~intcnt[5];

assign HCNTLT28 = ~(hcnt[2] & hcnt[3] & hcnt[4]); // u802
wire hcnt_res0 = ~RESET_N | ~HCNTLT28; // u805
always @(posedge hsync_n, posedge hcnt_res0) if (hcnt_res0) hcnt[0] <= 0; else hcnt[0] <= ~hcnt[0];
wire hcnt_res1 = VSYNC_I & ~vsync_d; // u810
always @(negedge hcnt[0], posedge hcnt_res1) if (hcnt_res1) hcnt[1] <= 0; else hcnt[1] <= ~hcnt[1];
always @(posedge hcnt[1], posedge hcnt_res1) if (hcnt_res1) hcnt[2] <= 0; else hcnt[2] <= ~hcnt[2];
always @(negedge hcnt[2], posedge hcnt_res1) if (hcnt_res1) hcnt[3] <= 0; else hcnt[3] <= ~hcnt[3];
always @(negedge hcnt[3], posedge hcnt_res1) if (hcnt_res1) hcnt[4] <= 0; else hcnt[4] <= ~hcnt[4];

wire hdelay_res0 = hsync_n | hdelay[3]; // u804
wire hdelay_res1 = hsync_n; // u822

always @(negedge CCLK, posedge hdelay_res0) if (hdelay_res0) hdelay[0] <= 0; else hdelay[0] <= ~hdelay[0];
always @(negedge hdelay[0], posedge hdelay_res0) if (hdelay_res0) hdelay[1] <= 0; else hdelay[1] <= ~hdelay[1];
always @(posedge hdelay[1], posedge hdelay_res0) if (hdelay_res0) hdelay[2] <= 0; else hdelay[2] <= ~hdelay[2];
always @(negedge hdelay[2], posedge hdelay_res1) if (hdelay_res1) hdelay[3] <= 0; else hdelay[3] <= ~hdelay[3];

assign HSYNC_O = hdelay[2];

assign SYNC_N = ~(VSYNC_O ^ HSYNC_O);

wire mode_sync = ~hdelay[2];

wire int_reset = irq_reset | irqack_rst;

always @(negedge intcnt[5], posedge int_reset)  begin
    if (int_reset) INT_N <= 1; else INT_N <= 0;
end

assign irqack_rst = ~M1_N & (irqack_rst | ~(INT_N | IORQ_N | M1_N));

endmodule
