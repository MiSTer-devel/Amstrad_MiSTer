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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Amstrad_MMU is
	Port (
		CLK        : in  STD_LOGIC;
		reset      : in  STD_LOGIC;
		
		ram64k     : in  STD_LOGIC;

		wr_z80     : in  STD_LOGIC;
		wr_io_z80  : in  STD_LOGIC;

      D          : in  STD_LOGIC_VECTOR (7 downto 0);
		A          : in  STD_LOGIC_VECTOR (15 downto 0);
		ram_A      : out STD_LOGIC_VECTOR (22 downto 0)
	);
end Amstrad_MMU;


architecture Behavioral of Amstrad_MMU is

-- "0000000" "xx" ROMBase L U0 U7 U1
-- "0000001" "xx" ROMBase 4 5 6 7
-- "0000010" "xx" RAMBase
-- "0000011" "xx" RAMBank page 0
-- "0000111" "xx" RAMBank page 1
-- "0001111" "xx" RAMBank page 3
-- "001"          dsk_A(19:0) DSK_A (unused)
-- "0101111" "xx" RAMBank page 7
-- "100000000"    ROMBank 0-255

-- cpcWiki
-- http://www.cpcwiki.eu/index.php/Gate_Array
-- -Address-     0      1      2      3      4      5      6      7
-- 0000-3FFF   RAM_0  RAM_0  RAM_4  RAM_0  RAM_0  RAM_0  RAM_0  RAM_0
-- 4000-7FFF   RAM_1  RAM_1  RAM_5  RAM_3  RAM_4  RAM_5  RAM_6  RAM_7
-- 8000-BFFF   RAM_2  RAM_2  RAM_6  RAM_2  RAM_2  RAM_2  RAM_2  RAM_2
-- C000-FFFF   RAM_3  RAM_7  RAM_7  RAM_7  RAM_3  RAM_3  RAM_3  RAM_3
--http://www.grimware.org/doku.php/documentations/devices/gatearray
--see also Quazar legends

	signal lowerROMen : STD_LOGIC;
	signal upperROMen : STD_LOGIC;
	signal RAMbank    : STD_LOGIC_VECTOR (2 downto 0);
	signal RAMbank512 : STD_LOGIC_VECTOR (2 downto 0);
	signal ROMbank    : STD_LOGIC_VECTOR (7 downto 0); -- upper ROM number
	signal old_wr_io  : STD_LOGIC;

