--    {@{@{@{@{@{@
--  {@{@{@{@{@{@{@{@  This code is covered by CoreAmstrad synthesis r005
--  {@    {@{@    {@  A core of Amstrad CPC 6128 running on MiST-board platform
--  {@{@{@{@{@{@{@{@
--  {@  {@{@{@{@  {@  CoreAmstrad is implementation of FPGAmstrad on MiST-board
--  {@{@        {@{@   Contact : renaudhelias@gmail.com
--  {@{@{@{@{@{@{@{@   @see http://code.google.com/p/mist-board/
--    {@{@{@{@{@{@     @see FPGAmstrad at CPCWiki
--
--
--------------------------------------------------------------------------------
-- FPGAmstrad_amstrad_motherboard.Amstrad_ASIC
-- VRAM/PRAM write
-- CRTC interrupt, IO_ACK
-- WAIT_n
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- https://sourceforge.net/p/jemu/code/HEAD/tree/JEMU/src/jemu/system/cpc/GateArray.java

-- Being clear about address/data :
-- 12/13 : ADRESSE_maRegister update, upper to 9 isn't used
-- 0 1 2 3 do run setEvents => strange it seems about HORIZONTALS
-- 7 seem making effects if its value is 0 but it seems a source code erratum
-- 3 does call setReg3(value) which rules under hsyncWidth and vsyncWidth
-- 6 does call setReg6() with some border effect on a demo
-- 8 does call setReg8(value) interlace

-- ink 0,2,20
-- speed ink 1,1
entity Amstrad_ASIC is
	Generic (
		--HD6845S 	Hitachi 	0 HD6845S_WriteMaskTable type 0 in JavaCPC
		--UM6845 	UMC 		0
		--UM6845R 	UMC 		1 UM6845R_WriteMaskTable type 1 in JavaCPC <==
		--MC6845 	Motorola	2 
		--crtc_type:std_logic:='1'; -- '0' or '1' :p
		M1_OFFSET:integer :=3; -- from 0 to 3
		SOUND_OFFSET:integer :=1; -- from 0 to 3 =(M1_OFFSET+2)%4
		NB_LINEH_BY_VSYNC:integer:=24+1; --4--5-- VSYNC normally 4 HSYNC
		-- feel nice policy : interrupt at end of HSYNC
		--I have HDISP (external port of original Amstrad 6128) so I can determinate true timing and making a fix time generator
		-- 39*8=312   /40=7.8 /52=6 /32=9.75
		VRAM_HDsp:integer:=800/16; -- words of 16bits, that contains more or less pixels... thinking as reference mode 2, some 800x600 mode 2 (mode 2 is one bit <=> one pixel, that's cool)
		VRAM_VDsp:integer:=600/2;
		-- plus je grandi cette valeur plus l'image va vers la gauche.
		VRAM_Hoffset:integer:=12; -- 63*16-46*16

		-- le raster palette arrive au moment oÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹ l'encre est en face du stylo.
		-- si on a un dÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©calage raster palette alors on lis au mauvais moment, donc au mauvais endroit
		-- hors nous on lit via MA, et on ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©crit n'importe oÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹ via VRAM_Voffset
		-- donc VRAM_Voffset n'a pas d'influence sur le raster palette
		-- ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§a veut dire que l'adresse mÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©moire dessous la palette n'est pas bonne


		-- plus je grandi cette valeur plus l'image va vers le haut.
		VRAM_Voffset:integer:=14; --15; --16; --18;  -- no influence under layer PRAM (raster palette colours ink), because PRAM is time dependant. Here influence is just about image position on screen
		-- output pixels
		-- Amstrad
		-- 
		--OFFSET:STD_LOGIC_VECTOR(15 downto 0):=x"C000";
		-- screen.bas
		-- CLS
		-- FOR A=&C000 TO &FFFF
		-- POKE A,&FF
		-- NEXT A
		-- 
		-- line.bas
		-- CLS
		-- FOR A=&C000 TO &C050
		-- POKE A,&FF
		-- NEXT A
		-- 
		-- lines.bas
		-- CLS
		-- FOR A=&C000 TO &C7FF
		-- POKE A,&FF
		-- NEXT A
		-- 
		-- byte pixels structure :
		-- mode 1 :
		--   1 byte <=> 4 pixels
		--   [AAAA][BBBB] : layering colors [AAAA] and [BBBB]
		--   A+B=0+0=dark blue (default Amstrad background color)
		--   A+B=0+1=light blue
		--   A+B=1+0=yellow
		--   A+B=1+1=red
		--  for example [1100][0011] with give 2 yellow pixels followed by 2 light blue pixels &C3
		-- mode 0 : 
		--   1 byte <=> 2 pixels
		--   [AA][BB][CC][DD] : layering colors of AA, BB, CC, DD
		--   Because it results too many equations for a simple RGB output, they do switch the last equation (alternating at a certain low frequency (INK SPEED))
		-- mode 2 :
		--   1 byte <=> 8 pixels
		--   [AAAAAAAA] : so only 2 colors xD
		MODE_MAX:integer:=2;
		--	 NB_PIXEL_PER_OCTET:integer:=4;--2**(MODE+1);
		NB_PIXEL_PER_OCTET_MAX:integer:=8;
		NB_PIXEL_PER_OCTET_MIN:integer:=2
	);
	Port (
		nCLK4_1 : in  STD_LOGIC;
		CLK16MHz : in STD_LOGIC;
		VMODE:out STD_LOGIC_VECTOR (1 downto 0);
		R2D2 : in  STD_LOGIC_VECTOR (7 downto 0);
		Dout : out  STD_LOGIC_VECTOR (7 downto 0):= (others=>'1');
		crtc_VSYNC : out STD_LOGIC:='0';
		crtc_A : out STD_LOGIC_VECTOR (15 downto 0):=(others=>'0');
		bvram_A: out STD_LOGIC_VECTOR (14 downto 0):=(others=>'0');
		bvram_W: out STD_LOGIC:='0'; 
		bvram_D: out std_logic_vector(7 downto 0):=(others=>'0'); -- pixel_DATA
		crtc_R : out STD_LOGIC:='0'; --ram_A external solve CRTC read scan
		int    : out STD_LOGIC:='0'; -- JavaCPC reset init

		A15_A14_A9_A8 : in  STD_LOGIC_VECTOR (3 downto 0);
		D      : in  STD_LOGIC_VECTOR (7 downto 0);
		M1_n   : in  STD_LOGIC;
		IORQ_n : in  STD_LOGIC;
		MREQ_n : in  STD_LOGIC;
		RD_n   : in  STD_LOGIC;
		WR_n   : in  STD_LOGIC;

		-- Z80 4MHz and CRTC 1MHz are produced by GATE_ARRAY normally
		-- MA0/CCLK is produced by GATE_ARRAY and does feed Yamaha sound chip.
		-- WAIT<=WAIT_MEM_n and WAIT_n; -- MEM_WR and M1
		-- please_wait(4MHz,WAIT)=>4MHz is a clock hack as Z80 does not implement correclty the WAIT purpose (Z80 is encapsulating a Z8080 and so corrupt this purpose)
		WAIT_n : out  STD_LOGIC:='1';
		-- YM2149 is using rising_edge(CLK)
		SOUND_CLK : out  STD_LOGIC; -- calibrated with Sim City/Abracadabra et les voleurs du temps/CPCRulez -CIRCLES demo
		--decalibrated (dsk DELETED TRACK purpose does break it completly)
		crtc_D : in  STD_LOGIC_VECTOR (7 downto 0);
		palette_A: out STD_LOGIC_VECTOR (13 downto 0):=(others=>'0');
		palette_D: out std_logic_vector(7 downto 0);
		palette_W: out std_logic;
		reset:in  STD_LOGIC;

		crtc_type: in std_logic;
		ga_shunt: in std_logic;

		RED    : out  STD_LOGIC_VECTOR(1 downto 0);
		GREEN  : out  STD_LOGIC_VECTOR(1 downto 0);
		BLUE   : out  STD_LOGIC_VECTOR(1 downto 0);
		HBLANK : out STD_logic;
		VBLANK : out STD_logic;
		HSYNC  : out STD_logic;
		VSYNC  : out STD_logic
	);
end Amstrad_ASIC;

architecture Behavioral of Amstrad_ASIC is

	signal IO_REQ_W : std_logic;
	signal IO_REQ_R : std_logic;
	signal IO_ACK   : std_logic;
	signal MEM_RD   : std_logic;

	-- init values are for test bench javacpc ! + Grimware
	signal RHtot:std_logic_vector(7 downto 0):="00111111";
	signal RHdisp:std_logic_vector(7 downto 0):="00101000";
	signal RHsyncpos:std_logic_vector(7 downto 0):="00101110";
	signal RHwidth:std_logic_vector(3 downto 0):="1110";
	signal RVwidth:std_logic_vector(3 downto 0):="1000";
	signal RVtot:std_logic_vector(7 downto 0):="00100110";
	signal RVtotAdjust:std_logic_vector(7 downto 0):="00000000";
	signal RVdisp:std_logic_vector(7 downto 0):="00011001";
	signal RVsyncpos:std_logic_vector(7 downto 0):="00011110";
	signal RRmax:std_logic_vector(7 downto 0):="00000111";
	
	signal Skew:std_logic_vector(1 downto 0):="00";
	signal interlaceVideo:std_logic:='0';
	signal interlace:std_logic:='0';
	signal scanAdd:std_logic_vector(7 downto 0):=x"01";
	signal halfR0:std_logic_vector(7 downto 0):="00100000"; --(RHTot+1)/2

	-- check RVtot*RRmax=38*7=266>200 => 39*8=312 ! 38*8=304 304/52=5.84 ! 38*7=266=5.11
	--       ? RVsyncpos*RRmax=30*7=210, 266-210=56 (NB_HSYNC_BY_INTERRUPT=52) 30*8=240 312-240=72
	-- NB_HSYNC_BY_INTERRUPT*6=52*6=312
	
-- Grimware A PAL 50Hz video-frame on the Amstrad is 312 rasterlines. 
-- Grimware screenshoot :
--R0 RHtot     =63 : 0..63                            (donc 64 pas)
--R1 RHdisp    =40 : 0..39 si HCC=R1 alors DISPEN=OFF (donc 40 pas laissÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© passÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©)
--R2 RHsyncpos =46 : si HCC=R2 alors HSYNC=ON         (donc 46 pas laissÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© passÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©)
--R3 RHwidth   =14 : si (HCC-R2=)R3 alors HSYNC=OFF   (donc 60 pas laissÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© passÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©)
--R4 RVtot     =38 : 0..38                            (donc 39 pas)
--R6 RVdisp    =25 : 0..24 si VCC=R6 alors DISPEN=OFF (donc 25 pas laissÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© passÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©)
--R7 RVsyncpos =30 : si VCC=R7 alors VSYNC=ON         (donc 30 pas laissÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© passÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©)
--R3 RVwidth   =8  : VSYNC=OFF aprÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s un certain temps...
--R9 RRmax     =7  : 0..7                             (donc  8 pas)
--caractÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¨res de 8*8, donc verticalement : 1024 et horizontalement : 312.

--minus one : R0, R4, R9

	-- arnold cpctest.asm :
	-- crtc_default_values:
	-- defb 63,40,46,&8e,38,0,25,30,0,7,0,0,&30,0,0,0,0
	
	--CRTC register 1 defines the width of the visible area in CRTC characters.
	--The CPC display hardware fetches two bytes per CRTC character.
	--Therefore the length of a CRTC scanline in bytes is (R1*2). (here : 40*2*8=640 pixels)
	
	--CRTC register 6 defines the height of the visible area in CRTC character lines.
	--Therefore the total height of the visible area in CRTC scanlines is (R9+1)*R6 (here :(7+1)*25=200 pixels)
	-- (RRmax+1)*RVdisp
	
	constant DO_NOTHING : STD_LOGIC:='0';
	constant DO_HSYNC : STD_LOGIC:='1';
	constant DO_VSYNC : STD_LOGIC:='1';
	
	signal ADRESSE_maRegister:STD_LOGIC_VECTOR(13 downto 0):="110000" & "00000000";--(others=>'0');
	signal LineCounter_is0:boolean:=true;
	signal vsync_int:std_logic;
	signal hsync_int:std_logic;
	signal vsync_azrael:std_logic;
	signal hsync_azrael:std_logic;
	
	--signal CLK4MHz : STD_LOGIC;
	--signal SOUND_CLK_i : STD_LOGIC;
	--signal crtc_DISP : STD_LOGIC;--alternate 2MHz phase scaled   ===//
	
	type palette_type is array(31 downto 0) of std_logic_vector(5 downto 0); -- RRVVBB
	constant palette:palette_type:=(
		20=>"000000",
		 4=>"000001",
		21=>"000011",
		28=>"010000",
		24=>"010001",
			29=>"010011",
		12=>"110000",
			5=>"110001",
		13=>"110011",
		22=>"000100",
		6=>"000101",
		23=>"000111",
		30=>"010100",
		 0=>"010101",
		31=>"010111",
		14=>"110100",
		 7=>"110101",
		15=>"110111",
		18=>"001100",
		 2=>"001101",
		19=>"001111",
		26=>"011100",
		25=>"011101",
		27=>"011111",
		10=>"111100",
		 3=>"111101",
		11=>"111111",
		
		-- others color >=27
		1=>"010101",
		8=>"110001",
		9=>"111101",
		16=>"000001",
		17=>"001101"
		);
	
	
	type pen_type is array(15 downto 0) of integer range 0 to 31;
	signal pen:pen_type:=(4,12,21,28,24,29,12,5,13,22,6,23,30,0,31,14);
	signal border:integer range 0 to 31;
	
	signal MODE_select: STD_LOGIC_VECTOR (1 downto 0);
	signal newMode:STD_LOGIC_VECTOR (1 downto 0);
	
	-- action aZRaEL : disp !
	constant DO_NOTHING_OUT : integer range 0 to 2:=0;
	constant DO_READ : integer range 0 to 2:=1;
	constant DO_BORDER: integer range 0 to 2:=2;
	signal etat_rgb : integer range 0 to 2:=DO_NOTHING_OUT;
	signal DATA_action : std_logic:='0'; -- if rising_edge then DATA just is filled.
	signal DATA : std_logic_vector(7 downto 0):=(others=>'0');
	
	--type LATENCE_ARRAY is array (255 downto 0) of std_logic;
	type LATENCE_ARRAY is array (255 downto 0) of integer range 0 to 2;

	-- generated by LatencesCPC.java
constant latences:LATENCE_ARRAY :=(
    16 => 1, -- "10"
    34 => 1, -- "22"
    42 => 1, -- "2a"
		50 => 1, --"32" --human calibrate
		58 => 1, --"3a" --human calibrate
    192 => 1, -- "c0" -- ?
		196 => 1, -- "c4" --human calibrate
    197 => 1, -- "c5" -- ?
    199 => 1, -- "c7" -- ?
    200 => 1, -- "c8" -- ?
		204 => 1, -- "cc" --human calibrate
		205 => 1, -- "cd" --human calibrate
    207 => 1, -- "cf" -- ?
    208 => 1, -- "d0" -- ?
		212 => 1, -- "d4" --human calibrate
    213 => 1, -- "d5" -- ?
    215 => 1, -- "d7" -- ?
    216 => 1, -- "d8" -- ?
		220 => 1, -- "dc" --human calibrate
    223 => 1, -- "df" -- ?
    224 => 1, -- "e0" -- ?
    227 => 1, -- "e3" -- ?
		228 => 1, -- "e4" --human calibrate
    229 => 1, -- "e5" -- ?
    231 => 1, -- "e7" -- ?
    232 => 1, -- "e8" -- ?
    239 => 1, -- "ef" -- ?
    240 => 1, -- "f0" -- ?
		244 => 1, -- "f4" --human calibrate
    245 => 1, -- "f5" -- ?
    247 => 1, -- "f7" -- ?
    248 => 1, -- "f8" -- ?
		252 => 1, -- "fc" --human calibrate
    255 => 1, -- "ff" -- ?
    -- "cb" NOT TESTED
    -- "dd" NOT TESTED
    -- "ed" NOT TESTED
    -- "fd" NOT TESTED
others=>0);
constant latences_CB:LATENCE_ARRAY :=(
    48 => 0, -- "30" UNDOCUMENTED
    49 => 0, -- "31" UNDOCUMENTED
    50 => 0, -- "32" UNDOCUMENTED
    51 => 0, -- "33" UNDOCUMENTED
    52 => 0, -- "34" UNDOCUMENTED
    53 => 0, -- "35" UNDOCUMENTED
    54 => 0, -- "36" UNDOCUMENTED
    55 => 0, -- "37" UNDOCUMENTED
others=>0);
constant latences_DD:LATENCE_ARRAY :=(
16 => 1, -- "10" --human calibrate
    34 => 1, -- "22"
    42 => 1, -- "2a"
50 => 1, -- "32" --human calibrate
    54 => 1, -- "36" -- ?
58 => 1, -- "3a" --human calibrate
192 => 1, -- "c0" --human calibrate -- ?
196 => 1, -- "c4" --human calibrate
197 => 1, -- "c5" --human calibrate
199 => 1, -- "c7" --human calibrate
200 => 1, -- "c8" --human calibrate
204 => 1, -- "cc" --human calibrate
205 => 1, -- "cd" --human calibrate
207 => 1, -- "cf" --human calibrate
208 => 1, -- "d0" --human calibrate
212 => 1, -- "d4" --human calibrate
213 => 1, -- "d5" --human calibrate
215 => 1, -- "d7" --human calibrate
216 => 1, -- "d8" --human calibrate
220 => 1, -- "dc" --human calibrate
223 => 1, -- "df" --human calibrate
224 => 1, -- "e0" --human calibrate
    227 => 1, -- "e3" --?
228 => 1, -- "e4" --human calibrate
    229 => 1, -- "e5" -- ?
231 => 1, -- "e7" --human calibrate
232 => 1, -- "e8" --human calibrate
236 => 1, -- "ec" --human calibrate
239 => 1, -- "ef" --human calibrate
240 => 1, -- "f0" --human calibrate
244 => 1, -- "f4" --human calibrate
245 => 1, -- "f5" --human calibrate
247 => 1, -- "f7" --human calibrate
248 => 1, -- "f8" --human calibrate
252 => 1, -- "fc" --human calibrate
255 => 1, -- "ff" --human calibrate
    0 => 0, -- "00" UNDOCUMENTED
    1 => 0, -- "01" UNDOCUMENTED
    2 => 0, -- "02" UNDOCUMENTED
    3 => 0, -- "03" UNDOCUMENTED
    4 => 0, -- "04" UNDOCUMENTED
    5 => 0, -- "05" UNDOCUMENTED
    6 => 0, -- "06" UNDOCUMENTED
    7 => 0, -- "07" UNDOCUMENTED
    8 => 0, -- "08" UNDOCUMENTED
    10 => 0, -- "0a" UNDOCUMENTED
    11 => 0, -- "0b" UNDOCUMENTED
    12 => 0, -- "0c" UNDOCUMENTED
    13 => 0, -- "0d" UNDOCUMENTED
    14 => 0, -- "0e" UNDOCUMENTED
    15 => 0, -- "0f" UNDOCUMENTED
    17 => 0, -- "11" UNDOCUMENTED
    18 => 0, -- "12" UNDOCUMENTED
    19 => 0, -- "13" UNDOCUMENTED
    20 => 0, -- "14" UNDOCUMENTED
    21 => 0, -- "15" UNDOCUMENTED
    22 => 0, -- "16" UNDOCUMENTED
    23 => 0, -- "17" UNDOCUMENTED
    24 => 0, -- "18" UNDOCUMENTED
    26 => 0, -- "1a" UNDOCUMENTED
    27 => 0, -- "1b" UNDOCUMENTED
    28 => 0, -- "1c" UNDOCUMENTED
    29 => 0, -- "1d" UNDOCUMENTED
    30 => 0, -- "1e" UNDOCUMENTED
    31 => 0, -- "1f" UNDOCUMENTED
    32 => 0, -- "20" UNDOCUMENTED
    36 => 0, -- "24" UNDOCUMENTED
    37 => 0, -- "25" UNDOCUMENTED
    38 => 0, -- "26" UNDOCUMENTED
    39 => 0, -- "27" UNDOCUMENTED
    40 => 0, -- "28" UNDOCUMENTED
    44 => 0, -- "2c" UNDOCUMENTED
    45 => 0, -- "2d" UNDOCUMENTED
    46 => 0, -- "2e" UNDOCUMENTED
    47 => 0, -- "2f" UNDOCUMENTED
    48 => 0, -- "30" UNDOCUMENTED
    49 => 0, -- "31" UNDOCUMENTED
    51 => 0, -- "33" UNDOCUMENTED
    55 => 0, -- "37" UNDOCUMENTED
    56 => 0, -- "38" UNDOCUMENTED
    59 => 0, -- "3b" UNDOCUMENTED
    60 => 0, -- "3c" UNDOCUMENTED
    61 => 0, -- "3d" UNDOCUMENTED
    62 => 0, -- "3e" UNDOCUMENTED
    63 => 0, -- "3f" UNDOCUMENTED
    64 => 0, -- "40" UNDOCUMENTED
    65 => 0, -- "41" UNDOCUMENTED
    66 => 0, -- "42" UNDOCUMENTED
    67 => 0, -- "43" UNDOCUMENTED
    68 => 0, -- "44" UNDOCUMENTED
    69 => 0, -- "45" UNDOCUMENTED
    71 => 0, -- "47" UNDOCUMENTED
    72 => 0, -- "48" UNDOCUMENTED
    73 => 0, -- "49" UNDOCUMENTED
    74 => 0, -- "4a" UNDOCUMENTED
    75 => 0, -- "4b" UNDOCUMENTED
    76 => 0, -- "4c" UNDOCUMENTED
    77 => 0, -- "4d" UNDOCUMENTED
    79 => 0, -- "4f" UNDOCUMENTED
    80 => 0, -- "50" UNDOCUMENTED
    81 => 0, -- "51" UNDOCUMENTED
    82 => 0, -- "52" UNDOCUMENTED
    83 => 0, -- "53" UNDOCUMENTED
    84 => 0, -- "54" UNDOCUMENTED
    85 => 0, -- "55" UNDOCUMENTED
    87 => 0, -- "57" UNDOCUMENTED
    88 => 0, -- "58" UNDOCUMENTED
    89 => 0, -- "59" UNDOCUMENTED
    90 => 0, -- "5a" UNDOCUMENTED
    91 => 0, -- "5b" UNDOCUMENTED
    92 => 0, -- "5c" UNDOCUMENTED
    93 => 0, -- "5d" UNDOCUMENTED
    95 => 0, -- "5f" UNDOCUMENTED
    96 => 0, -- "60" UNDOCUMENTED
    97 => 0, -- "61" UNDOCUMENTED
    98 => 0, -- "62" UNDOCUMENTED
    99 => 0, -- "63" UNDOCUMENTED
    100 => 0, -- "64" UNDOCUMENTED
    101 => 0, -- "65" UNDOCUMENTED
    103 => 0, -- "67" UNDOCUMENTED
    104 => 0, -- "68" UNDOCUMENTED
    105 => 0, -- "69" UNDOCUMENTED
    106 => 0, -- "6a" UNDOCUMENTED
    107 => 0, -- "6b" UNDOCUMENTED
    108 => 0, -- "6c" UNDOCUMENTED
    109 => 0, -- "6d" UNDOCUMENTED
    111 => 0, -- "6f" UNDOCUMENTED
    118 => 0, -- "76" UNDOCUMENTED
    120 => 0, -- "78" UNDOCUMENTED
    121 => 0, -- "79" UNDOCUMENTED
    122 => 0, -- "7a" UNDOCUMENTED
    123 => 0, -- "7b" UNDOCUMENTED
    124 => 0, -- "7c" UNDOCUMENTED
    125 => 0, -- "7d" UNDOCUMENTED
    127 => 0, -- "7f" UNDOCUMENTED
    128 => 0, -- "80" UNDOCUMENTED
    129 => 0, -- "81" UNDOCUMENTED
    130 => 0, -- "82" UNDOCUMENTED
    131 => 0, -- "83" UNDOCUMENTED
    132 => 0, -- "84" UNDOCUMENTED
    133 => 0, -- "85" UNDOCUMENTED
    135 => 0, -- "87" UNDOCUMENTED
    136 => 0, -- "88" UNDOCUMENTED
    137 => 0, -- "89" UNDOCUMENTED
    138 => 0, -- "8a" UNDOCUMENTED
    139 => 0, -- "8b" UNDOCUMENTED
    140 => 0, -- "8c" UNDOCUMENTED
    141 => 0, -- "8d" UNDOCUMENTED
    143 => 0, -- "8f" UNDOCUMENTED
    144 => 0, -- "90" UNDOCUMENTED
    145 => 0, -- "91" UNDOCUMENTED
    146 => 0, -- "92" UNDOCUMENTED
    147 => 0, -- "93" UNDOCUMENTED
    148 => 0, -- "94" UNDOCUMENTED
    149 => 0, -- "95" UNDOCUMENTED
    151 => 0, -- "97" UNDOCUMENTED
    152 => 0, -- "98" UNDOCUMENTED
    153 => 0, -- "99" UNDOCUMENTED
    154 => 0, -- "9a" UNDOCUMENTED
    155 => 0, -- "9b" UNDOCUMENTED
    156 => 0, -- "9c" UNDOCUMENTED
    157 => 0, -- "9d" UNDOCUMENTED
    159 => 0, -- "9f" UNDOCUMENTED
    160 => 0, -- "a0" UNDOCUMENTED
    161 => 0, -- "a1" UNDOCUMENTED
    162 => 0, -- "a2" UNDOCUMENTED
    163 => 0, -- "a3" UNDOCUMENTED
    164 => 0, -- "a4" UNDOCUMENTED
    165 => 0, -- "a5" UNDOCUMENTED
    167 => 0, -- "a7" UNDOCUMENTED
    168 => 0, -- "a8" UNDOCUMENTED
    169 => 0, -- "a9" UNDOCUMENTED
    170 => 0, -- "aa" UNDOCUMENTED
    171 => 0, -- "ab" UNDOCUMENTED
    172 => 0, -- "ac" UNDOCUMENTED
    173 => 0, -- "ad" UNDOCUMENTED
    175 => 0, -- "af" UNDOCUMENTED
    176 => 0, -- "b0" UNDOCUMENTED
    177 => 0, -- "b1" UNDOCUMENTED
    178 => 0, -- "b2" UNDOCUMENTED
    179 => 0, -- "b3" UNDOCUMENTED
    180 => 0, -- "b4" UNDOCUMENTED
    181 => 0, -- "b5" UNDOCUMENTED
    183 => 0, -- "b7" UNDOCUMENTED
    184 => 0, -- "b8" UNDOCUMENTED
    185 => 0, -- "b9" UNDOCUMENTED
    186 => 0, -- "ba" UNDOCUMENTED
    187 => 0, -- "bb" UNDOCUMENTED
    188 => 0, -- "bc" UNDOCUMENTED
    189 => 0, -- "bd" UNDOCUMENTED
    191 => 0, -- "bf" UNDOCUMENTED
    193 => 0, -- "c1" UNDOCUMENTED
    194 => 0, -- "c2" UNDOCUMENTED
    195 => 0, -- "c3" UNDOCUMENTED
    198 => 0, -- "c6" UNDOCUMENTED
    201 => 0, -- "c9" UNDOCUMENTED
    202 => 0, -- "ca" UNDOCUMENTED
    206 => 0, -- "ce" UNDOCUMENTED
    209 => 0, -- "d1" UNDOCUMENTED
    210 => 0, -- "d2" UNDOCUMENTED
    211 => 0, -- "d3" UNDOCUMENTED
    214 => 0, -- "d6" UNDOCUMENTED
    217 => 0, -- "d9" UNDOCUMENTED
    218 => 0, -- "da" UNDOCUMENTED
    219 => 0, -- "db" UNDOCUMENTED
    222 => 0, -- "de" UNDOCUMENTED
    226 => 0, -- "e2" UNDOCUMENTED
    230 => 0, -- "e6" UNDOCUMENTED
    233 => 0, -- "e9" UNDOCUMENTED
    234 => 0, -- "ea" UNDOCUMENTED
    235 => 0, -- "eb" UNDOCUMENTED
    238 => 0, -- "ee" UNDOCUMENTED
    241 => 0, -- "f1" UNDOCUMENTED
    242 => 0, -- "f2" UNDOCUMENTED
    243 => 0, -- "f3" UNDOCUMENTED
    246 => 0, -- "f6" UNDOCUMENTED
    250 => 0, -- "fa" UNDOCUMENTED
    251 => 0, -- "fb" UNDOCUMENTED
    254 => 0, -- "fe" UNDOCUMENTED
    -- "cb" NOT TESTED
    -- "dd" NOT TESTED
    -- "ed" NOT TESTED
    -- "fd" NOT TESTED
others=>0);
constant latences_ED:LATENCE_ARRAY :=(
    64 => 1, -- "40"
    65 => 1, -- "41"
    67 => 1, -- "43"
71 => 1, -- "47" --human calibrate
    72 => 1, -- "48"
    73 => 1, -- "49"
    75 => 1, -- "4b"
79 => 1, -- "4f" --human calibrate
    80 => 1, -- "50"
    81 => 1, -- "51"
    83 => 1, -- "53"
87 => 1, -- "57" --human calibrate
    88 => 1, -- "58"
    89 => 1, -- "59"
    91 => 1, -- "5b"
95 => 1, -- "5f" --human calibrate
    96 => 1, -- "60"
    97 => 1, -- "61"
    99 => 1, -- "63"
    104 => 1, -- "68"
    105 => 1, -- "69"
    107 => 1, -- "6b"
    112 => 1, -- "70"
113 => 1, -- "71" --human calibrate
    115 => 1, -- "73"
    120 => 1, -- "78"
    121 => 1, -- "79"
    123 => 1, -- "7b"
    160 => 1, -- "a0"
    162 => 1, -- "a2"
    163 => 1, -- "a3"
    168 => 1, -- "a8"
    170 => 1, -- "aa"
    171 => 1, -- "ab"
    176 => 1, -- "b0"
177 => 1, -- "b1" --human calibrate
    178 => 1, -- "b2"
    179 => 1, -- "b3"
    184 => 1, -- "b8"
185 => 1, -- "b9" --human calibrate
    186 => 1, -- "ba"
    187 => 1, -- "bb"
    0 => 0, -- "00" UNDOCUMENTED
    1 => 0, -- "01" UNDOCUMENTED
    2 => 0, -- "02" UNDOCUMENTED
    3 => 0, -- "03" UNDOCUMENTED
    4 => 0, -- "04" UNDOCUMENTED
    5 => 0, -- "05" UNDOCUMENTED
    6 => 0, -- "06" UNDOCUMENTED
    7 => 0, -- "07" UNDOCUMENTED
    8 => 0, -- "08" UNDOCUMENTED
    9 => 0, -- "09" UNDOCUMENTED
    10 => 0, -- "0a" UNDOCUMENTED
    11 => 0, -- "0b" UNDOCUMENTED
    12 => 0, -- "0c" UNDOCUMENTED
    13 => 0, -- "0d" UNDOCUMENTED
    14 => 0, -- "0e" UNDOCUMENTED
    15 => 0, -- "0f" UNDOCUMENTED
    16 => 0, -- "10" UNDOCUMENTED
    17 => 0, -- "11" UNDOCUMENTED
    18 => 0, -- "12" UNDOCUMENTED
    19 => 0, -- "13" UNDOCUMENTED
    20 => 0, -- "14" UNDOCUMENTED
    21 => 0, -- "15" UNDOCUMENTED
    22 => 0, -- "16" UNDOCUMENTED
    23 => 0, -- "17" UNDOCUMENTED
    24 => 0, -- "18" UNDOCUMENTED
    25 => 0, -- "19" UNDOCUMENTED
    26 => 0, -- "1a" UNDOCUMENTED
    27 => 0, -- "1b" UNDOCUMENTED
    28 => 0, -- "1c" UNDOCUMENTED
    29 => 0, -- "1d" UNDOCUMENTED
    30 => 0, -- "1e" UNDOCUMENTED
    31 => 0, -- "1f" UNDOCUMENTED
    32 => 0, -- "20" UNDOCUMENTED
    33 => 0, -- "21" UNDOCUMENTED
    34 => 0, -- "22" UNDOCUMENTED
    35 => 0, -- "23" UNDOCUMENTED
    36 => 0, -- "24" UNDOCUMENTED
    37 => 0, -- "25" UNDOCUMENTED
    38 => 0, -- "26" UNDOCUMENTED
    39 => 0, -- "27" UNDOCUMENTED
    40 => 0, -- "28" UNDOCUMENTED
    41 => 0, -- "29" UNDOCUMENTED
    42 => 0, -- "2a" UNDOCUMENTED
    43 => 0, -- "2b" UNDOCUMENTED
    44 => 0, -- "2c" UNDOCUMENTED
    45 => 0, -- "2d" UNDOCUMENTED
    46 => 0, -- "2e" UNDOCUMENTED
    47 => 0, -- "2f" UNDOCUMENTED
    48 => 0, -- "30" UNDOCUMENTED
    49 => 0, -- "31" UNDOCUMENTED
    50 => 0, -- "32" UNDOCUMENTED
    51 => 0, -- "33" UNDOCUMENTED
    52 => 0, -- "34" UNDOCUMENTED
    53 => 0, -- "35" UNDOCUMENTED
    54 => 0, -- "36" UNDOCUMENTED
    55 => 0, -- "37" UNDOCUMENTED
    56 => 0, -- "38" UNDOCUMENTED
    57 => 0, -- "39" UNDOCUMENTED
    58 => 0, -- "3a" UNDOCUMENTED
    59 => 0, -- "3b" UNDOCUMENTED
    60 => 0, -- "3c" UNDOCUMENTED
    61 => 0, -- "3d" UNDOCUMENTED
    62 => 0, -- "3e" UNDOCUMENTED
    63 => 0, -- "3f" UNDOCUMENTED
    76 => 0, -- "4c" UNDOCUMENTED
    78 => 0, -- "4e" UNDOCUMENTED
    84 => 0, -- "54" UNDOCUMENTED
    85 => 0, -- "55" UNDOCUMENTED
    92 => 0, -- "5c" UNDOCUMENTED
    93 => 0, -- "5d" UNDOCUMENTED
    100 => 0, -- "64" UNDOCUMENTED
    101 => 0, -- "65" UNDOCUMENTED
    102 => 0, -- "66" UNDOCUMENTED
    108 => 0, -- "6c" UNDOCUMENTED
    109 => 0, -- "6d" UNDOCUMENTED
    110 => 0, -- "6e" UNDOCUMENTED
    116 => 0, -- "74" UNDOCUMENTED
    117 => 0, -- "75" UNDOCUMENTED
    118 => 0, -- "76" UNDOCUMENTED
    119 => 0, -- "77" UNDOCUMENTED
    124 => 0, -- "7c" UNDOCUMENTED
    125 => 0, -- "7d" UNDOCUMENTED
    126 => 0, -- "7e" UNDOCUMENTED
    127 => 0, -- "7f" UNDOCUMENTED
    128 => 0, -- "80" UNDOCUMENTED
    129 => 0, -- "81" UNDOCUMENTED
    130 => 0, -- "82" UNDOCUMENTED
    131 => 0, -- "83" UNDOCUMENTED
    132 => 0, -- "84" UNDOCUMENTED
    133 => 0, -- "85" UNDOCUMENTED
    134 => 0, -- "86" UNDOCUMENTED
    135 => 0, -- "87" UNDOCUMENTED
    136 => 0, -- "88" UNDOCUMENTED
    137 => 0, -- "89" UNDOCUMENTED
    138 => 0, -- "8a" UNDOCUMENTED
    139 => 0, -- "8b" UNDOCUMENTED
    140 => 0, -- "8c" UNDOCUMENTED
    141 => 0, -- "8d" UNDOCUMENTED
    142 => 0, -- "8e" UNDOCUMENTED
    143 => 0, -- "8f" UNDOCUMENTED
    144 => 0, -- "90" UNDOCUMENTED
    145 => 0, -- "91" UNDOCUMENTED
    146 => 0, -- "92" UNDOCUMENTED
    147 => 0, -- "93" UNDOCUMENTED
    148 => 0, -- "94" UNDOCUMENTED
    149 => 0, -- "95" UNDOCUMENTED
    150 => 0, -- "96" UNDOCUMENTED
    151 => 0, -- "97" UNDOCUMENTED
    152 => 0, -- "98" UNDOCUMENTED
    153 => 0, -- "99" UNDOCUMENTED
    154 => 0, -- "9a" UNDOCUMENTED
    155 => 0, -- "9b" UNDOCUMENTED
    156 => 0, -- "9c" UNDOCUMENTED
    157 => 0, -- "9d" UNDOCUMENTED
    158 => 0, -- "9e" UNDOCUMENTED
    159 => 0, -- "9f" UNDOCUMENTED
    164 => 0, -- "a4" UNDOCUMENTED
    165 => 0, -- "a5" UNDOCUMENTED
    166 => 0, -- "a6" UNDOCUMENTED
    167 => 0, -- "a7" UNDOCUMENTED
    172 => 0, -- "ac" UNDOCUMENTED
    173 => 0, -- "ad" UNDOCUMENTED
    174 => 0, -- "ae" UNDOCUMENTED
    175 => 0, -- "af" UNDOCUMENTED
    180 => 0, -- "b4" UNDOCUMENTED
    181 => 0, -- "b5" UNDOCUMENTED
    182 => 0, -- "b6" UNDOCUMENTED
    183 => 0, -- "b7" UNDOCUMENTED
    188 => 0, -- "bc" UNDOCUMENTED
    189 => 0, -- "bd" UNDOCUMENTED
    190 => 0, -- "be" UNDOCUMENTED
    191 => 0, -- "bf" UNDOCUMENTED
    192 => 0, -- "c0" UNDOCUMENTED
    193 => 0, -- "c1" UNDOCUMENTED
    194 => 0, -- "c2" UNDOCUMENTED
    195 => 0, -- "c3" UNDOCUMENTED
    196 => 0, -- "c4" UNDOCUMENTED
    197 => 0, -- "c5" UNDOCUMENTED
    198 => 0, -- "c6" UNDOCUMENTED
    199 => 0, -- "c7" UNDOCUMENTED
    200 => 0, -- "c8" UNDOCUMENTED
    201 => 0, -- "c9" UNDOCUMENTED
    202 => 0, -- "ca" UNDOCUMENTED
    203 => 0, -- "cb" UNDOCUMENTED
    204 => 0, -- "cc" UNDOCUMENTED
    205 => 0, -- "cd" UNDOCUMENTED
    206 => 0, -- "ce" UNDOCUMENTED
    207 => 0, -- "cf" UNDOCUMENTED
    208 => 0, -- "d0" UNDOCUMENTED
    209 => 0, -- "d1" UNDOCUMENTED
    210 => 0, -- "d2" UNDOCUMENTED
    211 => 0, -- "d3" UNDOCUMENTED
    212 => 0, -- "d4" UNDOCUMENTED
    213 => 0, -- "d5" UNDOCUMENTED
    214 => 0, -- "d6" UNDOCUMENTED
    215 => 0, -- "d7" UNDOCUMENTED
    216 => 0, -- "d8" UNDOCUMENTED
    217 => 0, -- "d9" UNDOCUMENTED
    218 => 0, -- "da" UNDOCUMENTED
    219 => 0, -- "db" UNDOCUMENTED
    220 => 0, -- "dc" UNDOCUMENTED
    221 => 0, -- "dd" UNDOCUMENTED
    222 => 0, -- "de" UNDOCUMENTED
    223 => 0, -- "df" UNDOCUMENTED
    224 => 0, -- "e0" UNDOCUMENTED
    225 => 0, -- "e1" UNDOCUMENTED
    226 => 0, -- "e2" UNDOCUMENTED
    227 => 0, -- "e3" UNDOCUMENTED
    228 => 0, -- "e4" UNDOCUMENTED
    229 => 0, -- "e5" UNDOCUMENTED
    230 => 0, -- "e6" UNDOCUMENTED
    231 => 0, -- "e7" UNDOCUMENTED
    232 => 0, -- "e8" UNDOCUMENTED
    233 => 0, -- "e9" UNDOCUMENTED
    234 => 0, -- "ea" UNDOCUMENTED
    235 => 0, -- "eb" UNDOCUMENTED
    236 => 0, -- "ec" UNDOCUMENTED
    237 => 0, -- "ed" UNDOCUMENTED
    238 => 0, -- "ee" UNDOCUMENTED
    239 => 0, -- "ef" UNDOCUMENTED
    240 => 0, -- "f0" UNDOCUMENTED
    241 => 0, -- "f1" UNDOCUMENTED
    242 => 0, -- "f2" UNDOCUMENTED
    243 => 0, -- "f3" UNDOCUMENTED
    244 => 0, -- "f4" UNDOCUMENTED
    245 => 0, -- "f5" UNDOCUMENTED
    246 => 0, -- "f6" UNDOCUMENTED
    247 => 0, -- "f7" UNDOCUMENTED
    248 => 0, -- "f8" UNDOCUMENTED
    249 => 0, -- "f9" UNDOCUMENTED
    250 => 0, -- "fa" UNDOCUMENTED
    251 => 0, -- "fb" UNDOCUMENTED
    252 => 0, -- "fc" UNDOCUMENTED
    253 => 0, -- "fd" UNDOCUMENTED
    254 => 0, -- "fe" UNDOCUMENTED
    255 => 0, -- "ff" UNDOCUMENTED
others=>0);
constant latences_FD:LATENCE_ARRAY :=(
16 => 1, -- "10" --human calibrate
    34 => 1, -- "22"
    42 => 1, -- "2a"
50 => 1, -- "32" --human calibrate
    54 => 1, -- "36" -- ?
58 => 1, -- "3a" --human calibrate
192 => 1, -- "c0" --human calibrate
196 => 1, -- "c4" --human calibrate
197 => 1, -- "c5" --human calibrate
199 => 1, -- "c7" --human calibrate
200 => 1, -- "c8" --human calibrate
204 => 1, -- "cc" --human calibrate
205 => 1, -- "cd" --human calibrate
207 => 1, -- "cf" --human calibrate
208 => 1, -- "d0" --human calibrate
212 => 1, -- "d4" --human calibrate
213 => 1, -- "d5" --human calibrate
215 => 1, -- "d7" --human calibrate
216 => 1, -- "d8" --human calibrate
220 => 1, -- "dc" --human calibrate
223 => 1, -- "df" --human calibrate
224 => 1, -- "e0" --human calibrate
    227 => 1, -- "e3" -- ?
228 => 1, -- "e4" --human calibrate
    229 => 1, -- "e5" -- ?
231 => 1, -- "e7" --human calibrate
232 => 1, -- "e8" --human calibrate
236 => 1, -- "ec" --human calibrate
239 => 1, -- "ef" --human calibrate
240 => 1, -- "f0" --human calibrate
244 => 1, -- "f4" --human calibrate
245 => 1, -- "f5" --human calibrate
247 => 1, -- "f7" --human calibrate
248 => 1, -- "f8" --human calibrate
252 => 1, -- "fc" --human calibrate
255 => 1, -- "ff" --human calibrate
    0 => 0, -- "00" UNDOCUMENTED
    1 => 0, -- "01" UNDOCUMENTED
    2 => 0, -- "02" UNDOCUMENTED
    3 => 0, -- "03" UNDOCUMENTED
    4 => 0, -- "04" UNDOCUMENTED
    5 => 0, -- "05" UNDOCUMENTED
    6 => 0, -- "06" UNDOCUMENTED
    7 => 0, -- "07" UNDOCUMENTED
    8 => 0, -- "08" UNDOCUMENTED
    10 => 0, -- "0a" UNDOCUMENTED
    11 => 0, -- "0b" UNDOCUMENTED
    12 => 0, -- "0c" UNDOCUMENTED
    13 => 0, -- "0d" UNDOCUMENTED
    14 => 0, -- "0e" UNDOCUMENTED
    15 => 0, -- "0f" UNDOCUMENTED
    17 => 0, -- "11" UNDOCUMENTED
    18 => 0, -- "12" UNDOCUMENTED
    19 => 0, -- "13" UNDOCUMENTED
    20 => 0, -- "14" UNDOCUMENTED
    21 => 0, -- "15" UNDOCUMENTED
    22 => 0, -- "16" UNDOCUMENTED
    23 => 0, -- "17" UNDOCUMENTED
    24 => 0, -- "18" UNDOCUMENTED
    26 => 0, -- "1a" UNDOCUMENTED
    27 => 0, -- "1b" UNDOCUMENTED
    28 => 0, -- "1c" UNDOCUMENTED
    29 => 0, -- "1d" UNDOCUMENTED
    30 => 0, -- "1e" UNDOCUMENTED
    31 => 0, -- "1f" UNDOCUMENTED
    32 => 0, -- "20" UNDOCUMENTED
    36 => 0, -- "24" UNDOCUMENTED
    37 => 0, -- "25" UNDOCUMENTED
    38 => 0, -- "26" UNDOCUMENTED
    39 => 0, -- "27" UNDOCUMENTED
    40 => 0, -- "28" UNDOCUMENTED
    44 => 0, -- "2c" UNDOCUMENTED
    45 => 0, -- "2d" UNDOCUMENTED
    46 => 0, -- "2e" UNDOCUMENTED
    47 => 0, -- "2f" UNDOCUMENTED
    48 => 0, -- "30" UNDOCUMENTED
    49 => 0, -- "31" UNDOCUMENTED
    51 => 0, -- "33" UNDOCUMENTED
    55 => 0, -- "37" UNDOCUMENTED
    56 => 0, -- "38" UNDOCUMENTED
    59 => 0, -- "3b" UNDOCUMENTED
    60 => 0, -- "3c" UNDOCUMENTED
    61 => 0, -- "3d" UNDOCUMENTED
    62 => 0, -- "3e" UNDOCUMENTED
    63 => 0, -- "3f" UNDOCUMENTED
    64 => 0, -- "40" UNDOCUMENTED
    65 => 0, -- "41" UNDOCUMENTED
    66 => 0, -- "42" UNDOCUMENTED
    67 => 0, -- "43" UNDOCUMENTED
    68 => 0, -- "44" UNDOCUMENTED
    69 => 0, -- "45" UNDOCUMENTED
    71 => 0, -- "47" UNDOCUMENTED
    72 => 0, -- "48" UNDOCUMENTED
    73 => 0, -- "49" UNDOCUMENTED
    74 => 0, -- "4a" UNDOCUMENTED
    75 => 0, -- "4b" UNDOCUMENTED
    76 => 0, -- "4c" UNDOCUMENTED
    77 => 0, -- "4d" UNDOCUMENTED
    79 => 0, -- "4f" UNDOCUMENTED
    80 => 0, -- "50" UNDOCUMENTED
    81 => 0, -- "51" UNDOCUMENTED
    82 => 0, -- "52" UNDOCUMENTED
    83 => 0, -- "53" UNDOCUMENTED
    84 => 0, -- "54" UNDOCUMENTED
    85 => 0, -- "55" UNDOCUMENTED
    87 => 0, -- "57" UNDOCUMENTED
    88 => 0, -- "58" UNDOCUMENTED
    89 => 0, -- "59" UNDOCUMENTED
    90 => 0, -- "5a" UNDOCUMENTED
    91 => 0, -- "5b" UNDOCUMENTED
    92 => 0, -- "5c" UNDOCUMENTED
    93 => 0, -- "5d" UNDOCUMENTED
    95 => 0, -- "5f" UNDOCUMENTED
    96 => 0, -- "60" UNDOCUMENTED
    97 => 0, -- "61" UNDOCUMENTED
    98 => 0, -- "62" UNDOCUMENTED
    99 => 0, -- "63" UNDOCUMENTED
    100 => 0, -- "64" UNDOCUMENTED
    101 => 0, -- "65" UNDOCUMENTED
    103 => 0, -- "67" UNDOCUMENTED
    104 => 0, -- "68" UNDOCUMENTED
    105 => 0, -- "69" UNDOCUMENTED
    106 => 0, -- "6a" UNDOCUMENTED
    107 => 0, -- "6b" UNDOCUMENTED
    108 => 0, -- "6c" UNDOCUMENTED
    109 => 0, -- "6d" UNDOCUMENTED
    111 => 0, -- "6f" UNDOCUMENTED
    118 => 0, -- "76" UNDOCUMENTED
    120 => 0, -- "78" UNDOCUMENTED
    121 => 0, -- "79" UNDOCUMENTED
    122 => 0, -- "7a" UNDOCUMENTED
    123 => 0, -- "7b" UNDOCUMENTED
    124 => 0, -- "7c" UNDOCUMENTED
    125 => 0, -- "7d" UNDOCUMENTED
    127 => 0, -- "7f" UNDOCUMENTED
    128 => 0, -- "80" UNDOCUMENTED
    129 => 0, -- "81" UNDOCUMENTED
    130 => 0, -- "82" UNDOCUMENTED
    131 => 0, -- "83" UNDOCUMENTED
    132 => 0, -- "84" UNDOCUMENTED
    133 => 0, -- "85" UNDOCUMENTED
    135 => 0, -- "87" UNDOCUMENTED
    136 => 0, -- "88" UNDOCUMENTED
    137 => 0, -- "89" UNDOCUMENTED
    138 => 0, -- "8a" UNDOCUMENTED
    139 => 0, -- "8b" UNDOCUMENTED
    140 => 0, -- "8c" UNDOCUMENTED
    141 => 0, -- "8d" UNDOCUMENTED
    143 => 0, -- "8f" UNDOCUMENTED
    144 => 0, -- "90" UNDOCUMENTED
    145 => 0, -- "91" UNDOCUMENTED
    146 => 0, -- "92" UNDOCUMENTED
    147 => 0, -- "93" UNDOCUMENTED
    148 => 0, -- "94" UNDOCUMENTED
    149 => 0, -- "95" UNDOCUMENTED
    151 => 0, -- "97" UNDOCUMENTED
    152 => 0, -- "98" UNDOCUMENTED
    153 => 0, -- "99" UNDOCUMENTED
    154 => 0, -- "9a" UNDOCUMENTED
    155 => 0, -- "9b" UNDOCUMENTED
    156 => 0, -- "9c" UNDOCUMENTED
    157 => 0, -- "9d" UNDOCUMENTED
    159 => 0, -- "9f" UNDOCUMENTED
    160 => 0, -- "a0" UNDOCUMENTED
    161 => 0, -- "a1" UNDOCUMENTED
    162 => 0, -- "a2" UNDOCUMENTED
    163 => 0, -- "a3" UNDOCUMENTED
    164 => 0, -- "a4" UNDOCUMENTED
    165 => 0, -- "a5" UNDOCUMENTED
    167 => 0, -- "a7" UNDOCUMENTED
    168 => 0, -- "a8" UNDOCUMENTED
    169 => 0, -- "a9" UNDOCUMENTED
    170 => 0, -- "aa" UNDOCUMENTED
    171 => 0, -- "ab" UNDOCUMENTED
    172 => 0, -- "ac" UNDOCUMENTED
    173 => 0, -- "ad" UNDOCUMENTED
    175 => 0, -- "af" UNDOCUMENTED
    176 => 0, -- "b0" UNDOCUMENTED
    177 => 0, -- "b1" UNDOCUMENTED
    178 => 0, -- "b2" UNDOCUMENTED
    179 => 0, -- "b3" UNDOCUMENTED
    180 => 0, -- "b4" UNDOCUMENTED
    181 => 0, -- "b5" UNDOCUMENTED
    183 => 0, -- "b7" UNDOCUMENTED
    184 => 0, -- "b8" UNDOCUMENTED
    185 => 0, -- "b9" UNDOCUMENTED
    186 => 0, -- "ba" UNDOCUMENTED
    187 => 0, -- "bb" UNDOCUMENTED
    188 => 0, -- "bc" UNDOCUMENTED
    189 => 0, -- "bd" UNDOCUMENTED
    191 => 0, -- "bf" UNDOCUMENTED
    193 => 0, -- "c1" UNDOCUMENTED
    194 => 0, -- "c2" UNDOCUMENTED
    195 => 0, -- "c3" UNDOCUMENTED
    198 => 0, -- "c6" UNDOCUMENTED
    201 => 0, -- "c9" UNDOCUMENTED
    202 => 0, -- "ca" UNDOCUMENTED
    206 => 0, -- "ce" UNDOCUMENTED
    209 => 0, -- "d1" UNDOCUMENTED
    210 => 0, -- "d2" UNDOCUMENTED
    211 => 0, -- "d3" UNDOCUMENTED
    214 => 0, -- "d6" UNDOCUMENTED
    217 => 0, -- "d9" UNDOCUMENTED
    218 => 0, -- "da" UNDOCUMENTED
    219 => 0, -- "db" UNDOCUMENTED
    222 => 0, -- "de" UNDOCUMENTED
    226 => 0, -- "e2" UNDOCUMENTED
    230 => 0, -- "e6" UNDOCUMENTED
    234 => 0, -- "ea" UNDOCUMENTED
    235 => 0, -- "eb" UNDOCUMENTED
    238 => 0, -- "ee" UNDOCUMENTED
    241 => 0, -- "f1" UNDOCUMENTED
    242 => 0, -- "f2" UNDOCUMENTED
    243 => 0, -- "f3" UNDOCUMENTED
    246 => 0, -- "f6" UNDOCUMENTED
    250 => 0, -- "fa" UNDOCUMENTED
    251 => 0, -- "fb" UNDOCUMENTED
    254 => 0, -- "fe" UNDOCUMENTED
    -- "cb" NOT TESTED
    -- "dd" NOT TESTED
    -- "ed" NOT TESTED
    -- "fd" NOT TESTED
others=>0);
constant latences_DDCB:LATENCE_ARRAY :=(
    6 => 1, -- "06"
    14 => 1, -- "0e"
    22 => 1, -- "16"
    30 => 1, -- "1e"
    38 => 1, -- "26"
    46 => 1, -- "2e"
    62 => 1, -- "3e"
    70 => 1, -- "46"
    78 => 1, -- "4e"
    86 => 1, -- "56"
    94 => 1, -- "5e"
    102 => 1, -- "66"
    110 => 1, -- "6e"
    118 => 1, -- "76"
    126 => 1, -- "7e"
    134 => 1, -- "86"
    142 => 1, -- "8e"
    150 => 1, -- "96"
    158 => 1, -- "9e"
    166 => 1, -- "a6"
    174 => 1, -- "ae"
    182 => 1, -- "b6"
    190 => 1, -- "be"
    198 => 1, -- "c6"
    206 => 1, -- "ce"
    214 => 1, -- "d6"
    222 => 1, -- "de"
    230 => 1, -- "e6"
    238 => 1, -- "ee"
    246 => 1, -- "f6"
    254 => 1, -- "fe"
    0 => 0, -- "00" UNDOCUMENTED
    1 => 0, -- "01" UNDOCUMENTED
    2 => 0, -- "02" UNDOCUMENTED
    3 => 0, -- "03" UNDOCUMENTED
    4 => 0, -- "04" UNDOCUMENTED
    5 => 0, -- "05" UNDOCUMENTED
    7 => 0, -- "07" UNDOCUMENTED
    8 => 0, -- "08" UNDOCUMENTED
    9 => 0, -- "09" UNDOCUMENTED
    10 => 0, -- "0a" UNDOCUMENTED
    11 => 0, -- "0b" UNDOCUMENTED
    12 => 0, -- "0c" UNDOCUMENTED
    13 => 0, -- "0d" UNDOCUMENTED
    15 => 0, -- "0f" UNDOCUMENTED
    16 => 0, -- "10" UNDOCUMENTED
    17 => 0, -- "11" UNDOCUMENTED
    18 => 0, -- "12" UNDOCUMENTED
    19 => 0, -- "13" UNDOCUMENTED
    20 => 0, -- "14" UNDOCUMENTED
    21 => 0, -- "15" UNDOCUMENTED
    23 => 0, -- "17" UNDOCUMENTED
    24 => 0, -- "18" UNDOCUMENTED
    25 => 0, -- "19" UNDOCUMENTED
    26 => 0, -- "1a" UNDOCUMENTED
    27 => 0, -- "1b" UNDOCUMENTED
    28 => 0, -- "1c" UNDOCUMENTED
    29 => 0, -- "1d" UNDOCUMENTED
    31 => 0, -- "1f" UNDOCUMENTED
    32 => 0, -- "20" UNDOCUMENTED
    33 => 0, -- "21" UNDOCUMENTED
    34 => 0, -- "22" UNDOCUMENTED
    35 => 0, -- "23" UNDOCUMENTED
    36 => 0, -- "24" UNDOCUMENTED
    37 => 0, -- "25" UNDOCUMENTED
    39 => 0, -- "27" UNDOCUMENTED
    40 => 0, -- "28" UNDOCUMENTED
    41 => 0, -- "29" UNDOCUMENTED
    42 => 0, -- "2a" UNDOCUMENTED
    43 => 0, -- "2b" UNDOCUMENTED
    44 => 0, -- "2c" UNDOCUMENTED
    45 => 0, -- "2d" UNDOCUMENTED
    47 => 0, -- "2f" UNDOCUMENTED
    48 => 0, -- "30" UNDOCUMENTED
    49 => 0, -- "31" UNDOCUMENTED
    50 => 0, -- "32" UNDOCUMENTED
    51 => 0, -- "33" UNDOCUMENTED
    52 => 0, -- "34" UNDOCUMENTED
    53 => 0, -- "35" UNDOCUMENTED
    54 => 0, -- "36" UNDOCUMENTED
    55 => 0, -- "37" UNDOCUMENTED
    56 => 0, -- "38" UNDOCUMENTED
    57 => 0, -- "39" UNDOCUMENTED
    58 => 0, -- "3a" UNDOCUMENTED
    59 => 0, -- "3b" UNDOCUMENTED
    60 => 0, -- "3c" UNDOCUMENTED
    61 => 0, -- "3d" UNDOCUMENTED
    63 => 0, -- "3f" UNDOCUMENTED
    64 => 0, -- "40" UNDOCUMENTED
    65 => 0, -- "41" UNDOCUMENTED
    66 => 0, -- "42" UNDOCUMENTED
    67 => 0, -- "43" UNDOCUMENTED
    68 => 0, -- "44" UNDOCUMENTED
    69 => 0, -- "45" UNDOCUMENTED
    71 => 0, -- "47" UNDOCUMENTED
    72 => 0, -- "48" UNDOCUMENTED
    73 => 0, -- "49" UNDOCUMENTED
    74 => 0, -- "4a" UNDOCUMENTED
    75 => 0, -- "4b" UNDOCUMENTED
    76 => 0, -- "4c" UNDOCUMENTED
    77 => 0, -- "4d" UNDOCUMENTED
    79 => 0, -- "4f" UNDOCUMENTED
    80 => 0, -- "50" UNDOCUMENTED
    81 => 0, -- "51" UNDOCUMENTED
    82 => 0, -- "52" UNDOCUMENTED
    83 => 0, -- "53" UNDOCUMENTED
    84 => 0, -- "54" UNDOCUMENTED
    85 => 0, -- "55" UNDOCUMENTED
    87 => 0, -- "57" UNDOCUMENTED
    88 => 0, -- "58" UNDOCUMENTED
    89 => 0, -- "59" UNDOCUMENTED
    90 => 0, -- "5a" UNDOCUMENTED
    91 => 0, -- "5b" UNDOCUMENTED
    92 => 0, -- "5c" UNDOCUMENTED
    93 => 0, -- "5d" UNDOCUMENTED
    95 => 0, -- "5f" UNDOCUMENTED
    96 => 0, -- "60" UNDOCUMENTED
    97 => 0, -- "61" UNDOCUMENTED
    98 => 0, -- "62" UNDOCUMENTED
    99 => 0, -- "63" UNDOCUMENTED
    100 => 0, -- "64" UNDOCUMENTED
    101 => 0, -- "65" UNDOCUMENTED
    103 => 0, -- "67" UNDOCUMENTED
    104 => 0, -- "68" UNDOCUMENTED
    105 => 0, -- "69" UNDOCUMENTED
    106 => 0, -- "6a" UNDOCUMENTED
    107 => 0, -- "6b" UNDOCUMENTED
    108 => 0, -- "6c" UNDOCUMENTED
    109 => 0, -- "6d" UNDOCUMENTED
    111 => 0, -- "6f" UNDOCUMENTED
    112 => 0, -- "70" UNDOCUMENTED
    113 => 0, -- "71" UNDOCUMENTED
    114 => 0, -- "72" UNDOCUMENTED
    115 => 0, -- "73" UNDOCUMENTED
    116 => 0, -- "74" UNDOCUMENTED
    117 => 0, -- "75" UNDOCUMENTED
    119 => 0, -- "77" UNDOCUMENTED
    120 => 0, -- "78" UNDOCUMENTED
    121 => 0, -- "79" UNDOCUMENTED
    122 => 0, -- "7a" UNDOCUMENTED
    123 => 0, -- "7b" UNDOCUMENTED
    124 => 0, -- "7c" UNDOCUMENTED
    125 => 0, -- "7d" UNDOCUMENTED
    127 => 0, -- "7f" UNDOCUMENTED
    128 => 0, -- "80" UNDOCUMENTED
    129 => 0, -- "81" UNDOCUMENTED
    130 => 0, -- "82" UNDOCUMENTED
    131 => 0, -- "83" UNDOCUMENTED
    132 => 0, -- "84" UNDOCUMENTED
    133 => 0, -- "85" UNDOCUMENTED
    135 => 0, -- "87" UNDOCUMENTED
    136 => 0, -- "88" UNDOCUMENTED
    137 => 0, -- "89" UNDOCUMENTED
    138 => 0, -- "8a" UNDOCUMENTED
    139 => 0, -- "8b" UNDOCUMENTED
    140 => 0, -- "8c" UNDOCUMENTED
    141 => 0, -- "8d" UNDOCUMENTED
    143 => 0, -- "8f" UNDOCUMENTED
    144 => 0, -- "90" UNDOCUMENTED
    145 => 0, -- "91" UNDOCUMENTED
    146 => 0, -- "92" UNDOCUMENTED
    147 => 0, -- "93" UNDOCUMENTED
    148 => 0, -- "94" UNDOCUMENTED
    149 => 0, -- "95" UNDOCUMENTED
    151 => 0, -- "97" UNDOCUMENTED
    152 => 0, -- "98" UNDOCUMENTED
    153 => 0, -- "99" UNDOCUMENTED
    154 => 0, -- "9a" UNDOCUMENTED
    155 => 0, -- "9b" UNDOCUMENTED
    156 => 0, -- "9c" UNDOCUMENTED
    157 => 0, -- "9d" UNDOCUMENTED
    159 => 0, -- "9f" UNDOCUMENTED
    160 => 0, -- "a0" UNDOCUMENTED
    161 => 0, -- "a1" UNDOCUMENTED
    162 => 0, -- "a2" UNDOCUMENTED
    163 => 0, -- "a3" UNDOCUMENTED
    164 => 0, -- "a4" UNDOCUMENTED
    165 => 0, -- "a5" UNDOCUMENTED
    167 => 0, -- "a7" UNDOCUMENTED
    168 => 0, -- "a8" UNDOCUMENTED
    169 => 0, -- "a9" UNDOCUMENTED
    170 => 0, -- "aa" UNDOCUMENTED
    171 => 0, -- "ab" UNDOCUMENTED
    172 => 0, -- "ac" UNDOCUMENTED
    173 => 0, -- "ad" UNDOCUMENTED
    175 => 0, -- "af" UNDOCUMENTED
    176 => 0, -- "b0" UNDOCUMENTED
    177 => 0, -- "b1" UNDOCUMENTED
    178 => 0, -- "b2" UNDOCUMENTED
    179 => 0, -- "b3" UNDOCUMENTED
    180 => 0, -- "b4" UNDOCUMENTED
    181 => 0, -- "b5" UNDOCUMENTED
    183 => 0, -- "b7" UNDOCUMENTED
    184 => 0, -- "b8" UNDOCUMENTED
    185 => 0, -- "b9" UNDOCUMENTED
    186 => 0, -- "ba" UNDOCUMENTED
    187 => 0, -- "bb" UNDOCUMENTED
    188 => 0, -- "bc" UNDOCUMENTED
    189 => 0, -- "bd" UNDOCUMENTED
    191 => 0, -- "bf" UNDOCUMENTED
    192 => 0, -- "c0" UNDOCUMENTED
    193 => 0, -- "c1" UNDOCUMENTED
    194 => 0, -- "c2" UNDOCUMENTED
    195 => 0, -- "c3" UNDOCUMENTED
    196 => 0, -- "c4" UNDOCUMENTED
    197 => 0, -- "c5" UNDOCUMENTED
    199 => 0, -- "c7" UNDOCUMENTED
    200 => 0, -- "c8" UNDOCUMENTED
    201 => 0, -- "c9" UNDOCUMENTED
    202 => 0, -- "ca" UNDOCUMENTED
    203 => 0, -- "cb" UNDOCUMENTED
    204 => 0, -- "cc" UNDOCUMENTED
    205 => 0, -- "cd" UNDOCUMENTED
    207 => 0, -- "cf" UNDOCUMENTED
    208 => 0, -- "d0" UNDOCUMENTED
    209 => 0, -- "d1" UNDOCUMENTED
    210 => 0, -- "d2" UNDOCUMENTED
    211 => 0, -- "d3" UNDOCUMENTED
    212 => 0, -- "d4" UNDOCUMENTED
    213 => 0, -- "d5" UNDOCUMENTED
    215 => 0, -- "d7" UNDOCUMENTED
    216 => 0, -- "d8" UNDOCUMENTED
    217 => 0, -- "d9" UNDOCUMENTED
    218 => 0, -- "da" UNDOCUMENTED
    219 => 0, -- "db" UNDOCUMENTED
    220 => 0, -- "dc" UNDOCUMENTED
    221 => 0, -- "dd" UNDOCUMENTED
    223 => 0, -- "df" UNDOCUMENTED
    224 => 0, -- "e0" UNDOCUMENTED
    225 => 0, -- "e1" UNDOCUMENTED
    226 => 0, -- "e2" UNDOCUMENTED
    227 => 0, -- "e3" UNDOCUMENTED
    228 => 0, -- "e4" UNDOCUMENTED
    229 => 0, -- "e5" UNDOCUMENTED
    231 => 0, -- "e7" UNDOCUMENTED
    232 => 0, -- "e8" UNDOCUMENTED
    233 => 0, -- "e9" UNDOCUMENTED
    234 => 0, -- "ea" UNDOCUMENTED
    235 => 0, -- "eb" UNDOCUMENTED
    236 => 0, -- "ec" UNDOCUMENTED
    237 => 0, -- "ed" UNDOCUMENTED
    239 => 0, -- "ef" UNDOCUMENTED
    240 => 0, -- "f0" UNDOCUMENTED
    241 => 0, -- "f1" UNDOCUMENTED
    242 => 0, -- "f2" UNDOCUMENTED
    243 => 0, -- "f3" UNDOCUMENTED
    244 => 0, -- "f4" UNDOCUMENTED
    245 => 0, -- "f5" UNDOCUMENTED
    247 => 0, -- "f7" UNDOCUMENTED
    248 => 0, -- "f8" UNDOCUMENTED
    249 => 0, -- "f9" UNDOCUMENTED
    250 => 0, -- "fa" UNDOCUMENTED
    251 => 0, -- "fb" UNDOCUMENTED
    252 => 0, -- "fc" UNDOCUMENTED
    253 => 0, -- "fd" UNDOCUMENTED
    255 => 0, -- "ff" UNDOCUMENTED
others=>0);
constant latences_FDCB:LATENCE_ARRAY :=(
    6 => 1, -- "06"
    14 => 1, -- "0e"
    22 => 1, -- "16"
    30 => 1, -- "1e"
    38 => 1, -- "26"
    46 => 1, -- "2e"
    62 => 1, -- "3e"
    70 => 1, -- "46"
    78 => 1, -- "4e"
    86 => 1, -- "56"
    94 => 1, -- "5e"
    102 => 1, -- "66"
    110 => 1, -- "6e"
    118 => 1, -- "76"
    126 => 1, -- "7e"
    134 => 1, -- "86"
    142 => 1, -- "8e"
    150 => 1, -- "96"
    158 => 1, -- "9e"
    166 => 1, -- "a6"
    174 => 1, -- "ae"
    182 => 1, -- "b6"
    190 => 1, -- "be"
    198 => 1, -- "c6"
    206 => 1, -- "ce"
    214 => 1, -- "d6"
    222 => 1, -- "de"
    230 => 1, -- "e6"
    238 => 1, -- "ee"
    246 => 1, -- "f6"
    254 => 1, -- "fe"
    0 => 0, -- "00" UNDOCUMENTED
    1 => 0, -- "01" UNDOCUMENTED
    2 => 0, -- "02" UNDOCUMENTED
    3 => 0, -- "03" UNDOCUMENTED
    4 => 0, -- "04" UNDOCUMENTED
    5 => 0, -- "05" UNDOCUMENTED
    7 => 0, -- "07" UNDOCUMENTED
    8 => 0, -- "08" UNDOCUMENTED
    9 => 0, -- "09" UNDOCUMENTED
    10 => 0, -- "0a" UNDOCUMENTED
    11 => 0, -- "0b" UNDOCUMENTED
    12 => 0, -- "0c" UNDOCUMENTED
    13 => 0, -- "0d" UNDOCUMENTED
    15 => 0, -- "0f" UNDOCUMENTED
    16 => 0, -- "10" UNDOCUMENTED
    17 => 0, -- "11" UNDOCUMENTED
    18 => 0, -- "12" UNDOCUMENTED
    19 => 0, -- "13" UNDOCUMENTED
    20 => 0, -- "14" UNDOCUMENTED
    21 => 0, -- "15" UNDOCUMENTED
    23 => 0, -- "17" UNDOCUMENTED
    24 => 0, -- "18" UNDOCUMENTED
    25 => 0, -- "19" UNDOCUMENTED
    26 => 0, -- "1a" UNDOCUMENTED
    27 => 0, -- "1b" UNDOCUMENTED
    28 => 0, -- "1c" UNDOCUMENTED
    29 => 0, -- "1d" UNDOCUMENTED
    31 => 0, -- "1f" UNDOCUMENTED
    32 => 0, -- "20" UNDOCUMENTED
    33 => 0, -- "21" UNDOCUMENTED
    34 => 0, -- "22" UNDOCUMENTED
    35 => 0, -- "23" UNDOCUMENTED
    36 => 0, -- "24" UNDOCUMENTED
    37 => 0, -- "25" UNDOCUMENTED
    39 => 0, -- "27" UNDOCUMENTED
    40 => 0, -- "28" UNDOCUMENTED
    41 => 0, -- "29" UNDOCUMENTED
    42 => 0, -- "2a" UNDOCUMENTED
    43 => 0, -- "2b" UNDOCUMENTED
    44 => 0, -- "2c" UNDOCUMENTED
    45 => 0, -- "2d" UNDOCUMENTED
    47 => 0, -- "2f" UNDOCUMENTED
    48 => 0, -- "30" UNDOCUMENTED
    49 => 0, -- "31" UNDOCUMENTED
    50 => 0, -- "32" UNDOCUMENTED
    51 => 0, -- "33" UNDOCUMENTED
    52 => 0, -- "34" UNDOCUMENTED
    53 => 0, -- "35" UNDOCUMENTED
    54 => 0, -- "36" UNDOCUMENTED
    55 => 0, -- "37" UNDOCUMENTED
    56 => 0, -- "38" UNDOCUMENTED
    57 => 0, -- "39" UNDOCUMENTED
    58 => 0, -- "3a" UNDOCUMENTED
    59 => 0, -- "3b" UNDOCUMENTED
    60 => 0, -- "3c" UNDOCUMENTED
    61 => 0, -- "3d" UNDOCUMENTED
    63 => 0, -- "3f" UNDOCUMENTED
    64 => 0, -- "40" UNDOCUMENTED
    65 => 0, -- "41" UNDOCUMENTED
    66 => 0, -- "42" UNDOCUMENTED
    67 => 0, -- "43" UNDOCUMENTED
    68 => 0, -- "44" UNDOCUMENTED
    69 => 0, -- "45" UNDOCUMENTED
    71 => 0, -- "47" UNDOCUMENTED
    72 => 0, -- "48" UNDOCUMENTED
    73 => 0, -- "49" UNDOCUMENTED
    74 => 0, -- "4a" UNDOCUMENTED
    75 => 0, -- "4b" UNDOCUMENTED
    76 => 0, -- "4c" UNDOCUMENTED
    77 => 0, -- "4d" UNDOCUMENTED
    79 => 0, -- "4f" UNDOCUMENTED
    80 => 0, -- "50" UNDOCUMENTED
    81 => 0, -- "51" UNDOCUMENTED
    82 => 0, -- "52" UNDOCUMENTED
    83 => 0, -- "53" UNDOCUMENTED
    84 => 0, -- "54" UNDOCUMENTED
    85 => 0, -- "55" UNDOCUMENTED
    87 => 0, -- "57" UNDOCUMENTED
    88 => 0, -- "58" UNDOCUMENTED
    89 => 0, -- "59" UNDOCUMENTED
    90 => 0, -- "5a" UNDOCUMENTED
    91 => 0, -- "5b" UNDOCUMENTED
    92 => 0, -- "5c" UNDOCUMENTED
    93 => 0, -- "5d" UNDOCUMENTED
    95 => 0, -- "5f" UNDOCUMENTED
    96 => 0, -- "60" UNDOCUMENTED
    97 => 0, -- "61" UNDOCUMENTED
    98 => 0, -- "62" UNDOCUMENTED
    99 => 0, -- "63" UNDOCUMENTED
    100 => 0, -- "64" UNDOCUMENTED
    101 => 0, -- "65" UNDOCUMENTED
    103 => 0, -- "67" UNDOCUMENTED
    104 => 0, -- "68" UNDOCUMENTED
    105 => 0, -- "69" UNDOCUMENTED
    106 => 0, -- "6a" UNDOCUMENTED
    107 => 0, -- "6b" UNDOCUMENTED
    108 => 0, -- "6c" UNDOCUMENTED
    109 => 0, -- "6d" UNDOCUMENTED
    111 => 0, -- "6f" UNDOCUMENTED
    112 => 0, -- "70" UNDOCUMENTED
    113 => 0, -- "71" UNDOCUMENTED
    114 => 0, -- "72" UNDOCUMENTED
    115 => 0, -- "73" UNDOCUMENTED
    116 => 0, -- "74" UNDOCUMENTED
    117 => 0, -- "75" UNDOCUMENTED
    119 => 0, -- "77" UNDOCUMENTED
    120 => 0, -- "78" UNDOCUMENTED
    121 => 0, -- "79" UNDOCUMENTED
    122 => 0, -- "7a" UNDOCUMENTED
    123 => 0, -- "7b" UNDOCUMENTED
    124 => 0, -- "7c" UNDOCUMENTED
    125 => 0, -- "7d" UNDOCUMENTED
    127 => 0, -- "7f" UNDOCUMENTED
    128 => 0, -- "80" UNDOCUMENTED
    129 => 0, -- "81" UNDOCUMENTED
    130 => 0, -- "82" UNDOCUMENTED
    131 => 0, -- "83" UNDOCUMENTED
    132 => 0, -- "84" UNDOCUMENTED
    133 => 0, -- "85" UNDOCUMENTED
    135 => 0, -- "87" UNDOCUMENTED
    136 => 0, -- "88" UNDOCUMENTED
    137 => 0, -- "89" UNDOCUMENTED
    138 => 0, -- "8a" UNDOCUMENTED
    139 => 0, -- "8b" UNDOCUMENTED
    140 => 0, -- "8c" UNDOCUMENTED
    141 => 0, -- "8d" UNDOCUMENTED
    143 => 0, -- "8f" UNDOCUMENTED
    144 => 0, -- "90" UNDOCUMENTED
    145 => 0, -- "91" UNDOCUMENTED
    146 => 0, -- "92" UNDOCUMENTED
    147 => 0, -- "93" UNDOCUMENTED
    148 => 0, -- "94" UNDOCUMENTED
    149 => 0, -- "95" UNDOCUMENTED
    151 => 0, -- "97" UNDOCUMENTED
    152 => 0, -- "98" UNDOCUMENTED
    153 => 0, -- "99" UNDOCUMENTED
    154 => 0, -- "9a" UNDOCUMENTED
    155 => 0, -- "9b" UNDOCUMENTED
    156 => 0, -- "9c" UNDOCUMENTED
    157 => 0, -- "9d" UNDOCUMENTED
    159 => 0, -- "9f" UNDOCUMENTED
    160 => 0, -- "a0" UNDOCUMENTED
    161 => 0, -- "a1" UNDOCUMENTED
    162 => 0, -- "a2" UNDOCUMENTED
    163 => 0, -- "a3" UNDOCUMENTED
    164 => 0, -- "a4" UNDOCUMENTED
    165 => 0, -- "a5" UNDOCUMENTED
    167 => 0, -- "a7" UNDOCUMENTED
    168 => 0, -- "a8" UNDOCUMENTED
    169 => 0, -- "a9" UNDOCUMENTED
    170 => 0, -- "aa" UNDOCUMENTED
    171 => 0, -- "ab" UNDOCUMENTED
    172 => 0, -- "ac" UNDOCUMENTED
    173 => 0, -- "ad" UNDOCUMENTED
    175 => 0, -- "af" UNDOCUMENTED
    176 => 0, -- "b0" UNDOCUMENTED
    177 => 0, -- "b1" UNDOCUMENTED
    178 => 0, -- "b2" UNDOCUMENTED
    179 => 0, -- "b3" UNDOCUMENTED
    180 => 0, -- "b4" UNDOCUMENTED
    181 => 0, -- "b5" UNDOCUMENTED
    183 => 0, -- "b7" UNDOCUMENTED
    184 => 0, -- "b8" UNDOCUMENTED
    185 => 0, -- "b9" UNDOCUMENTED
    186 => 0, -- "ba" UNDOCUMENTED
    187 => 0, -- "bb" UNDOCUMENTED
    188 => 0, -- "bc" UNDOCUMENTED
    189 => 0, -- "bd" UNDOCUMENTED
    191 => 0, -- "bf" UNDOCUMENTED
    192 => 0, -- "c0" UNDOCUMENTED
    193 => 0, -- "c1" UNDOCUMENTED
    194 => 0, -- "c2" UNDOCUMENTED
    195 => 0, -- "c3" UNDOCUMENTED
    196 => 0, -- "c4" UNDOCUMENTED
    197 => 0, -- "c5" UNDOCUMENTED
    199 => 0, -- "c7" UNDOCUMENTED
    200 => 0, -- "c8" UNDOCUMENTED
    201 => 0, -- "c9" UNDOCUMENTED
    202 => 0, -- "ca" UNDOCUMENTED
    203 => 0, -- "cb" UNDOCUMENTED
    204 => 0, -- "cc" UNDOCUMENTED
    205 => 0, -- "cd" UNDOCUMENTED
    207 => 0, -- "cf" UNDOCUMENTED
    208 => 0, -- "d0" UNDOCUMENTED
    209 => 0, -- "d1" UNDOCUMENTED
    210 => 0, -- "d2" UNDOCUMENTED
    211 => 0, -- "d3" UNDOCUMENTED
    212 => 0, -- "d4" UNDOCUMENTED
    213 => 0, -- "d5" UNDOCUMENTED
    215 => 0, -- "d7" UNDOCUMENTED
    216 => 0, -- "d8" UNDOCUMENTED
    217 => 0, -- "d9" UNDOCUMENTED
    218 => 0, -- "da" UNDOCUMENTED
    219 => 0, -- "db" UNDOCUMENTED
    220 => 0, -- "dc" UNDOCUMENTED
    221 => 0, -- "dd" UNDOCUMENTED
    223 => 0, -- "df" UNDOCUMENTED
    224 => 0, -- "e0" UNDOCUMENTED
    225 => 0, -- "e1" UNDOCUMENTED
    226 => 0, -- "e2" UNDOCUMENTED
    227 => 0, -- "e3" UNDOCUMENTED
    228 => 0, -- "e4" UNDOCUMENTED
    229 => 0, -- "e5" UNDOCUMENTED
    231 => 0, -- "e7" UNDOCUMENTED
    232 => 0, -- "e8" UNDOCUMENTED
    233 => 0, -- "e9" UNDOCUMENTED
    234 => 0, -- "ea" UNDOCUMENTED
    235 => 0, -- "eb" UNDOCUMENTED
    236 => 0, -- "ec" UNDOCUMENTED
    237 => 0, -- "ed" UNDOCUMENTED
    239 => 0, -- "ef" UNDOCUMENTED
    240 => 0, -- "f0" UNDOCUMENTED
    241 => 0, -- "f1" UNDOCUMENTED
    242 => 0, -- "f2" UNDOCUMENTED
    243 => 0, -- "f3" UNDOCUMENTED
    244 => 0, -- "f4" UNDOCUMENTED
    245 => 0, -- "f5" UNDOCUMENTED
    247 => 0, -- "f7" UNDOCUMENTED
    248 => 0, -- "f8" UNDOCUMENTED
    249 => 0, -- "f9" UNDOCUMENTED
    250 => 0, -- "fa" UNDOCUMENTED
    251 => 0, -- "fb" UNDOCUMENTED
    252 => 0, -- "fc" UNDOCUMENTED
    253 => 0, -- "fd" UNDOCUMENTED
    255 => 0, -- "ff" UNDOCUMENTED
others=>0);
	
	signal WAIT_n_0: std_logic:='1';
	signal WAIT_n_0_ack: boolean:=false;
	--signal WAIT_n_0_ackM1: std_logic:='1';
	--signal WAIT_n_D: std_logic:='0';
	signal WAIT_n_D: integer range 0 to 2:=0;
	signal WAIT_n_1: std_logic:='1';
	
	signal prefix_CB:boolean:=false;
	signal prefix_ED:boolean:=false;
	signal prefix_DD_FD:boolean:=false;
	signal prefix_DD_FD_CB:boolean:=false;
	
begin

	IO_ACK  <= not M1_n and not IORQ_n;
	IO_REQ_R<= not RD_n and not IORQ_n;
	IO_REQ_W<= not WR_n and not IORQ_n;
	MEM_RD  <= not RD_n and not MREQ_n;

	process(reset,nCLK4_1) is
	begin
		if reset='1' then
			MODE_select<="00";
		elsif rising_edge(nCLK4_1) then
			if IO_REQ_W='1' and A15_A14_A9_A8(3 downto 2) = "01" and D(7 downto 6) ="10" then --7Fxx gate array --
				--http://www.cpctech.org.uk/docs/garray.html
				if D(1 downto 0)="11" then
					MODE_select<="00";
				else
					MODE_select<=D(1 downto 0);
				end if;
			end if;
		end if;	
	end process;


WAIT_n_D <= latences_CB(conv_integer(R2D2)) when prefix_CB
				else latences_ED(conv_integer(R2D2)) when prefix_ED
				else latences_DD(conv_integer(R2D2)) when prefix_DD_FD
				else latences_DDCB(conv_integer(R2D2)) when prefix_DD_FD_CB
				else latences(conv_integer(R2D2));
				
-- au début la valeur est fausse, puis à un moment elle devient vrai, puis enfin elle est traitée (c'est-y pas une formule de warrior ça ?)
--WAIT_n_0 <= not(WAIT_n_D) when M1_n='0' and MEM_RD='1' else '1';
WAIT_n_0 <= '0' when M1_n='0' and MEM_RD='1' and WAIT_n_D>0 else '1';

WAIT_n<=WAIT_n_0 and WAIT_n_1 when not(WAIT_n_0_ack) else WAIT_n_1;

	process(reset,nCLK4_1) is
	variable compteur1MHz:integer range 0 to 3:=2;
		variable was_M1:boolean:=false;
		variable was_m:boolean:=false;
		variable waiting:boolean:=false;
		variable waiting_LATENCE:boolean:=false;
		--variable waiting_R2D2:std_logic:='0';
		variable was_MEMRD:boolean:=false;
		variable sizeM1:integer range 0 to 5:=0;
		variable conflit_WAIT:boolean:=false;
		--variable pang_WAIT:boolean:=false;
		variable pang_WAIT:integer range 0 to 2:=0;



		variable prefix_CB_mem:boolean:=false;
		variable prefix_ED_mem:boolean:=false;
		variable prefix_DD_FD_mem:boolean:=false;
		variable prefix_DD_FD_CB_mem:boolean:=false;
			
	begin
		if reset='1' then
			WAIT_n_1<='1';
			WAIT_n_0_ack<=false;
			waiting:=false;
			waiting_LATENCE:=false;
			conflit_WAIT:=false;
			--pang_WAIT:=false;
			pang_WAIT:=0;
			--was_MEMWR:=false;
			was_M1:=false;
		elsif rising_edge(nCLK4_1) then
			compteur1MHz:=(compteur1MHz+1) mod 4;
	
			if WAIT_n_1='0' and WAIT_n_0='0' and not(WAIT_n_0_ack) then
				-- conflit : WAIT_n_0 n'a servit à rien.
				conflit_WAIT:=true;
			end if;
	
			--if (M1_n='0' or was_M1) and MEM_RD='0' and was_MEMRD and R2D2=x"2A" then
			--if not(was_2A) and R2D2=x"2A" then
			--if (M1_n='0' or was_M1) and MEM_RD='1' and not(was_MEMRD) and R2D2=x"2A" then
			if M1_n='0' and MEM_RD='1' and not(was_MEMRD) then
				--if WAIT_n_D = '1' and ga_shunt='1' then
				if WAIT_n_D > 0 and ga_shunt='1' then
					--pang_WAIT:=true;
					pang_WAIT:=WAIT_n_D;
				end if;
				WAIT_n_0_ack<=true;
			end if;
			if MEM_RD='0' then
				WAIT_n_0_ack<=false;
			end if;
			
			--if waiting_R2D2='1' then -- and ga_shunt='1'
			--	waiting_R2D2:='0';
			--	WAIT_n_1<='0';
			--else
				if waiting then
					WAIT_n_1<='0';
				else
					WAIT_n_1<='1';
				end if;

				--compteur1MHz=0
				--Z80 CLK4MHz
				--GateArray nCLK4MHz (+0.5)
				-- \=>M1 Wait_n
				-- \=>i (+0.5)
				--   \=>crtc_VSYNC
				--   \=>SOUND_CLK
				
				-- si je met --compteur1MHz=3, j'ai HSYNC_width qui est bon dans le test CPCTEST de ArnoldEmu
				
				--z80_synchronise	
				if (M1_n='0') and not(was_M1) and compteur1MHz=M1_OFFSET then -- and IO_ACK='0'
					-- M - - - M - - - M - - -
					-- 0 1 2 3 0 1 2 3 0 1 2 3
					-- cool
					waiting:=false;
					WAIT_n_1<='1';
				elsif waiting and compteur1MHz=M1_OFFSET then
					waiting:=false;
					WAIT_n_1<='1';
				elsif waiting or waiting_LATENCE then
					-- quand on pose un wait, cet idiot il garde M1_n=0 le tour suivant
				elsif (M1_n='0') and not(was_M1) then -- and IO_ACK='0'
					-- M - - M - - - M - - -
					-- 0 1 2 3 0 1 2 3 0 1 2 3
					-- M - - M W - - - M - - -
					-- 0 1 2 3 0 1 2 3 0 1 2 3
					
					-- M - M - - - M - - -
					-- 0 1 2 3 0 1 2 3 0 1 2 3
					-- M - M W W - - - M - - -
					-- 0 1 2 3 0 1 2 3 0 1 2 3
				
					-- M - - - - M - - - M - - -
					-- 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3
					-- M - - - - M W W W - - - M - - -
					-- 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3
				
					-- pas cool
					WAIT_n_1<='0';
					waiting:=true;
				elsif compteur1MHz=M1_OFFSET and not(waiting) then
					-- Some instructions has more than 4 Tstate -- validated
				end if;
			--end if;
			
			if not(waiting) and conflit_WAIT then
				WAIT_n_1<='0'; -- 1st T replayed
				conflit_WAIT:=false;
			--elsif not(waiting) and pang_WAIT then
			elsif not(waiting) and pang_WAIT>0 then
				WAIT_n_1<='0'; -- 2nd T played
				--pang_WAIT:=false;
				pang_WAIT:=pang_WAIT-1;
			end if;
			if not(waiting) and pang_WAIT>0 then
				-- au prochain tour je continue d'inserer du WAIT !!!
				waiting_LATENCE:=true;
			else
				waiting_LATENCE:=false;
			end if;
			
			if M1_n='0' and MEM_RD='1' and not(was_MEMRD) then
				if ga_shunt='0' then
					prefix_CB_mem:=false;
					prefix_ED_mem:=false;
					prefix_DD_FD_mem:=false;
					prefix_DD_FD_CB_mem:=false;
				elsif R2D2=x"CB" and prefix_DD_FD_mem then
					-- DD CB or FD CB
					prefix_CB_mem:=false;
					prefix_ED_mem:=false;
					prefix_DD_FD_mem:=false;
					prefix_DD_FD_CB_mem:=true;
				elsif R2D2=x"CB" then
					prefix_CB_mem:=true;
					prefix_ED_mem:=false;
					prefix_DD_FD_mem:=false;
					prefix_DD_FD_CB_mem:=false;
				elsif R2D2=x"ED" then
					prefix_CB_mem:=false;
					prefix_ED_mem:=true;
					prefix_DD_FD_mem:=false;
					prefix_DD_FD_CB_mem:=false;
				elsif R2D2=x"DD" then
					prefix_CB_mem:=false;
					prefix_ED_mem:=false;
					prefix_DD_FD_mem:=true;
					prefix_DD_FD_CB_mem:=false;
				elsif R2D2=x"FD" then
					prefix_CB_mem:=false;
					prefix_ED_mem:=false;
					prefix_DD_FD_mem:=true;
					prefix_DD_FD_CB_mem:=false;
				else
					prefix_CB_mem:=false;
					prefix_ED_mem:=false;
					prefix_DD_FD_mem:=false;
					prefix_DD_FD_CB_mem:=false;
				end if;
			end if;
			
			prefix_CB<=prefix_CB_mem;
			prefix_ED<=prefix_ED_mem;
			prefix_DD_FD<=prefix_DD_FD_mem;
			prefix_DD_FD_CB<=prefix_DD_FD_CB_mem;

			
			if M1_n='0' then --and IO_ACK='0'
				was_M1:=true;
			else
				was_M1:=false;
			end if;
			
			if MEM_RD='1' then
				was_MEMRD:=true;
			else
				was_MEMRD:=false;
			end if;
		end if;
	end process;

ctrcConfig_process:process(reset,nCLK4_1) is
	variable reg_select32 : std_logic_vector(7 downto 0);
	variable reg_select : integer range 0 to 17;
	-- normally 0..17 but 0..31 in JavaCPC
	type registres_type is array(0 to 17) of std_logic_vector(7 downto 0);
	variable registres:registres_type := (others=>(others=>'0'));
	variable halfR0_mem:std_logic_vector(7 downto 0);
	variable ink:STD_LOGIC_VECTOR(3 downto 0);
	variable border_ink:STD_LOGIC;
	variable ink_color:STD_LOGIC_VECTOR(4 downto 0);
	
	variable pen_mem:pen_type:=(4,12,21,28,24,29,12,5,13,22,6,23,30,0,31,14);
	variable border_mem:integer range 0 to 31;
begin
	if reset='1' then
		Dout<=(others=>'1');
	elsif rising_edge(nCLK4_1) then
	
		if IO_REQ_W='1' and A15_A14_A9_A8(3) = '0' and A15_A14_A9_A8(2) = '1' then
			if D(7) ='0' then
				-- ink -- osef
				if D(6)='0' then
					border_ink:=D(4);
					ink:=D(3 downto 0);
				else
					ink_color:=D(4 downto 0);
					if border_ink='0' then
						pen_mem(conv_integer(ink)):=conv_integer(ink_color);
						pen<=pen_mem;
					else
						border_mem:=conv_integer(ink_color);
						border<=border_mem;
					end if;
				end if;
			end if;
		end if;
	
		if (IO_REQ_W or IO_REQ_R)='1' then -- EN port (enable)
			--On type 0 and 1, if a Write Only register is read from, "0" is returned. 
	--type 0		
--			b1 	b0 	Function 	Read/Write
--0 	0 	Select internal 6845 register 	Write Only
--0 	1 	Write to selected internal 6845 register 	Write Only
--1 	0 	- 	-
--1 	1 	Read from selected internal 6845 register 	Read only 

	--type 1
--b1 	b0 	Function 	Read/Write
--0 	0 	Select internal 6845 register 	Write Only
--0 	1 	Write to selected internal 6845 register 	Write Only
--1 	0 	Read Status Register 	Read Only
--1 	1 	Read from selected internal 6845 register 	Read only 
			Dout<=(others=>'1'); -- pull up (no command)
			if A15_A14_A9_A8(2)='0' and A15_A14_A9_A8(1)='0' then -- A9_WRITE
				if A15_A14_A9_A8(0)='0' then
					if IO_REQ_W='1' then
						-- DÃƒÆ’Ã‚Â©codage complet du numÃƒÆ’Ã‚Â©ro de registre sur le port &BFxx : Oui
						reg_select32:=D and x"1F";
						if reg_select32<=x"11" then -- < 17
							reg_select:=conv_integer(reg_select32);
						else
							reg_select:=17; -- out of range :p
						end if;
					else
						-- parasite : pull up
						reg_select32:=x"1F";
					end if;
				elsif reg_select32<=x"11" then
					if IO_REQ_W='1' then
						registres(reg_select):=D;
					else
						-- parasite : pull up
						registres(reg_select):=x"FF";
					end if;
					
					-- rien ici de pertinant...
					-- see arnoldemu's crtc.c file :
					-- CRTC0_UpdateState
					-- CRTC1_UpdateState
					-- CRTC2_UpdateState
					-- ASICCRTC_UpdateState
					-- JavaCPC Basic6845[CRTC].setRegister().setEvents()
					
					--HD6845S_WriteMaskTable idem que UM6845R_WriteMaskTable sauf pour R8 (skew)
					
					case reg_select is
						when 0=>
							RHtot<=registres(0);
							--hChars = reg[0] + 1;
							--halfR0 = hChars >> 1;
							halfR0_mem:=registres(0)+1;
							halfR0<="0" & halfR0_mem(7 downto 1);
						when 1=>
							RHdisp<=registres(1);
						when 2=>
							RHsyncpos<=registres(2);
						when 3=>
-- following DataSheet and Arnold emulator (Arnold says it exists a conversion table HSYNC crtc.c.GA_HSyncWidth)
							--hSyncWidth = value & 0x0f;
							RHwidth<=registres(3)(3 downto 0); -- DataSheet
							--RVwidth<=conv_std_logic_vector(NB_LINEH_BY_VSYNC,5);-- (24+1) using Arnold formula
-- Arnold formula ctrct.c.MONITOR_VSYNC_COUNT "01111";
-- Arkanoid does use width VSYNC while hurting a monster or firing with bonus gun
							-- RVwidth<=registres(3)(7 downto 4); -- JavaCPC 2015 puis freemac
							-- http://quasar.cpcscene.net/doku.php?id=coding:test_crtc#fn__24
							
							-- VSync width can only be changed on type 3 and 4 (???)
							-- The Vsync has a fixed length for CRTC 2, which is 16 scan lines (and not 8 as programmed by the firmware, implicitly using CRTC 0). 
							--http://cpctech.cpc-live.com/source/split.html
							if crtc_type='1' then
								--CRTC1 MC6845/MC6845R/UM6845R have a fixed Vertical Sync Width of 16 scanlines.
								--vSyncWidth = 0;
								RVwidth<=x"0"; --registres(3)(6 downto 4) & "0";
							else
								--CRTC0 HD6845S allows the Vertical Sync Width to be programmed
								--vSyncWidth = (value >> 4) & 0x0f;
								RVwidth<=registres(3)(7 downto 4);
							end if;
							
							--CRTC0 HD6845: Register 3: Sync Width Bit 7 Vertical Sync Width bit 3 Bit 6 Vertical Sync Width bit 2 Bit 5 Vertical Sync Width bit 1 Bit 4 Vertical Sync Width bit 0 Bit 3 Horizontal Sync Width bit 3 Bit 2 Horizontal Sync Width bit 2 Bit 1 Horizontal Sync Width bit 1 Bit 0 Horizontal Sync Width bit 0 
							--CRTC1 MC6845/UM6845: Note for UM6845: When the Horizontal Sync width is set to 0, then no Horizontal Syncs will be generated. (This feature can be used to distinguish between the UM6845 and MC6845).
							
							
							--CRTC0 Programming Horizontal Sync Width with 0: HD6845S: The data sheets says that the Horizontal Sync Width cannot be programmed with 0. The effect of doing this is not documented. MC6845: If the Horizontal Sync Width register is programmed with 0, no horizontal syncs are generated.
							
						when 4=>
							-- Validation des registres 9 et 4 aprÃƒÆ’Ã‚Â¨s reprogrammation (Pendant que C4 = 0, buffÃƒÆ’Ã‚Â©risÃƒÆ’Ã‚Â©s sinon)
							-- Rupture ligne-ÃƒÆ’Ã‚Â -ligne possible (R9 = R4 =0 ) >>oui<<
							RVtot<=registres(4) and x"7f";
						when 5=>
							RVtotAdjust<=registres(5) and x"1f";
						when 6=>
							--The DISPTMG (Activation du split-border) can be forced using R8 (DISPTMG Skew) on type 0,3 and 4 or by setting R6=0 on type 1.
							RVdisp<=registres(6) and x"7f";
						when 7=>
							RVsyncpos<=registres(7) and x"7f";
						when 8=>-- and x"f3"; and x"03" (type 1)
							-- interlace & skew
							-- arnoldemu's crtc.c
							-- Delay = (CRTCRegisters[8]>>4) & 0x03;
							-- CRTC_InternalState.HDelayReg8 = (unsigned char)Delay;
							--There are only two bits in R8:
							-- bit 0: interlace enable.
							-- bit 1: interlace type (when enabled)
							--Interlace and Skew 	xxxxxx00
							-- 00 : No interlace
							-- 01 : Interlace Sync Raster Scan Mode
							-- 10 : No Interlace
							-- 11 : Interlace Sync and Video Raster Scan Mode 
							
							-- CRTC0 HD6845S: Register 8: Interlace and Skew Bit 7 Cursor Display timing Skew Bit 1 Bit 6 Cursor Display timing Skew Bit 0 Bit 5 Display timing Skew Bit 1 (DTSKB1) Bit 4 Display timing SKew Bit 0 (DTSKB0) Bit 3 not used Bit 2 not used Bit 1 Video Mode Bit 0 Interlace Sync Mode Display timing skew: The data can be skewed by 0 characters, 1 character or 2 characters. When both bits are 1 the display is stopped and border is displayed. This is used in the BSC Megademo in the Crazy Cars II part. 
							-- CRTC1 MC6845/UM6845 : Bit 1 Video Mode Bit 0 Interlace Sync Mode
							
							-- Type 0,1a (and 4 ?) have an extra feature in R8, which seems to be the basis for the "register 8 border technique". These CRTCs use bits 4 and 5 of R8 for character delay: that is, to account for the fact, that in a typical low-cost system, the memory fetches (RAM and then font ROM) would be slow and would make the raster out of sync with "Display Enable" (DE, the frame, or border) which is wired directly to the color generator. 
							-- So they implemented a programmable DE delay (the "Skew") which is to be set a the duration of the raster fetch (counted in CRTC clock cycles, or mode 1 characters). The same thing is done for the "Cursor" line, because it is also shorter than the raster data-path. 
							--To implement this, you can by-pass or enable couple of registers on the concerned lines. Because these registers probably get reset when they're bypassed, if you reenable them while DE is true, it will take them as many characters as the DE delay, before they echo "true": you get a bit of border color in the middle of the screen ! 
							--Of course, when the delay is elapsed, the raster comes back, but you could repeatedly turn the delay on and off. 
							--interlace = (value & 0x01) != 0;
							interlace<=registres(8)(0);
							--interlaceVideo = (value & 0x03) == 3 ? 1 : 0;
							interlaceVideo<=registres(8)(1);
							--scanAdd = interlaceVideo + 1;
							if registres(8)(1) = '0' then
								scanAdd<=x"01";
							else
								scanAdd<=x"02";
							end if;
							--maxRaster = reg[9] | interlaceVideo;
							RRmax<=(registres(9) and x"1f") or "0000000" & registres(8)(1);
							--CRTC3 hDispDelay = ((reg[8] >> 4) & 0x04);
							Skew<=registres(8)(5 downto 4);
							
							
						when 9=> -- max raster adress
							-- Validation des registres 9 et 4 aprÃƒÆ’Ã‚Â¨s reprogrammation (Pendant que C4 = 0, buffÃƒÆ’Ã‚Â©risÃƒÆ’Ã‚Â©s sinon)
							--maxRaster = value | interlaceVideo;
							RRmax<=(registres(9) and x"1f") or "0000000" & interlaceVideo;
						when 10=>NULL; -- and x"7f";
							-- cursor start raster 
						when 11=>NULL; -- and x"1f";
							-- cursor end raster
						when 12=>
							--Validation de l'offset aprÃƒÆ’Ã‚Â¨s reprogrammation des registres 12 et 13 : >>ImmÃƒÆ’Ã‚Â©diatement<< (Pendant que C4 = 0, ÃƒÆ’Ã‚Â  l'ÃƒÆ’Ã‚Â©cran suivant sinon)
							
						   --NULL;  (read/write type 0) (write only type 1)
							-- start adress H
							--maRegister = (reg[13] + (reg[12] << 8)) & 0x3fff;
							-- and x"3f" donc (5 downto 0)
							ADRESSE_maRegister<=registres(12)(5 downto 0) & registres(13);
						when 13=> --NULL;  (read/write type 0) (write only type 1)
							-- start adress L
							--maRegister = (reg[13] + (reg[12] << 8)) & 0x3fff;
							ADRESSE_maRegister<=registres(12)(5 downto 0) & registres(13);
						when 14=>NULL; -- and x"3f"
							-- cursor H (read/write)
						when 15=>NULL;
							-- cursor L (read/write)
						when 16=>NULL;
							--light pen H (read only)
						when 17=>NULL;
							--light pen L (read only)
					end case;
				end if;
			elsif A15_A14_A9_A8(2)='0' and A15_A14_A9_A8(1)='1' then-- A9_READ
				-- type 0 : status is not implemented
				if A15_A14_A9_A8(0)='0' then
					-- STATUS REGISTER (CRTC 1 only)
					-- U (bit 7) : Update Ready
					-- L (bit 6) : LPEN Reegister Full
					-- V (bit 5) : Vertical Blanking (VDISP ?)
					-- in type 3 & 4, status_reg=reg
					
					-- Bit 6 LPEN REGISTER FULL 1: A light pen strobe has occured (light pen has put to screen and button has been pressed), 0: R16 or R17 has been read by the CPU 
					-- Bit 5	VERTICAL BLANKING 1: CRTC is scanning in the vertical blanking time, 0: CRTC is not scanning in the vertical blanking time.
					--Vertical BLanking (VBL)
					--This is a time interval during a video-frame required by the electron gun in a CRT monitor to move back up to the top of the tube. While the vertical blank, the electron beam is off, hence no data is displayed on the screen.
					--As soon as the electron gun is back to the top, the monitor will hold it there until a VSync appears to indicate the start of a new frame. If no VSync appears, the monitor will release the gun by itself after some time (depending on it's VHold) and will usually produce a rolling/jumping image because the monitor vertical synchronisation is no longer done with the CPC video-frame but with the monitor hardware limits (and they won't be the same).
					--The VBL is a monitor specific time interval, it can not be software controlled (on the Amstrad), unlike the VSync, which is a signal produced by the CRTC we can control. The monitor expect a VSync at regular interval to produce a stable image.
					
					--Bit 5, VERTB, causes an interrupt at line 0 (start of vertical blank) of
					--the video display frame. The system is often required to perform many
					--different tasks during the vertical blanking interval. Among these tasks
					--are the updating of various pointer registers, rewriting lists of Copper
					--tasks when necessary, and other system-control operations.
					
					--Registre de status accessible sur le port &BExx (VBL, border)
					
					-- Le bit 7 du registre 3 change la durÃƒÆ’Ã‚Â©e de la VBL >>NON<<(valeur : toujours double)
					-- CRTC 3 et 4 : lecture de la derniÃƒÆ’Ã‚Â¨re ligne de VBL sur le registre 10
					--if (LineCounter == 0) {
					--  return (1 << 5); x"20"
					if crtc_type='0' then
						Dout<=x"FF";
					elsif LineCounter_is0 then
						--if (LineCounter == 0) {
						--Bit 5 is set to 1 when CRTC is in "vertical blanking". Vertical blanking is when the vertical border is active. i.e. VCC>=R6.
						--It is cleared when the frame is started (VCC=0). It is not directly related to the DISPTMG output (used by the CPC to display the border colour) because that output is a combination of horizontal and vertical blanking. This bit will be 0 when pixels are being displayed.
						Dout<=x"20";
					else
						Dout<=x"00"; 
					end if;
				else
					-- type 0 : nothing (return x"00")
					-- type 1 : read status
					if reg_select32 = x"0A" then -- R10
						Dout<=registres(10) and x"7f"; -- applying the write mask here
					elsif reg_select32 = x"0B" then -- R11
						Dout<=registres(11) and x"1f"; -- applying the write mask here
					elsif reg_select32 = x"0C" then -- R12
						if crtc_type='0' then
							--CRTC0 HD6845S/MC6845: Start Address Registers (R12 and R13) can be read.
							Dout<=registres(12) and x"3f";  -- applying the write mask here
						else
							-- Lecture des registres 12 and 13 sur le port &BFxx : >>non<<
							--CRTC1 UM6845R: Start Address Registers cannot be read.
							Dout<=x"00"; -- type 1
						end if;
						
					elsif reg_select32 = x"0D" then -- R13
						if crtc_type='0' then
							Dout<=registres(13); -- type 0
							--CRTC0 HD6845S/MC6845: Start Address Registers (R12 and R13) can be read.
						else
							--CRTC1 UM6845R: Start Address Registers cannot be read.
							-- Lecture des registres 12 and 13 sur le port &BFxx : >>non<<
							Dout<=x"00"; -- type 1 & 2
						end if;
					elsif reg_select32 = x"0E" then -- R14
						--if crtc_type='0' then
						Dout<=registres(14) and x"3f"; -- applying the write mask here
						--else
						--	Dout<=registres(14);
						--end if;
					elsif reg_select32 = x"0F" then -- R15	
						Dout<=registres(15);-- all types
					elsif reg_select32 = x"10" then -- R16
						--	Light Pen Address (read only, don't dependant on write !!!) - "Emulator Sucks"
						Dout<=x"00"; --registres(16) and x"3f";-- all types
					elsif reg_select32 = x"11" then -- R17
						--	Light Pen Address (read only, don't dependant on write !!!) - "Emulator Sucks"
						Dout<=x"00"; --registres(17);-- all types
					elsif reg_select32 = x"FF" then
						if crtc_type='0' then
							-- registers 18-30 read as 0 on type1, register 31 reads as 0x0ff.
							Dout<=x"FF";
						else
							Dout<=x"00";
						end if;
					else
						-- 1. On type 0 and 1, if a Write Only register is read from, "0" is returned.
						-- registers 18-31 read as 0, on type 0 and 2.
						-- registers 18-30 read as 0 on type1
						Dout<=x"00";
					end if;
				end if;
			else
				--JavaCPC readPort() not implemented
				-- CS (chip select) OFF
				-- no read : pull-up
				Dout<=x"FF";
			end if;
--		elsif IO_ACK='1' then
--			-- IO_ACK DATA_BUS
--			Dout<=(others=>'1'); -- value to check... cpcwiki seem down at the moment I write this sentence :P
		else
			Dout<=(others=>'1');
		end if;
	end if;
end process ctrcConfig_process;

	-- DANGEROUS WARNING : CRTC PART WAS TESTED AND VALIDATED USING TESTBENCH
simple_GateArray_process : process(reset,nCLK4_1) is
 
 variable compteur1MHz : integer range 0 to 3:=0;
	variable dispV:std_logic:='0';
	variable disp_delta:std_logic:='0';
	variable dispH:std_logic:='0'; -- horizontal disp (easier to compute BORDER area)
	variable dispH_skew0:std_logic:='0';
	variable dispH_skew1:std_logic:='0';
	variable dispH_skew2:std_logic:='0';
	variable disp_VRAM:std_logic:='0';
	-- following Quazar legends, 300 times per second
	-- Following a lost trace in Google about www.cepece.info/amstrad/docs/garray.html I have
	-- "In the CPC the Gate Array generates maskable interrupts, to do this it uses the HSYNC and VSYNC signals from CRTC, a 6-bit internal counter and monitors..."
-- perhaps useful also : http://www.cpcwiki.eu/index.php/Synchronising_with_the_CRTC_and_display 
		-- following http://cpcrulez.fr/coding_amslive04-z80.htm
		-- protected int hCCMask = 0x7f; "char_counter256 HMAX n'est pas une valeur en dur, mais un label comme VT et VS..."
		variable hCC : std_logic_vector(7 downto 0):=(others=>'0'); --640/16
		variable LineCounter : std_logic_vector(7 downto 0):=(others=>'0'); --600
		variable etat_hsync : STD_LOGIC:=DO_NOTHING;
		variable etat_monitor_hsync : STD_LOGIC_VECTOR(3 downto 0):=(others=>DO_NOTHING);
		variable etat_vsync : STD_LOGIC:=DO_NOTHING;
		variable etat_monitor_vsync : STD_LOGIC_VECTOR(3 downto 0):=(others=>DO_NOTHING);
		variable etat_monitor_vhsync : STD_LOGIC_VECTOR(3 downto 0):=(others=>DO_NOTHING);
		--idem ADRESSE_MAcurrent_mem variable MA:STD_LOGIC_VECTOR(13 downto 0):=(others=>'0');
		variable RasterCounter:STD_LOGIC_VECTOR(7 downto 0):=(others=>'0'); -- buggy boy has value RRmax=5
		variable frame_oddEven:std_logic:='0';
		variable ADRESSE_maStore_mem:STD_LOGIC_VECTOR(13 downto 0):=(others=>'0');
		variable ADRESSE_MAcurrent_mem:STD_LOGIC_VECTOR(13 downto 0):=(others=>'0');
		variable crtc_A_mem:std_logic_vector(14 downto 0):=(others=>'0'); -- 16bit memory
		variable bvram_A_mem:std_logic_vector(13 downto 0):=(others=>'0'); -- 16bit memory
		variable bvram_A_mem_delta:std_logic_vector(13 downto 0):=(others=>'0'); -- 16bit memory

		
		--(128*1024)/64 2*1024=2^11
		variable zap_scan:boolean:=true; -- if in last round, has no blank signal, do not scan memory !

		variable vram_vertical_offset_counter:integer:=0;
		variable vram_vertical_counter:integer:=0;
		variable in_V:boolean:=false;
		variable vram_horizontal_offset_counter:integer:=0;
		variable vram_horizontal_counter:integer:=0;
		variable is_H_middle:boolean:=false;
		
		variable palette_A_tictac_mem:std_logic_vector(13 downto 0):=(others=>'0');
		variable palette_D_tictac_mem:std_logic_vector(7 downto 0):=(others=>'0');
		variable border_begin_mem:std_logic_vector(7 downto 0):=(others=>'0');
		variable disp_begin_mem:std_logic:='0';
		variable RHdisp_mem:std_logic_vector(7 downto 0):="00101000";
		
		variable last_dispH:std_logic:='0';
		variable palette_horizontal_counter:integer range 0 to 256-1:=0; --640/16
		variable palette_color:integer range 0 to 16-1;
		
		variable RVtotAdjust_mem:std_logic_vector(7 downto 0):=(others=>'0');
		variable RVtotAdjust_do:boolean:=false;
		
		variable hSyncCount:std_logic_vector(3 downto 0):=(others=>'0');
		variable vSyncCount:std_logic_vector(3 downto 0):=(others=>'0');
		
		variable DATA_mem:std_logic_vector(7 downto 0);
	begin
		if reset='1' then
			vsync_int<=DO_NOTHING;
			hsync_int<=DO_NOTHING;
			vsync_azrael<=DO_NOTHING;
			hsync_azrael<=DO_NOTHING;
			
--			InterruptLineCount:=(others=>'0');
--			InterruptSyncCount:=2;
--			int<='0';
			crtc_VSYNC<=DO_NOTHING;
			
			etat_hsync:=DO_NOTHING;
			etat_monitor_hsync:=(others=>DO_NOTHING);
			etat_vsync:=DO_NOTHING;
			etat_monitor_vsync:=(others=>DO_NOTHING);
			etat_monitor_vhsync:=(others=>DO_NOTHING);
			
			ADRESSE_maStore_mem:=(others=>'0');
			ADRESSE_MAcurrent_mem:=(others=>'0');
			LineCounter:=x"00";
			RasterCounter:=x"00";
			hCC:=x"00";
			
			--bvram
			crtc_R<='0';
			bvram_D<=(others=>'0');
			bvram_W<='0';
	--it's Z80 time !
		elsif rising_edge(nCLK4_1) then
		
		compteur1MHz:=(compteur1MHz+1) mod 4;
		
		if compteur1MHz=SOUND_OFFSET then
			SOUND_CLK<='0';
		else 
			-- it's a falling_edge Yamaha
			SOUND_CLK<='1';
		end if;
		

		
--crtc_DISP<='0';
palette_W<='0';
--bvram
crtc_R<='0'; -- directly solve external ram_A for CRTC read
bvram_W<='0';

-- Crazy Car II doesn't like little_reset
			-- Asphalt IACK without test in int_mem
			-- counter never upper than  52
			-- z80 mode 1 : the byte need no be sent, as the z80 restarts at logical address x38 regardless(z80 datasheet)
			case compteur1MHz is
			when 0=>
				--setEvents() HSync strange behaviour : part 1
				etat_monitor_hsync:=etat_monitor_hsync(2 downto 0) & etat_monitor_hsync(0);

				--checkHSync(false); -- and RHwidth/=x"0" FIXME
				-- BAD : MC6845/UM6845: Note for UM6845: When the Horizontal Sync width is set to 0, then no Horizontal Syncs will be generated. (This feature can be used to distinguish between the UM6845 and MC6845).
				-- http://cpctech.cpc-live.com/docs/hd6845s/hd6845sp.htm 0=>16
				-- http://cpctech.cpc-live.com/docs/um6845r/um6845r.htm 0=>???
				-- http://cpctech.cpc-live.com/docs/mc6845/mc6845.htm 0=>ignore
				if ((frame_oddEven='1' and hCC = halfR0)
				or (frame_oddEven='0' and hCC=RHsyncpos)) and (CRTC_TYPE='1' or RHwidth/=x"0") then -- and etat_hsync=DO_NOTHING
					--hSyncCount = 0;
					hSyncCount:= x"0";
					--if (hDisp && CRTCType == 1 && hSyncWidth == (reg[3] & 0x0f)) {
					--if dispH_skew0='1' and crtc_type='1' then
					--	--vDisp = reg[6] != 0;
					--	if RVDisp=0 then
					--		dispV:='0';
					--	else
					--		dispV:='1';
					--	end if;
					--	hSyncCount:= x"1"; -- Prehistoric live barre, at right, if x"0" : a pixel glinch.
					--end if;
					--inHSync = true;
					etat_hsync:=DO_HSYNC;
					--listener.hSyncStart();
					etat_monitor_hsync(0):=DO_HSYNC;
--hsync_int<=DO_HSYNC; -- following javacpc,grimware and arnold
				-- if (inHSync) {
				elsif etat_hsync=DO_HSYNC then
					--hSyncCount = (hSyncCount + 1) & 0x0f;
					hSyncCount:=hSyncCount+1;
					--if (hSyncCount == hSyncWidth) {
					if	hSyncCount=RHwidth then
						--inHSync = false;
						etat_hsync:=DO_NOTHING;
						--listener.hSyncEnd();
						--etat_monitor_hsync(0):=DO_NOTHING;
						etat_monitor_hsync:="0000";
--hsync_int<=DO_NOTHING;
					else
						if hSyncCount=1+4 then
							etat_monitor_hsync:="0000";
						end if;
					end if;
				end if;
				
				--http://www.phenixinformatique.com/modules/newbb/viewtopic.php?topic_id=4316&forum=9
				--In original CRTC DataSheet, it doesn't have any test about VSync period, and also, bits 4 to 7 of R3 are not taken into account. Some factories shall have reused this free bits to put on it its own features, feel more about somes linked to VSync (like interlaced R8, adding difference between a certain model of CRTC and another).
				--PPI read CRTC.isVSYnc bool
				--if (inVSync && (vSyncCount = (vSyncCount + 1) & 0x0f) == vSyncWidth) {
				if hCC = 0 then
					etat_monitor_vsync:=etat_monitor_vsync(2 downto 0) & etat_monitor_vsync(0);
					-- checkVSync()
					--if RasterCounter=0 and LineCounter=RVsyncpos then -- crtc 3 -- crtc 0 et 1 pour JavaCPC
					-- on CRTC type 0 and 1, Vsync can be triggered on any line of the char. -- WakeUp! demo fail in scrolling down the girl
					--if (LineCounter == reg[7] && !inVSync) {
					--if RasterCounter=0 and etat_vsync=DO_NOTHING and LineCounter=RVsyncpos then -- crtc 0 et 1 -- WakeUp! slow down
					--if RasterCounter=0 and LineCounter=RVsyncpos then
					--on CRTC type 0 and 1, Vsync can be triggered on any line of the char.
					--if LineCounter=RVsyncpos and etat_vsync=DO_NOTHING then -- (too clever for a CRTC, isn't it ? "do offset if problems")
					--checkVSync();
					--if (LineCounter == reg[7] && !inVSync) { -- (too clever for a CRTC, isn't it ? "do offset if problems")
					--WakeUp!
					if RasterCounter=0 and LineCounter=RVsyncpos then -- and etat_vsync=DO_NOTHING then
					--if LineCounter=RVsyncpos then
						--checkVSync(true); (idem newFrame() ?)
						--Batman logo rotating still like this... but dislike the !inVSync filter (etat_vsync=DO_NOTHING) here...
						-- Batman city towers does like RasterCounter=0 filter here...
						-- CRTC datasheet : if 0000 is programmed for VSync, then 16 raster period is generated.
						vSyncCount:= x"0"; -- pulse ?
						etat_vsync:=DO_VSYNC;
						etat_monitor_vsync(0):=DO_VSYNC;
--crtc_VSYNC<=DO_VSYNC; -- it is really '1' by here, because we need an interrupt while vsync=1 or else border is to too faster (border 1,2)
--vsync_int<=DO_VSYNC; -- do start a counter permitting 2 hsync failing before interrupt
					elsif etat_vsync=DO_VSYNC then -- and not(RVtotAdjust_do) then
						vSyncCount:=vSyncCount+1;
						if vSyncCount=RVwidth then -- following Grim (forum)
							etat_vsync:=DO_NOTHING;
							etat_monitor_vsync:="0000";
--crtc_VSYNC<=DO_NOTHING;
--vsync_int<=DO_NOTHING; -- useless, except to addition several vsync layering them each others
						else
							if vSyncCount=2+2 then
								etat_monitor_vsync:="0000";
							end if;
						end if;
					end if;
				end if;
				etat_monitor_vhsync:=etat_monitor_vhsync(2 downto 0) & etat_monitor_vsync(2);
				
				--setEvents() HSync strange behaviour : part 2
				if zap_scan then
					dispH_skew0:='0';
				elsif hCC = 0 then -- and LineCounter<RVDisp*(RRmax+1) then
					dispH_skew0:='1';
					--hDispStart() (redondance avec hCC=RHtot (hCC:=0) !) : donc ne rien faire ici...
				elsif (crtc_type='1' and hCC = RHdisp) or (crtc_type='0' and hCC=RHdisp+Skew) then
					dispH_skew0:='0';
					
						--if ((getRA() | interlaceVideo) == maxRaster) {
						if (RasterCounter or "0000000" & interlaceVideo)=RRMax then
							if crtc_type='1' then
								--maStore = (maStore + reg[1]) & 0x3fff;
								--0x3fff est ok : ADRESSE_maStore_mem(13:0)
								ADRESSE_maStore_mem:=ADRESSE_maStore_mem+RHDisp;
							else
								--if (CRTC_InternalState.HCount == CRTC_InternalState.HEnd) -- c'est HDisp ce HEnd en fait...
								--CRTC_InternalState.MAStore = CRTC_InternalState.MALine + CRTC_InternalState.HCount;
								ADRESSE_maStore_mem:=ADRESSE_maStore_mem + RHDisp + Skew;
							end if;
						end if;

					
				end if;
				
				if crtc_type='0' then
					-- hDispDelay = (reg[8] >> 4) & 0x03;
					if Skew="00" then
						dispH:=dispH_skew0;
					elsif Skew="01" then
						dispH:=dispH_skew1;
					elsif Skew="10" then
						dispH:=dispH_skew2;
					else
						--checkHDisp()
						--if ((reg[8] & 0x030) == 0x30) {
						dispH:='0'; --normally full black (no output)
					end if;
					dispH_skew2:=dispH_skew1;
					dispH_skew1:=dispH_skew0;
				else
					dispH:=dispH_skew0;
				end if;
				--if frame_oddEven='1' then
				--	dispH:='0'; -- :p
				--end if;
				
				-- V (bit 5) : Vertical Blanking
				-- Bit 5 is set to 1 when CRTC is in "vertical blanking". Vertical blanking is when the vertical border
				-- is active. i.e. VCC>=R6.
				-- It is cleared when the frame is started (VCC=0). It is not directly related to the DISPTMG output
				-- (used by the CPC to display the border colour) because that output is a combination of horizontal
				-- and vertical blanking. This bit will be 0 when pixels are being displayed.
				
				-- http://quasar.cpcscene.net/doku.php?id=coding:test_crtc
				-- Lecture de l'ÃƒÆ’Ã‚Â©tat de la VBL sur le bit 5 du registre 10 sur le port &BFxx	Non	>>Non<<	Non	Oui	Oui
				
				-- Only R5 still needs to be explained. To allow a finer adjustment of the screen length than by the number of character lines (R4), R5 adds a number of blank scanlines at the end of the screen timing.
				
				--DISPTMG signal defines the border. When DISPTMG is "1" the border colour is output by the Gate-Array to the display.
				--The DISPTMG can be forced using R8 (DISPTMG Skew) on type 0,3 and 4 or by setting R6=0 on type 1.
				if LineCounter=RVDisp and RasterCounter=0 and crtc_type='1' then
					--redondance ici de cas newFrame() (déjà traité ailleur)
					--checkHDisp() -- if (reg[6] != 0) { --listener.hDispStart();
					dispV:='0';
					-- Scan is not currently running in vertical blanking time-span.
					--VBLANK<='1';
				elsif LineCounter=0 then
					dispV:='1';
					-- Scan currently is in vertical blanking time-span.
					--VBLANK<='0';
				elsif LineCounter=RVDisp and RasterCounter=0 and crtc_type='0' then
					--redondance ici de cas newFrame() (déjà traité ailleur)
					dispV:='0';
				end if;
				if LineCounter=0 then
					LineCounter_is0<=true;
				else
					LineCounter_is0<=false;
				end if;
				
				if dispH='1' and dispV='1' then
					--etat_rgb<=DO_READ;
					-- http://quasar.cpcscene.com/doku.php?id=assem:crtc
					-- Have to respect address cut ADRESSE_CONSTANT_mem:=conv_integer(ADRESSE_maRegister(13 downto 0)) mod (16*1024);
					
					-- newFrame() :  ma = maBase = ADRESSE_maRegister;
					
					-- je suis relatif ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â  RHdisp, alors qu'ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â  chaque scanStart() RHdisp est relu et += ADRESSE_maStore_mem
					--ADRESSE_hCC_mem:=conv_integer(hCC) mod (16*1024);
					
					-- .------- REG 12 --------.   .------- REG 13 --------.
					-- |                       |   |                       |
					--  15 14 13 12 11 10 09 08     07 06 05 04 03 02 01 00
					-- .--.--.--.--.--.--.--.--.   .--.--.--.--.--.--.--.--.
					-- |X |X |  |  |  |  |  |  |   |  |  |  |  |  |  |  |  |
					-- '--'--'--'--'--'--'--'--'   '--'--'--'--'--'--'--'--'
					--       '--.--'--.--'---------------.-----------------'
					--          |     |                  |
					--          |     |                  '------> Offset for setting
					--          |     |                           videoram 
					--          |     |                           (1024 positions)
					--          |     |                           Bits 0..9
					--          |     |
					--          |     '-------------------------> Video Buffer : note (1)
					--          |
					--          '-------------------------------> Video Page : note (2)
					-- note (1)                 note (2)
					-- .--.--.--------------.  .--.--.---------------.
					-- |11|10| Video Buffer |  |13|12|   Video Page  |
					-- |--|--|--------------|  |--|--|---------------|
					-- | 0| 0|     16Ko     |  | 0| 0|  0000 - 3FFF  |
					-- |--|--|--------------|  |--|--|---------------|
					-- | 0| 1|     16Ko     |  | 0| 1|  4000 - 7FFF  |
					-- |--|--|--------------|  |--|--|---------------|
					-- | 1| 0|     16Ko     |  | 1| 0|  8000 - BFFF  |
					-- |--|--|--------------|  |--|--|---------------|
					-- | 1| 1|     32Ko     |  | 1| 1|  C000 - FFFF  |
					-- '--'--'--------------'  '--'--'---------------'
					--
					--PulkoMandy - I don't get this "4 pages" thing. The CRTC can address the full 64K of central ram and start the display almost anywhere in it. 
					
					-- ma = (maBase + hCC) & 0x3fff;
					--MA:=conv_std_logic_vector(ADRESSE_maStore_mem+ADRESSE_hCC_mem,14);
					--RasterCounter:=ligne_carac_v_RA;
					--http://cpctech.cpc-live.com/docs/scraddr.html
					crtc_A_mem(14 downto 0):=ADRESSE_MAcurrent_mem(13 downto 12) & RasterCounter(2 downto 0) & ADRESSE_MAcurrent_mem(9 downto 0);
					--http://cpcrulez.fr/coding_amslive02-balayage_video.htm dit :
					--MA(13 downto 12) & RasterCounter(2 downto 0) & MA(9 downto 0) & CCLK
				else
					--etat_rgb<=DO_NOTHING_OUT;
					crtc_A_mem:=(others=>'0');
				end if;
				-- it's not really 16MHz, but we don't care
				crtc_A(15 downto 0)<=crtc_A_mem(14 downto 0) & '0';

-- VRAM_HDsp VRAM_VDsp
-- it's just the begin, do relax...
if etat_monitor_vsync(2)=DO_VSYNC and etat_monitor_vsync(3)=DO_NOTHING then
--vsync (gerald confirmed this to me):
--1. vsync to monitor is 2 HSYNC after the start of vsync from crtc. (2 scanlines delay)
--	=> interrupt wait et wait_wait.
--2. vsync to monitor is max 4 lines
--3. vsync to monitor is cut if crtc vsync length is less than 6.
--	=> vSyncCount = 25; 24|0 donc 4*6
--
--	So VSYNC (@raster-line) :
--	* CRTC 1000000 1100000 1110000 1111000 1111100 1111110 1111111
--	* TV   0000000 0000000 0010000 0011000 0011100 0011110 0011110
	vram_vertical_offset_counter:=0;
	--vram_vertical_counter:=0;
end if;
if etat_monitor_hsync(2)=DO_HSYNC and etat_monitor_hsync(3)=DO_NOTHING then
	if vram_vertical_counter<VRAM_VDsp then
		vram_vertical_counter:=vram_vertical_counter+1;
	end if;
	if vram_vertical_offset_counter<VRAM_Voffset then
		vram_vertical_offset_counter:=vram_vertical_offset_counter+1;
	elsif vram_vertical_offset_counter=VRAM_Voffset then
		vram_vertical_offset_counter:=vram_vertical_offset_counter+1;
		vram_vertical_counter:=0;
	end if;
	
--hsync:
--1. hsync to monitor starts 2 us after the hsync from crtc.
--2. hsync to monitor is max 4us
--3. if hsync programmed into crtc is less than 6, hsync to monitor is shorter. (e.g. if you write 4 into hsync length in crtc, hsync to monitor is 2us long).
--	So HSYNC (@1MHz)
--	* CRTC 1000000 1100000 1110000 1111000 1111100 1111110 1111111
--	* TV   0000000 0000000 0010000 0011000 0011100 0011110 0011110
	vram_horizontal_offset_counter:=0;
	--vram_horizontal_counter:=0;
end if;

-- Here we're scanning 800x600 following VSYNC et HSYNC, so we can write some border...
if vram_horizontal_counter<VRAM_HDsp then
	vram_horizontal_counter:=vram_horizontal_counter+1;
end if;
if vram_horizontal_offset_counter<VRAM_Hoffset then
	vram_horizontal_offset_counter:=vram_horizontal_offset_counter+1;
elsif vram_horizontal_offset_counter=VRAM_Hoffset then
	vram_horizontal_offset_counter:=vram_horizontal_offset_counter+1;
	vram_horizontal_counter:=0;
end if;

is_H_middle:=false;
-- Here we're scanning 800x600 following VSYNC et HSYNC, so we can write some border...
if vram_vertical_counter<VRAM_VDsp then
	in_V:=true;
	if vram_horizontal_counter=0 and vram_vertical_counter= 0 then
		palette_A_tictac_mem:=(others=>'0');
	end if;
	
	if vram_horizontal_counter=VRAM_HDsp/2 then
		is_H_middle:=true;
	end if;
	
	if dispH='1' and (vram_horizontal_counter=0 or last_dispH='0') then
		-- big capture.
		border_begin_mem:=conv_std_logic_vector(vram_horizontal_counter,8);
		RHdisp_mem:=RHdisp;
		last_dispH:='1';
	end if;
else
	in_V:=false;
end if;

if vram_vertical_counter<VRAM_VDsp and vram_horizontal_counter<VRAM_HDsp then
	bvram_A_mem:=conv_std_logic_vector(vram_vertical_counter*VRAM_HDsp+vram_horizontal_counter,bvram_A_mem'length);
	disp_VRAM:='1';
else
	-- do kill disp
	disp_VRAM:='0';
end if;

if dispH='0' then
	-- allow last_dispH to go back to '0'.
	last_dispH:='0';
end if;

				--cycle()
-- The CRTC component is separated from Gatearray component, so does we have some late ?
-- Not certain, as this old component was really old ones : using state and no rising_egde...
				-- if (hCC == reg[0]) {
				-- Valeur minimale du registre 0 CRTC0:1 CRTC1:0
				if hCC=RHtot and (crtc_type='1' or RHtot/=0) then -- tot-1 ok
					--hCC = 0;
					hCC:=(others=>'0');
					--scanStart(); ====> vSyncWidth ....
					--if (reg[9] == 0 && reg[4] == 0 && (CRTCType == 0 || CRTCType == 3)) {
					--	vtAdj = 1;
					--}
					--if (vtAdj > 0 && --vtAdj == 0) newFrame();
					-- else if ((ra | interlaceVideo) == maxRaster) {
					if ((RasterCounter or "0000000" & interlaceVideo)=RRMax and LineCounter=RVTot and RVtotAdjust=0 and not(RVtotAdjust_do)) -- tot-1 ok ok
						or (RVtotAdjust_do and RVtotAdjust_mem=RVtotAdjust) then
						-- on a fini RVtotAdjust (ou sinon on a eu un RVtot fini sans RVtotAdjust)
							RVtotAdjust_do:=false;
							--newFrame()
							-- on commence RVtot
							--if (vCC == reg[4] && vtAdj == 0) {
							RasterCounter:="0000000" & frame_oddEven and "0000000" & interlaceVideo; --(others=>'0'); -- pulse ?
							zap_scan:=false;
--This method requires careful timing for the CRTC register updates,
--	it also needs testing on all CRTC because there are differences
-- of when each will accept and use the values programmed. However,
--	the result can be made to work on all with more simple ruptures.
--	Care must also be taken to ensure the timings are setup for a 50Hz screen. 
--When VCC=0, R12/R13 is re-read at the start of each line. R12/R13 can therefore be changed for each scanline when VCC=0. 
							--updateScreen()
							--ma = maBase = ADRESSE_maRegister;
							--maCurrent = maStore = maRegister;
							--Validation de l'offset après reprogrammation des registres 12 et 13
							ADRESSE_maStore_mem:=ADRESSE_maRegister(13 downto 0);
							
							LineCounter:=(others=>'0');
							ADRESSE_MAcurrent_mem:=ADRESSE_maStore_mem;
							if interlace = '0' then
								frame_oddEven:='0';
							else
								frame_oddEven:=not(frame_oddEven);
							end if;
							-- RVtot vs RVtotAdjust ? RVtotAdjust ne serait-il pas dynamique par hazard ? NON selon JavaCPC c'est meme le contraire
					elsif (RasterCounter or "0000000" & interlaceVideo)=RRMax then
						--RasterCounter = (frame & interlaceVideo) & 0x07;
						RasterCounter:="0000000" & frame_oddEven and "0000000" & interlaceVideo; --(others=>'0');
						-- scanStart() : maBase = (maBase + reg[1]) & 0x3fff;
						if LineCounter=RVTot and not(RVtotAdjust_do) then
							--if (interlace && frame == 0) {
							--	vtAdj++;
							--}
							RVtotAdjust_mem:=x"01";
							RVtotAdjust_do:=true;
						elsif RVtotAdjust_do then
							RVtotAdjust_mem:=RVtotAdjust_mem+1;
						end if;
						-- Linear Address Generator
						-- Nhd+0
						--if ((getRA() | interlaceVideo) == maxRaster) {
						--	maStore = (maStore + reg[1]) & 0x3fff;
						--}
						--maStore = (maStore + reg[1]) & 0x3fff;
						--0x3fff est ok : ADRESSE_maStore_mem(13:0)

						--hDispStart()
						--maCurrent = maStore & 0x03fff; (cas 1 et 2 1/2) -- cas 1 hCC=0 cas 2 hDispStart() -- hDispStart() est lancé lors vDisp dans JavaCPC
						ADRESSE_MAcurrent_mem:=ADRESSE_maStore_mem;
						--} else if (vcc && -- if (vtAdj == 0 || (CRTCType == 1)) { -- "vcc" est un boolean ici (un RRmax atteind)
						--if (vcc && vtAdj == 0) { -- "vcc" est un boolean ici (un RRmax atteind)
						if crtc_type='1' or not(RVtotAdjust_do) then
							-- LineCounter = (LineCounter + 1) & 0x7f;
							LineCounter:=(LineCounter+1) and x"7F";
						end if;
					else
						-- RasterCounter = (RasterCounter + scanAdd) & 0x07;
						RasterCounter:=(RasterCounter + scanAdd) and x"1F";
						if RVtotAdjust_do then
							RVtotAdjust_mem:=RVtotAdjust_mem+1;
						elsif LineCounter = 0 and crtc_type='1' then
							--if (CRTCType == 0 && LineCounter == 0 && RasterCounter == 0 && maScroll == 0) {
							--if (CRTCType == 1 && LineCounter == 0/*
							--When VCC=0, R12/R13 is re-read at the start of each line. R12/R13 can therefore be changed for each scanline when VCC=0. 
							--updateScreen()
							--maCurrent = maStore = maRegister;
							--Validation de l'offset après reprogrammation des registres 12 et 13
							ADRESSE_maStore_mem:=ADRESSE_maRegister(13 downto 0);
						end if;
						--hDispStart()
						--maCurrent = maStore & 0x03fff; (cas 1 et 2 2/2) -- cas 1 hCC=0 cas 2 hDispStart() -- hDispStart() est lancé lors vDisp dans JavaCPC
						ADRESSE_MAcurrent_mem:=ADRESSE_maStore_mem;
					end if;
					
				else
					-- hCCMask : so var is size 256 and mod is 128...
					--protected int hCCMask = 0x7f;
					--hCC = (hCC + 1) & hCCMask;
					hCC:=(hCC+1) and x"7F";
					--maCurrent = (maStore + hCC) & 0x3fff;
					ADRESSE_MAcurrent_mem:=ADRESSE_maStore_mem+hCC; -- WakeUp color raster while girl is here. Better if this code is here.
				end if;

				bvram_A(14 downto 0)<=bvram_A_mem_delta(13 downto 0) & '1';
				DATA_mem:=crtc_D;
				DATA_action<='1';
				DATA<=DATA_mem;
				bvram_W<=disp_delta;
				bvram_D<=DATA_mem;
				
				crtc_R<=dispH and dispV and disp_VRAM;
crtc_VSYNC<=etat_vsync;
vsync_int<=etat_vsync;
hsync_int<=etat_hsync;
				
			when 1=>
				-- Daisy relaxing (zsdram.v)
				bvram_A_mem_delta:=bvram_A_mem;
				disp_delta:=dispH and dispV and disp_VRAM;
				--Daisy relaxing (zsdram.v)
				crtc_A(15 downto 0)<=crtc_A_mem(14 downto 0) & '0';
				crtc_R<=dispH and dispV and disp_VRAM;
				DATA_action<='0';
				

			when 2=>
				bvram_A(14 downto 0)<=bvram_A_mem_delta(13 downto 0) & '0';
				DATA_mem:=crtc_D;
				DATA<=DATA_mem;
				DATA_action<='1';
				bvram_W<=disp_delta;
				bvram_D<=DATA_mem;
				crtc_A(15 downto 0)<=crtc_A_mem(14 downto 0) & '1';
				crtc_R<=dispH and dispV and disp_VRAM;
				if dispH='1' and dispV='1' then
					etat_rgb<=DO_READ;
				else
					etat_rgb<=DO_NOTHING_OUT;
				end if;
vsync_azrael<=etat_monitor_vhsync(1);
hsync_azrael<=etat_monitor_hsync(1);
			when 3=>
				--Daisy relaxing (zsdram.v)
				crtc_A(15 downto 0)<=crtc_A_mem(14 downto 0) & '1';
				crtc_R<=dispH and dispV and disp_VRAM;
				DATA_action<='0';
			end case;
			
-- filling palette (PRAM)
if in_V then
	if is_H_middle and compteur1MHz=0 then
		palette_horizontal_counter:=0;
		disp_begin_mem:=dispH and dispV and disp_VRAM;
	elsif palette_horizontal_counter<2+16+1 then
		palette_horizontal_counter:=palette_horizontal_counter+1;
	end if;
	if disp_begin_mem='0' then
		-- full VERTICAL BORDER
		if palette_horizontal_counter<1 then
			palette_A<=palette_A_tictac_mem(13 downto 0);
			palette_D_tictac_mem:=border_begin_mem;
			palette_D<=palette_D_tictac_mem;
			palette_W<='1';
			palette_A_tictac_mem:=palette_A_tictac_mem+1;
		elsif palette_horizontal_counter<2 then
			palette_A<=palette_A_tictac_mem(13 downto 0);
			palette_D_tictac_mem:=conv_std_logic_vector(border,5) & "0" & newMode;
			palette_D<=palette_D_tictac_mem;
			palette_W<='1';
			palette_A_tictac_mem:=palette_A_tictac_mem+1;
		elsif palette_horizontal_counter<2+16 then
			palette_A<=palette_A_tictac_mem(13 downto 0);
			if palette_horizontal_counter = 2 then
				palette_color:=0;
			else
				palette_color:=palette_color+1;
			end if;
			palette_D_tictac_mem:=conv_std_logic_vector(pen(palette_color),8);
			palette_D<=palette_D_tictac_mem;
			palette_W<='1';
			palette_A_tictac_mem:=palette_A_tictac_mem+1;
		elsif palette_horizontal_counter<2+16+1 then
			palette_A<=palette_A_tictac_mem(13 downto 0);
			palette_D_tictac_mem:=RHdisp_mem;
			palette_D<=palette_D_tictac_mem;
			palette_W<='1';
			palette_A_tictac_mem:=palette_A_tictac_mem+1;
		else
			palette_A<=(others=>'0');
			palette_D<=(others=>'0');
			palette_W<='0';
		end if;
	elsif disp_begin_mem='1' then
		-- DISPLAY
		if palette_horizontal_counter<1 then
			palette_A<=palette_A_tictac_mem(13 downto 0);
			-- compute LEFT BORDER
			palette_D_tictac_mem:=border_begin_mem;
			palette_D<=palette_D_tictac_mem;
			palette_W<='1';
			palette_A_tictac_mem:=palette_A_tictac_mem+1;
		elsif palette_horizontal_counter<2 then
			palette_A<=palette_A_tictac_mem(13 downto 0);
			palette_D_tictac_mem:=conv_std_logic_vector(border,5) & "1" & newMode;
			palette_D<=palette_D_tictac_mem;
			palette_W<='1';
			palette_A_tictac_mem:=palette_A_tictac_mem+1;
		elsif palette_horizontal_counter<2+16 then
			palette_A<=palette_A_tictac_mem(13 downto 0);
			if palette_horizontal_counter = 2 then
				palette_color:=0;
			else
				palette_color:=palette_color+1;
			end if;
			palette_D_tictac_mem:=conv_std_logic_vector(pen(palette_color),8);
			palette_D<=palette_D_tictac_mem;
			palette_W<='1';
			palette_A_tictac_mem:=palette_A_tictac_mem+1;
		elsif palette_horizontal_counter<2+16+1 then
			palette_A<=palette_A_tictac_mem(13 downto 0);
			-- compute RIGHT BORDER
			palette_D_tictac_mem:=RHdisp_mem;
			palette_D<=palette_D_tictac_mem;
			palette_W<='1';
			palette_A_tictac_mem:=palette_A_tictac_mem+1;
		else
			palette_A<=(others=>'0');
			palette_D<=(others=>'0');
			palette_W<='0';
		end if;
	end if;
end if;
			
			--crtc_DISP<=dispH and dispV and disp_VRAM;
			
--does pass arnoldemu testbench "cpctest" http://cpctech.cpc-live.com/test.zip
--crtc_VSYNC<=vsync_int;
	

		end if;
	end process simple_GateArray_process;

	Markus_interrupt_process: process(reset,nCLK4_1) is
		variable InterruptLineCount : std_logic_vector(5 downto 0):=(others=>'0'); -- a 6-bit counter, reset state is 0
		variable InterruptSyncCount:integer range 0 to 2:=2;
		variable etat_hsync_old : STD_LOGIC:=DO_NOTHING;
		variable etat_vsync_old : STD_LOGIC:=DO_NOTHING;
		--variable IO_ACK_old : STD_LOGIC:='0';
		variable newMode_mem : STD_LOGIC_VECTOR(1 downto 0);
	begin
		if reset='1' then
			InterruptLineCount:=(others=>'0');
			InterruptSyncCount:=2;
			--IO_ACK_old:='0';
			etat_hsync_old:=DO_NOTHING;
			etat_vsync_old:=DO_NOTHING;
			int<='0';
			--crtc_VSYNC<=DO_NOTHING;
			
			--etat_hsync:=DO_NOTHING;
			--etat_monitor_hsync:=(others=>DO_NOTHING);
			--etat_vsync:=DO_NOTHING;
			--etat_monitor_vsync:=(others=>DO_NOTHING);
			
		--it's Z80 time !
		elsif rising_edge(nCLK4_1) then

		-- no IO_ACK_old => CPCTEST ok
		if IO_ACK='1' then --and IO_ACK_old='0' then
--the Gate Array will reset bit5 of the counter
--Once the Z80 acknowledges the interrupt, the GA clears bit 5 of the scan line counter.
-- When the interrupt is acknowledged, this is sensed by the Gate-Array. The top bit (bit 5), of the counter is set to "0" and the interrupt request is cleared. This prevents the next interrupt from occuring closer than 32 HSYNCs time. http://cpctech.cpc-live.com/docs/ints.html
			--InterruptLineCount &= 0x1f;
			InterruptLineCount(5):= '0';
-- following Grimware legends : When the CPU acknowledge the interrupt (eg. it is going to jump to the interrupt vector), the Gate Array will reset bit5 of the counter, so the next interrupt can't occur closer than 32 HSync.
			--compteur52(5 downto 1):= (others=>'0'); -- following JavaCPC 2015
-- the interrupt request remains active until the Z80 acknowledges it. http://cpctech.cpc-live.com/docs/ints.html
			int<='0'; -- following JavaCPC 2015
		end if;
		--IO_ACK_old:=IO_ACK;
		
		
		-- InterruptLineCount begin
			--http://www.cpcwiki.eu/index.php/Synchronising_with_the_CRTC_and_display
			if IO_REQ_W='1' and A15_A14_A9_A8(3) = '0' and A15_A14_A9_A8(2) = '1' then
				if D(7) ='0' then
					-- ink -- osef
				else
					if D(6) = '0' then
						-- It only applies once
						if D(4) = '1' then
							InterruptLineCount:=(others=>'0');
	--Grimware : if set (1), this will (only) reset the interrupt counter. --int<='0'; -- JavaCPC 2015
	--the interrupt request is cleared and the 6-bit counter is reset to "0".  -- http://cpctech.cpc-live.com/docs/ints.html
							int<='0';
						end if;
	-- JavaCPC 2015 : always old_delay_feature:=D(4); -- It only applies once ????
					else 
						-- rambank -- osef pour 464
					end if;
				end if;
			end if;
			
			
			--The GA has a counter that increments on every falling edge of the CRTC generated HSYNC signal.
			--hSyncEnd()
			if etat_hsync_old=DO_HSYNC and hsync_int=DO_NOTHING then
			-- It triggers 6 interrupts per frame http://pushnpop.net/topic-452-1.html
				-- JavaCPC interrupt style...
				--if (++InterruptLineCount == 52) {
				InterruptLineCount:=InterruptLineCount+1;
				if conv_integer(InterruptLineCount)=52 then -- Asphalt ? -- 52="110100"
					--Once this counter reaches 52, the GA raises the INT signal and resets the counter to 0.
					--InterruptLineCount = 0;
					InterruptLineCount:=(others=>'0');
					--GateArray_Interrupt();
					int<='1';
				end if;
				
				--if (InterruptSyncCount > 0 && --InterruptSyncCount == 0) {
				if InterruptSyncCount < 2 then
					InterruptSyncCount := InterruptSyncCount + 1;
					if InterruptSyncCount = 2 then
						--if (InterruptLineCount >= 32) {
						if conv_integer(InterruptLineCount)>=32 then
							--GateArray_Interrupt();
							int<='1';
						--else
							--int<='0'; -- Circle- DEMO ? / Markus JavaCPC doesn't have this instruction
						end if;
						--InterruptLineCount = 0;
						InterruptLineCount:=(others=>'0');
					end if;
				end if;
				
				newMode_mem:=MODE_select;
				newMode<=newMode_mem;
			end if;
			
			--vSyncStart()
			if vsync_int=DO_VSYNC and etat_vsync_old=DO_NOTHING then
				--A VSYNC triggers a delay action of 2 HSYNCs in the GA
				--In both cases the following interrupt requests are synchronised with the VSYNC. 
				-- JavaCPC
				--InterruptSyncCount = 2;
				InterruptSyncCount := 0;
			end if;
			-- InterruptLineCount end
			
			etat_hsync_old:=hsync_int;
			etat_vsync_old:=vsync_int;
		end if;
	end process Markus_interrupt_process;
	
	VMODE<=newMode;

	aZRaEL_process : process(CLK16MHz) is
		-- BORDER 0 testbench (image position)
		--38-8=8 carac
		constant BEGIN_VBORDER : integer :=(8-4)*8; -- OK validated 32
		constant END_VBORDER : integer :=(8+25+4)*8; -- KO missing 4 chars OK corrected. 296
		--64-46=18 carac16(2 carac) => 16 (????)
		-- 296-32=296 296*2=528 720x528 does exists...
		
		-- -3.5
		--constant BEGIN_HBORDER : integer :=(16-2 -2 )*16+8; -- ko missing 3 char 200
		constant BEGIN_HBORDER : integer :=(16-2 -2 -3)*16; -- ko missing 3 char 144
		--constant END_HBORDER : integer :=(16+40+2)*16-8; -- OK but -8 cause one char too late 920
		-- constant END_HBORDER : integer :=(16+40+2 -4)*16; -- OK but -8 cause one char too late 920
		-- + 2.5
		--constant END_HBORDER : integer :=(16+40+2 -4 +2)*16+8; -- OK but -8 cause one char too late 904
		-- + 2.5+0.5
		constant END_HBORDER : integer :=(16+40+2 -4 +2)*16+8+8; -- OK but -8 cause one char too late 912
		-- Not 720 : 904-144 = 760
		
		-- 4*16*2+640=768
		-- 912 - 144=768
		
		
		
		 variable compteur1MHz_16 : integer range 0 to 7:=0;
		 variable old_DATA_action : std_logic:='0';
		 -- aZRaEL
		variable DATA_mem:std_logic_vector(7 downto 0);
		variable NB_PIXEL_PER_OCTET:integer range NB_PIXEL_PER_OCTET_MIN to NB_PIXEL_PER_OCTET_MAX;
		variable cursor_pixel_ref : integer range 0 to NB_PIXEL_PER_OCTET_MAX-1;
		variable cursor_pixel : integer range 0 to NB_PIXEL_PER_OCTET_MAX-1;
		variable etat_rgb_mem : integer range 0 to 2:=DO_NOTHING_OUT;
		variable color : STD_LOGIC_VECTOR(2**(MODE_MAX)-1 downto 0);
		variable color_patch : STD_LOGIC_VECTOR(2**(MODE_MAX)-1 downto 0);
		variable vsync_mem:std_logic:='0';
		variable hsync_mem:std_logic:='0';
		variable vsync_mem_old:std_logic:='0';
		variable hsync_mem_old:std_logic:='0';
		
		variable VBORDERmem:integer:=0; -- 304 max
		variable doResetVBORDERmem:boolean:=false;
		variable HBORDERmem:integer:=0; -- 64*16 max
	begin
		if rising_edge(CLK16MHz) then
			-- rising_edge
			compteur1MHz_16:=(compteur1MHz_16+1) mod 8;
			if DATA_action='1' and old_DATA_action='0' then
				compteur1MHz_16:=0;
				DATA_mem:=DATA;
				vsync_mem:=not(vsync_azrael); --not(vsync_int);
				hsync_mem:=not(hsync_azrael); --not(hsync_int);
				etat_rgb_mem:=etat_rgb;
			end if;
			vsync<=vsync_mem;
			hsync<=hsync_mem;
			-- aZRaEL display pixels
			
			if vsync_mem=DO_VSYNC and vsync_mem_old=DO_NOTHING then
				--VBORDERmem:=0;
				doResetVBORDERmem:=true;
			end if;
			if hsync_mem=DO_HSYNC and hsync_mem_old=DO_NOTHING then
				HBORDERmem:=0;
				if doResetVBORDERmem then
					VBORDERmem:=0;
					doResetVBORDERmem:=false;
				else
					VBORDERmem:=VBORDERmem+1;
				end if;
			else
				HBORDERmem:=HBORDERmem+1;
			end if;
			
			if VBORDERmem<BEGIN_VBORDER or VBORDERmem>=END_VBORDER then
				VBLANK <= '1';
			else
				VBLANK <= '0';
			end if;

			if HBORDERmem<BEGIN_HBORDER or HBORDERmem>=END_HBORDER then
				HBLANK <= '1';
			else
				HBLANK <= '0';
			end if;
			
			if VBORDERmem<BEGIN_VBORDER or VBORDERmem>=END_VBORDER or HBORDERmem<BEGIN_HBORDER or HBORDERmem>=END_HBORDER then
				-- out of SCREEN
				RED<="00";
				GREEN<="00";
				BLUE<="00";
			elsif etat_rgb_mem = DO_READ then
			
				if newMode="10" then
					NB_PIXEL_PER_OCTET:=8;
					cursor_pixel_ref:=(compteur1MHz_16 / 1) mod 8;
					cursor_pixel:=cursor_pixel_ref; -- hide one pixel on both
				elsif newMode="01" then
					NB_PIXEL_PER_OCTET:=4;
					cursor_pixel_ref:=(compteur1MHz_16 / 2) mod 8; -- ok
					cursor_pixel:=cursor_pixel_ref; -- target correction... data more slow than address coming : one tic
				else --if newMode="00" or newMode="11" then
					NB_PIXEL_PER_OCTET:=2;
					cursor_pixel_ref:=(compteur1MHz_16 / 4) mod 8;
					cursor_pixel:=cursor_pixel_ref;
				end if;
			
				color:=(others=>'0');
				for i in 2**(MODE_MAX)-1 downto 0 loop
					if (NB_PIXEL_PER_OCTET=2 and i<=3)
					or (NB_PIXEL_PER_OCTET=4 and i<=1)
					or (NB_PIXEL_PER_OCTET=8 and i<=0) then
						color(3-i):=DATA_mem(i*NB_PIXEL_PER_OCTET+(NB_PIXEL_PER_OCTET-1-cursor_pixel));
					end if;
				end loop;
				if NB_PIXEL_PER_OCTET=8 then
					RED<=palette(pen(conv_integer(color(3))))(5 downto 4);
					GREEN<=palette(pen(conv_integer(color(3))))(3 downto 2);
					BLUE<=palette(pen(conv_integer(color(3))))(1 downto 0);
				elsif NB_PIXEL_PER_OCTET=4 then
					RED<=palette(pen(conv_integer(color(3 downto 2))))(5 downto 4);
					GREEN<=palette(pen(conv_integer(color(3 downto 2))))(3 downto 2);
					BLUE<=palette(pen(conv_integer(color(3 downto 2))))(1 downto 0);
				else --if newMode="00" then + MODE 11
					color_patch:=color(3) & color(1) & color(2) & color(0); -- wtf xD
					RED<=palette(pen(conv_integer(color_patch)))(5 downto 4);
					GREEN<=palette(pen(conv_integer(color_patch)))(3 downto 2);
					BLUE<=palette(pen(conv_integer(color_patch)))(1 downto 0);
				end if;
--			elsif etat_rgb_mem = DO_BORDER then
--				RED<=palette(border)(5 downto 4);
--				GREEN<=palette(border)(3 downto 2);
--				BLUE<=palette(border)(1 downto 0);
			else
				-- border
				RED<=palette(border)(5 downto 4);
				GREEN<=palette(border)(3 downto 2);
				BLUE<=palette(border)(1 downto 0);
				--RED<="00";
				--GREEN<="00";
				--BLUE<="00";
			end if;
			old_DATA_action:=DATA_action;
			vsync_mem_old:=vsync_mem;
			hsync_mem_old:=hsync_mem;
		end if;
	end process aZRaEL_process;
	
--Interrupt Generation Facility of the Amstrad Gate Array
--The GA has a counter that increments on every falling edge of the CRTC generated HSYNC signal. Once this counter reaches 52, the GA raises the INT signal and resets the counter to 0.
--A VSYNC triggers a delay action of 2 HSYNCs in the GA, at the completion of which the scan line count in the GA is compared to 32. If the counter is below 32, the interrupt generation is suppressed. If it is greater than or equal to 32, an interrupt is issued. Regardless of whether or not an interrupt is raised, the scan line counter is reset to 0.
--The GA has a software controlled interrupt delay feature. The GA scan line counter will be cleared immediately upon enabling this option (bit 4 of ROM/mode control). It only applies once and has to be reissued if more than one interrupt needs to be delayed.
--Once the Z80 acknowledges the interrupt, the GA clears bit 5 of the scan line counter. 
--
--http://cpctech.cpc-live.com/docs/ints2.html  (asm code)
--	Furthur details of interrupt timing
--Here is some information I got from Richard about the interrupt timing:
--"Just when I finally thought I had the interrupt timing sorted out (from real tests on a 6128 and 6128+), I decided to look at the Arnold V diagnostic cartridge in WinAPE, and the Interrupt Timing test failed.
--After pulling my hair out for a few hours, I checked out some info I found on the Z80 which states something like:
--The Z80 forces 2 wait-cycles (2 T-States) at the start of an interrupt.
--The code I had forced a 1us wait state for an interrupt acknowledge. For the most part this is correct, but it's not necessarily so. Seems the instruction currently being executed when an interrupt occurs can cause the extra CPC forced wait-state to be removed.
--Those instructions are:
--This seems to be related to a combination of the T-States of the instruction, the M-Cycles, and the wait states imposed by the CPC hardware to force each instruction to the 1us boundary.
--Richard" 
end Behavioral;
