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
-- FPGAmstrad_amstrad_motherboard.Keyboard
-- see KEYBOARD_controller.vhd
-- see KEYBOARD_driver.vhd
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity Keyboard is
	port (
		datain, clkin : in std_logic; -- PS2 clk and data
		fclk, fce, rst : in std_logic;  -- filter clock
		fok : out std_logic;  -- data output enable signal
		scancode : out std_logic_vector(7 downto 0) -- scan code signal output
	);
end Keyboard;

architecture rtl of Keyboard is
type state_type is (delay, start, d0, d1, d2, d3, d4, d5, d6, d7, parity, stop, badstop, finish);
signal data, clk, clk1, clk2, odd: std_logic;
signal code : std_logic_vector(7 downto 0); 
signal state : state_type;
begin

	clk <= (not clk1) and clk2;
	odd <= code(0) xor code(1) xor code(2) xor code(3) xor code(4) xor code(5) xor code(6) xor code(7);
	
	process(rst, fclk)
	begin
		if rst = '1' then
			state <= delay;
			code <= (others => '0');
			fok <= '0';
		elsif rising_edge(fclk) then
			if fce='1' then

				clk1 <= clkin;
				clk2 <= clk1;
				data <= datain;

				fok <= '0';
				case state is 
					when delay =>
						state <= start;
					when start =>
						if clk = '1' then
							if data = '0' then
								state <= d0;
							else
								state <= start; --delay;
							end if;
						end if;
					when d0 =>
						if clk = '1' then
							code(0) <= data;
							state <= d1;
						end if;
					when d1 =>
						if clk = '1' then
							code(1) <= data;
							state <= d2;
						end if;
					when d2 =>
						if clk = '1' then
							code(2) <= data;
							state <= d3;
						end if;
					when d3 =>
						if clk = '1' then
							code(3) <= data;
							state <= d4;
						end if;
					when d4 =>
						if clk = '1' then
							code(4) <= data;
							state <= d5;
						end if;
					when d5 =>
						if clk = '1' then
							code(5) <= data;
							state <= d6;
						end if;
					when d6 =>
						if clk = '1' then
							code(6) <= data;
							state <= d7;
						end if;
					when d7 =>
						if clk = '1' then
							code(7) <= data;
							state <= parity;
						end if;
					WHEN parity =>
						IF clk = '1' then
							if (data xor odd) = '1' then
								state <= stop;
							elsif data='1' then -- FF realign instruction
								fok <= '0';
								state <= start;
							else
								state <= badstop;
							end if;
						END IF;
					when badstop =>
						IF clk = '1' then
							if data = '1' then
								--state <= finish;
								fok <= '0';
								state <= start;
							else
								state <= badstop;--delay;
							end if;
						END IF;
					WHEN stop =>
						IF clk = '1' then
							if data = '1' then
								--state <= finish;
								fok <= '1';
								scancode <= code;
								state <= start;
							else
								state <= stop;--delay;
							end if;
						END IF;

					WHEN finish =>
						state <= delay;
						fok <= '1';
						scancode <= code;
					when others =>
						state <= delay;
				end case; 
			end if;
		end if;
	end process;
end rtl;