begin

	--http://quasar.cpcscene.com/doku.php?id=iassem:interruptions
	process(reset,CLK) is
	begin
		if reset='1' then
			ROMbank<=(others=>'0');
			RAMbank<=(others=>'0');
			RAMbank512<=(others=>'0');
			lowerROMen<='1';
			upperROMen<='1';
			old_wr_io<='0';
		elsif rising_edge(CLK) then
			old_wr_io <= wr_io_z80;
			if old_wr_io='0' and wr_io_z80='1' then
				if A(15 downto 14) = "01" and D(7) ='1' then --7Fxx gate array --
					--http://www.cpctech.org.uk/docs/garray.html
					if D(6) = '0' then --RMR
						lowerROMen<=not(D(2));
						upperROMen<=not(D(3));
					--http://www.cpctech.org.uk/docs/mem.html
					elsif ram64k = '0' then    -- MMR
						-- cpcwiki doesn't care about : if D(4 downto 2)="001" or D(4 downto 2)="000" then
						RAMbank512<=D(5 downto 3);
						RAMbank<=D(2 downto 0);
					end if;
				end if;
				if A(13)='0' then
					ROMbank<=D(7 downto 0);
				end if;
			end if;
		end if;	
	end process;

	ram_A(13 downto 0) <=A(13 downto 0);

	ram_A(22 downto 14)<=
		-- please note here the wr signal... changing address in consequence.
		b"0000000" & b"00"  when wr_z80='0' and lowerROMen='1' and (A(15)='0' and A(14)='0') -- lowerROM
		else b"1" & ROMbank when wr_z80='0' and upperROMen='1' and (A(15)='1' and A(14)='1') -- upperROMFF

		-- 0 : OK
		else b"00000" & b"1000" when RAMbank="000" and (A(15)='0' and A(14)='0')
		else b"00000" & b"1001" when RAMbank="000" and (A(15)='0' and A(14)='1')
		else b"00000" & b"1010" when RAMbank="000" and (A(15)='1' and A(14)='0')
		else b"00000" & b"1011" when RAMbank="000" and (A(15)='1' and A(14)='1')

		-- 1 : OK
		else b"00000" & b"1000" when RAMbank="001" and (A(15)='0' and A(14)='0')
		else b"00000" & b"1001" when RAMbank="001" and (A(15)='0' and A(14)='1')
		else b"00000" & b"1010" when RAMbank="001" and (A(15)='1' and A(14)='0')
		else b"0" & RAMbank512(2) & "0" & RAMbank512(1 downto 0) & b"1111" when RAMbank="001" and (A(15)='1' and A(14)='1')

		-- 2 : OK
		else b"0" & RAMbank512(2) & "0" & RAMbank512(1 downto 0) & b"1100" when RAMbank="010" and (A(15)='0' and A(14)='0')
		else b"0" & RAMbank512(2) & "0" & RAMbank512(1 downto 0) & b"1101" when RAMbank="010" and (A(15)='0' and A(14)='1')
		else b"0" & RAMbank512(2) & "0" & RAMbank512(1 downto 0) & b"1110" when RAMbank="010" and (A(15)='1' and A(14)='0')
		else b"0" & RAMbank512(2) & "0" & RAMbank512(1 downto 0) & b"1111" when RAMbank="010" and (A(15)='1' and A(14)='1')

		-- 3 : OK
		else b"00000" & b"1000" when RAMbank="011" and (A(15)='0' and A(14)='0') --RAM_0 
		else b"00000" & b"1011" when RAMbank="011" and (A(15)='0' and A(14)='1') --RAM_3
		else b"00000" & b"1010" when RAMbank="011" and (A(15)='1' and A(14)='0') --RAM_2
		else b"0" & RAMbank512(2) & "0" & RAMbank512(1 downto 0) & b"1111" when RAMbank="011" and (A(15)='1' and A(14)='1')
		
		-- 4 5 6 7 : OK
		else b"00000" & b"1000" when RAMbank="100" and (A(15)='0' and A(14)='0')
		else b"0" & RAMbank512(2) & "0" & RAMbank512(1 downto 0) & b"1100" when RAMbank="100" and (A(15)='0' and A(14)='1')
		else b"00000" & b"1010" when RAMbank="100" and (A(15)='1' and A(14)='0')
		else b"00000" & b"1011" when RAMbank="100" and (A(15)='1' and A(14)='1')

		else b"00000" & b"1000" when RAMbank="101" and (A(15)='0' and A(14)='0')
		else b"0" & RAMbank512(2) & "0" & RAMbank512(1 downto 0) & b"1101" when RAMbank="101" and (A(15)='0' and A(14)='1')
		else b"00000" & b"1010" when RAMbank="101" and (A(15)='1' and A(14)='0')
		else b"00000" & b"1011" when RAMbank="101" and (A(15)='1' and A(14)='1')

		else b"00000" & b"1000" when RAMbank="110" and (A(15)='0' and A(14)='0')
		else b"0" & RAMbank512(2) & "0" & RAMbank512(1 downto 0) & b"1110" when RAMbank="110" and (A(15)='0' and A(14)='1')
		else b"00000" & b"1010" when RAMbank="110" and (A(15)='1' and A(14)='0')
		else b"00000" & b"1011" when RAMbank="110" and (A(15)='1' and A(14)='1')

		else b"00000" & b"1000" when RAMbank="111" and (A(15)='0' and A(14)='0')
		else b"0" & RAMbank512(2) & "0" & RAMbank512(1 downto 0) & b"1111" when RAMbank="111" and (A(15)='0' and A(14)='1')
		else b"00000" & b"1010" when RAMbank="111" and (A(15)='1' and A(14)='0')
		else b"00000" & b"1011" when RAMbank="111" and (A(15)='1' and A(14)='1')
		else (others=>'1');

end Behavioral;
