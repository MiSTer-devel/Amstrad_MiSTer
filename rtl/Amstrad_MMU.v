/*

	Reworked Amstrad MMU for simplicity
	(C) 2018 Sorgelig

--------------------------------------------------------------------------------
--    {@{@{@{@{@{@
--  {@{@{@{@{@{@{@{@  This code is covered by CoreAmstrad synthesis r004
--  {@    {@{@    {@  A core of Amstrad CPC 6128 running on MiST-board platform
--  {@{@{@{@{@{@{@{@
--  {@  {@{@{@{@  {@  CoreAmstrad is implementation of FPGAmstrad on MiST-board
--  {@{@        {@{@   Contact : renaudhelias@gmail.com
--  {@{@{@{@{@{@{@{@   @see http://code.google.com/p/mist-board/
--    {@{@{@{@{@{@     @see FPGAmstrad at CPCWiki
--
--
--------------------------------------------------------------------------------
-- FPGAmstrad_amstrad_motherboard.Amstrad_MMU
-- RAM ROM mapping split
--------------------------------------------------------------------------------
*/

//http://www.grimware.org/doku.php/documentations/devices/gatearray

module Amstrad_MMU
(
	input        CLK,
	input        reset,

	input        ram64k,

	input        mem_WR,
	input        io_WR,

	input  [7:0] D,
	input [15:0] A,
	output reg [22:0] ram_A
);

reg lowerROMen;
reg upperROMen;
reg [2:0] RAMmap;
reg [4:0] RAMpage;
reg       RAMpageEx;
reg [7:0] ROMbank;

always @(posedge CLK) begin
	reg old_wr = 0;

	if (reset) begin
		ROMbank    <=0;
		RAMmap     <=0;
		RAMpage    <=3;
		lowerROMen <=1;
		upperROMen <=1;
	end
	else begin
		old_wr <= io_WR;
		if (~old_wr & io_WR) begin
			if (A[15:14] == 'b01 && D[7:6] == 'b10) begin //7Fxx gate array RMR
				lowerROMen <= ~D[2];
				upperROMen <= ~D[3];
			end
			
			if (~A[15] && D[7:6] == 'b11 && ~ram64k) begin //7Fxx PAL MMR
				RAMpage <= {1'b0, ~A[8], D[5:3]} + 5'd3;
				RAMmap  <= D[2:0];
			end

			if (~A[13]) ROMbank <= D;
		end
	end
end

always @(*) begin
	casex({lowerROMen&~mem_WR&(!A[15:14]), upperROMen&~mem_WR&(&A[15:14]), RAMmap, A[15:14]})
		'b1x_xxx_xx: ram_A[22:14] = 0;                             // lower rom
		'b01_xxx_xx: ram_A[22:14] = {1'b1, ROMbank};               // upper rom
		'b00_0x1_11,                                               // map1&3 bank3
		'b00_010_xx: ram_A[22:14] = {2'b00, RAMpage,    A[15:14]}; // map2   bank0-3 (ext  0..3)
		'b00_011_01: ram_A[22:14] = {2'b00,    5'd2,       2'b11}; // map3   bank1   (base 3)
		'b00_1xx_01: ram_A[22:14] = {2'b00, RAMpage, RAMmap[1:0]}; // map4-7 bank1   (ext  0..3)
		    default: ram_A[22:14] = {2'b00,    5'd2,    A[15:14]}; // base 64KB map  (base 0..3)
	endcase

	ram_A[13:0] = A[13:0];
end

endmodule
