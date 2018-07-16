--------------------------------------------------------------------------------
--
-- Extracted to separate entity, optimized and tweaked
-- (c) 2018 Sorgelig
--
--------------------------------------------------------------------------------
--
--    {@{@{@{@{@{@
--  {@{@{@{@{@{@{@{@  This code is covered by CoreAmstrad synthesis r005
--  {@    {@{@    {@  A core of Amstrad CPC 6128 running on MiST-board platform
--  {@{@{@{@{@{@{@{@
--  {@  {@{@{@{@  {@  CoreAmstrad is implementation of FPGAmstrad on MiST-board
--  {@{@        {@{@   Contact : renaudhelias@gmail.com
--  {@{@{@{@{@{@{@{@   @see http://code.google.com/p/mist-board/
--    {@{@{@{@{@{@     @see FPGAmstrad at CPCWiki
--
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- https://sourceforge.net/p/jemu/code/HEAD/tree/JEMU/src/jemu/system/cpc/GateArray.java

-- ink 0,2,20
-- speed ink 1,1
entity Amstrad_GA is
	Generic (
		--HD6845S 	Hitachi 	0 HD6845S_WriteMaskTable type 0 in JavaCPC
		--UM6845 	UMC 		0
		--UM6845R 	UMC 		1 UM6845R_WriteMaskTable type 1 in JavaCPC <==
		--MC6845 	Motorola	2 

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
		CLK       : in  STD_LOGIC;
		CE_4      : in  STD_LOGIC;
		CE_16     : in  STD_LOGIC;
		reset     : in  STD_LOGIC;

		VMODE     : out STD_LOGIC_VECTOR (1 downto 0);
		cyc1MHz   : out STD_LOGIC;

		int       : out STD_LOGIC:='0'; -- JavaCPC reset init
		crtc_vs   : in  STD_LOGIC;
		crtc_hs   : in  STD_LOGIC;
		crtc_de   : in  STD_LOGIC;
		vram_D    : in  STD_LOGIC_VECTOR (15 downto 0);
		
		INTack    : in  STD_LOGIC;
		D         : in  STD_LOGIC_VECTOR (7 downto 0);
		WE        : in  STD_LOGIC;

		RED       : out STD_LOGIC_VECTOR(1 downto 0);
		GREEN     : out STD_LOGIC_VECTOR(1 downto 0);
		BLUE      : out STD_LOGIC_VECTOR(1 downto 0);
		HBLANK    : out STD_LOGIC;
		VBLANK    : out STD_LOGIC;
		HSYNC     : out STD_LOGIC;
		VSYNC     : out STD_LOGIC
	);
end Amstrad_GA;

architecture Behavioral of Amstrad_GA is

	signal vsync_azrael:std_logic;
	signal hsync_azrael:std_logic;
	
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
	
	signal phase1MHz : std_logic_vector(1 downto 0);

begin

process(reset,CLK) is
	variable ink:STD_LOGIC_VECTOR(3 downto 0);
	variable border_ink:STD_LOGIC;
	variable ink_color:STD_LOGIC_VECTOR(4 downto 0);
	variable c_border:integer range 0 to 31;
	variable c_inkc:integer range 0 to 31;
	variable c_ink:STD_LOGIC_VECTOR(3 downto 0);
begin
	if reset='1' then
		MODE_select<="00";
	elsif rising_edge(CLK) then
		if CE_4 = '1' and phase1MHz = "00" and WE='1' then --7Fxx gate array --
			if D(7 downto 6) ="10" then
				--http://www.cpctech.org.uk/docs/garray.html
				if D(1 downto 0)="11" then
					MODE_select<="00";
				else
					MODE_select<=D(1 downto 0);
				end if;
			elsif D(7) ='0' then
				-- palette
				if D(6)='0' then
					border_ink:=D(4);
					ink:=D(3 downto 0);
				else
					ink_color:=D(4 downto 0);
					if border_ink='0' then
						c_inkc :=conv_integer(ink_color);
						c_ink  := ink;
					else
						c_border := conv_integer(ink_color);
					end if;
				end if;
			end if;
		end if;
		
		if CE_4 = '1' and phase1MHz = "10" then
			pen(conv_integer(c_ink)) <= c_inkc;
			border <= c_border;
		end if;
	end if;	
end process;

phase1MHz <= phase1MHz + ('0' & CE_4) when rising_edge(CLK);
cyc1MHz <= not phase1MHz(1) and not phase1MHz(0);

Markus_interrupt_process: process(reset,CLK) is
	variable InterruptLineCount : std_logic_vector(5 downto 0):=(others=>'0'); -- a 6-bit counter, reset state is 0
	variable InterruptSyncCount:integer range 0 to 2:=2;
	variable old_hsync : STD_LOGIC:='0';
	variable old_vsync : STD_LOGIC:='0';
	--variable IO_ACK_old : STD_LOGIC:='0';
	variable newMode_mem : STD_LOGIC_VECTOR(1 downto 0);
begin
	if reset='1' then
		InterruptLineCount:=(others=>'0');
		InterruptSyncCount:=2;

		old_hsync:='0';
		old_vsync:='0';
		int<='0';
		
	--it's Z80 time !
	elsif rising_edge(CLK) then

		if INTack='1' then --and IO_ACK_old='0' then
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
		if WE='1' then
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
		if old_hsync='1' and crtc_hs='0' then
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
		if crtc_vs='1' and old_vsync='0' then
			--A VSYNC triggers a delay action of 2 HSYNCs in the GA
			--In both cases the following interrupt requests are synchronised with the VSYNC. 
			-- JavaCPC
			--InterruptSyncCount = 2;
			InterruptSyncCount := 0;
		end if;
		-- InterruptLineCount end
		
		old_hsync:=crtc_hs;
		old_vsync:=crtc_vs;
	end if;
end process Markus_interrupt_process;
	
VMODE<=newMode;

sync_delay : process(reset,CLK) is
 
	variable monitor_hsync : STD_LOGIC_VECTOR(3 downto 0):=(others=>'0');
	variable monitor_vsync : STD_LOGIC_VECTOR(3 downto 0):=(others=>'0');
	variable monitor_vhsync : STD_LOGIC_VECTOR(3 downto 0):=(others=>'0');
	
	variable old_hsync, old_vsync : std_logic;
	variable hSyncCount : std_logic_vector(3 downto 0):=(others=>'0');
	variable vSyncCount : std_logic_vector(3 downto 0):=(others=>'0');
begin

	if rising_edge(CLK) then
		if CE_4='1' and phase1MHz = "01" then

			monitor_hsync:=monitor_hsync(2 downto 0) & monitor_hsync(0);

			if old_hsync = '0' and crtc_hs = '1' then
				hSyncCount:= x"0";
				monitor_hsync(0):='1';
			elsif old_hsync = '1' and crtc_hs = '0' then
				monitor_hsync:="0000";
			elsif crtc_hs = '1' then
				hSyncCount:=hSyncCount+1;
				if hSyncCount=1+4 then
					monitor_hsync:="0000";
				end if;
			end if;
			
			if old_hsync = '0' and crtc_hs = '1' then
				monitor_vsync:=monitor_vsync(2 downto 0) & monitor_vsync(0);
				if old_vsync = '0' and crtc_vs = '1' then
					vSyncCount:= x"0";
					monitor_vsync(0):='1';
				elsif old_vsync = '1' and crtc_vs = '0' then
					monitor_vsync:="0000";
				elsif crtc_vs='1' then
					vSyncCount:=vSyncCount+1;
					if vSyncCount=2+2 then
						monitor_vsync:="0000";
					end if;
				end if;
				
				old_vsync := crtc_vs;
			end if;

			old_hsync := crtc_hs;

			monitor_vhsync:=monitor_vhsync(2 downto 0) & monitor_vsync(2);

			vsync_azrael<=monitor_vhsync(2);
			hsync_azrael<=monitor_hsync(2);
		end if;
	end if;
end process sync_delay;


aZRaEL_process : process(CLK) is
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
	-- aZRaEL
	variable DATA_mem:std_logic_vector(7 downto 0);
	variable NB_PIXEL_PER_OCTET:integer range NB_PIXEL_PER_OCTET_MIN to NB_PIXEL_PER_OCTET_MAX;
	variable cursor_pixel : integer range 0 to NB_PIXEL_PER_OCTET_MAX-1;
	variable vde_mem :std_logic:='0';
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
	if rising_edge(CLK) then
		if CE_16='1' then
			-- rising_edge
			compteur1MHz_16:=(compteur1MHz_16+1) mod 8;

			if CE_4='1' then
				if phase1MHz = "10" then
					compteur1MHz_16:=0;
					vde_mem:=crtc_de;
					DATA_mem:=vram_D(7 downto 0);
					vsync_mem:=not(vsync_azrael); --not(crtc_vs);
					hsync_mem:=not(hsync_azrael); --not(crtc_hs);
				elsif phase1MHz = "00" then
					DATA_mem:=vram_D(15 downto 8);
				end if;
			end if;

			vsync<=vsync_mem;
			hsync<=hsync_mem;
			-- aZRaEL display pixels
			
			if vsync_mem='1' and vsync_mem_old='0' then
				--VBORDERmem:=0;
				doResetVBORDERmem:=true;
			end if;
			if hsync_mem='1' and hsync_mem_old='0' then
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
			elsif vde_mem = '1' then
			
				if newMode="10" then
					NB_PIXEL_PER_OCTET:=8;
					cursor_pixel:=(compteur1MHz_16 / 1) mod 8; -- hide one pixel on both
				elsif newMode="01" then
					NB_PIXEL_PER_OCTET:=4;
					cursor_pixel:=(compteur1MHz_16 / 2) mod 8; -- target correction... data more slow than address coming : one tic
				else --if newMode="00" or newMode="11" then
					NB_PIXEL_PER_OCTET:=2;
					cursor_pixel:=(compteur1MHz_16 / 4) mod 8;
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
			else
				-- border
				RED<=palette(border)(5 downto 4);
				GREEN<=palette(border)(3 downto 2);
				BLUE<=palette(border)(1 downto 0);
			end if;
			vsync_mem_old:=vsync_mem;
			hsync_mem_old:=hsync_mem;
		end if;
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
