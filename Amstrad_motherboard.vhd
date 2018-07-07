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
-- FPGAmstrad_*.vhd : Auto-generated code from FGPAmstrad 3 main schematics
-- This type of component is only used on my main schematic.
-- As it is about auto-generated code, you'll find no comments by here
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.ALL;

entity joykeyb_MUSER_amstrad_motherboard is
	port (
		CLK       : in    std_logic; 
		CE_4MHz   : in    std_logic; 
		joystick1 : in    std_logic_vector (5 downto 0); 
		joystick2 : in    std_logic_vector (5 downto 0); 
		PPI_portC : in    std_logic_vector (3 downto 0); 
		PS2_CLK   : in    std_logic; 
		PS2_DATA  : in    std_logic; 
		key_reset : out   std_logic_vector(1 downto 0);
		key_nmi   : out   std_logic;
		PPI_portA : out   std_logic_vector (7 downto 0)
	);
end joykeyb_MUSER_amstrad_motherboard;

architecture BEHAVIORAL of joykeyb_MUSER_amstrad_motherboard is
   attribute BOX_TYPE: string ;
   signal PPI_enable : std_logic;
   signal keycode    : std_logic_vector (9 downto 0);
   signal scancode   : std_logic_vector (7 downto 0);
   signal press      : std_logic;
   signal unpress    : std_logic;
   signal fok        : std_logic;
   
begin
	drvr : work.KEYBOARD_driver
		port map (
			CLK=>CLK,
			CE=>CE_4MHz,
			enable=>'1', --PPI_enable
			joystick1(5 downto 0)=>joystick1(5 downto 0),
			joystick2(5 downto 0)=>joystick2(5 downto 0),
			keycode(9 downto 0)=>keycode(9 downto 0),
			portC(3 downto 0)=>PPI_portC(3 downto 0),
			press=>press,
			unpress=>unpress,
			key_reset=>key_reset(1),
			key_reset_space=>key_reset(0),
			key_nmi=>key_nmi,
			portA(7 downto 0)=>PPI_portA(7 downto 0)
		);
   
	cntrl : work.KEYBOARD_controller
		port map (
			CLK=>CLK,
			CE=>CE_4MHz,
			fok=>fok,
			scancode_in(7 downto 0)=>scancode(7 downto 0),
			keycode(9 downto 0)=>keycode(9 downto 0),
			press=>press,
			unpress=>unpress
		);

	kbd : work.Keyboard
		port map (
			fclk=>CLK,
			fce=>CE_4MHz,
			clkin=>PS2_CLK,
			datain=>PS2_DATA,
			rst=>'0',
			fok=>fok,
			scancode(7 downto 0)=>scancode(7 downto 0)
		);

end BEHAVIORAL;



library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity Amstrad_motherboard is
   port (
		RESET_n    : in  std_logic;

		CLK        : in  std_logic; 
		CE_4P      : in  std_logic; 
		CE_4N      : in  std_logic; 
		CE_16      : in  std_logic;

		JOYSTICK1  : in  std_logic_vector(5 downto 0); 
		JOYSTICK2  : in  std_logic_vector(5 downto 0); 
		PS2_CLK    : in  std_logic; 
		PS2_DATA   : in  std_logic; 
		key_reset  : out std_logic_vector(1 downto 0); 

		ppi_jumpers: in  std_logic_vector(3 downto 0);
		crtc_type  : in  std_logic;
		no_wait    : in  std_logic;

		audio_l    : out std_logic_vector(7 downto 0); 
		audio_r    : out std_logic_vector(7 downto 0); 

		ram64k     : in  std_logic;
		ram_A      : out std_logic_vector(22 downto 0); 
		ram_Dout   : out std_logic_vector(7 downto 0); 
		ram_Din    : in  std_logic_vector(7 downto 0); 
		ram_R      : out std_logic; 
		ram_W      : out std_logic; 

		fdc_sel    : out std_logic_vector(3 downto 0); -- A10 & A8 & A7 & A0
		fdc_wr     : out std_logic;
		fdc_rd     : out std_logic;
		fdc_din    : in  std_logic_vector(7 downto 0);
		fdc_dout   : out std_logic_vector(7 downto 0);

		VMODE      : out std_logic_vector(1 downto 0);
		RED        : out std_logic_vector(1 downto 0);
		GREEN      : out std_logic_vector(1 downto 0);
		BLUE       : out std_logic_vector(1 downto 0);
		HBLANK     : out std_logic;
		VBLANK     : out std_logic;
		HSYNC      : out std_logic;
		VSYNC      : out std_logic;

		palette_A  : out std_logic_vector(13 downto 0); 
		palette_D  : out std_logic_vector(7 downto 0); 
		palette_W  : out std_logic; 
		vram_A     : out std_logic_vector(14 downto 0); 
		vram_D     : out std_logic_vector(7 downto 0); -- pixel_DATA
		vram_W     : out std_logic;

		zram_din   : in  std_logic_vector(7 downto 0); 
		zram_addr  : out std_logic_vector(15 downto 0);
		zram_rd    : out std_logic;

      -- Expansion connector (for implementing peripherals)
		addr       : out std_logic_vector (15 downto 0);
		data       : out std_logic_vector (7 downto 0);
		M1         : out std_logic;
		NMI        : in std_logic;
		key_nmi    : out std_logic
	);
end Amstrad_motherboard;

architecture BEHAVIORAL of Amstrad_motherboard is

	signal A             : std_logic_vector (15 downto 0);
	signal D             : std_logic_vector (7 downto 0);
	signal IO_RD         : std_logic;
	signal IO_WR         : std_logic;
	signal MEM_RD        : std_logic;
	signal MEM_WR        : std_logic;
	signal n_crtc_vsync  : std_logic;
	signal portC         : std_logic_vector (7 downto 0);
	signal WR_n          : std_logic;
	signal MREQ_n        : std_logic;
	signal RFSH_n        : std_logic;
	signal IORQ_n        : std_logic;
	signal RD_n          : std_logic;
	signal asic_dout     : std_logic_vector (7 downto 0):=(others=>'1');
	signal ppi_dout      : std_logic_vector (7 downto 0):=(others=>'1');
	signal mem_dout      : std_logic_vector (7 downto 0):=(others=>'1');
	signal portAout      : std_logic_vector (7 downto 0);
	signal kbd_out       : std_logic_vector (7 downto 0);
	signal portAin       : std_logic_vector (7 downto 0);
	signal WAIT_n        : std_logic;
	signal INT           : std_logic;
	signal M1_n          : std_logic;
	signal SOUND_CLK     : std_logic;

begin

	IO_RD <=not RD_n and not IORQ_n;
	IO_WR <=not WR_n and not IORQ_n;
	MEM_RD<=not RD_n and not MREQ_n;
	MEM_WR<=not WR_n and not MREQ_n;

	ram_W<=MEM_WR;
	ram_R<=MEM_RD;

	ram_Dout<=D;
	mem_dout<=ram_Din when MEM_RD='1' else (others=>'1');

	fdc_sel <= A(10) & A(8) & A(7) & A(0);
	fdc_wr  <= IO_WR;
	fdc_rd  <= IO_RD;
	fdc_dout<= D;

	addr<=A;
	data<=D;
	M1<=not M1_n;

	CPU : work.T80pa
		port map (
			RESET_n=>RESET_n,

			CLK=>CLK,
			CEN_p=>CE_4P and (WAIT_n or no_wait),
			CEN_n=>CE_4N,

			A=>A,
			DO=>D,
			DI=>asic_dout and ppi_dout and mem_dout and fdc_din,

			RD_n=>RD_n,
			WR_n=>WR_n,
			IORQ_n=>IORQ_n,
			MREQ_n=>MREQ_n,
			M1_n=>M1_n,
			RFSH_n=>RFSH_n,

			BUSRQ_n=>'1',
			INT_n=>not INT,
			NMI_n=>not NMI,
			WAIT_n=>'1'
		);

	ASIC : work.Amstrad_ASIC
		port map (
			reset=>not RESET_n,
			
			CLK=>CLK,
			CE_4=>CE_4P,
			CE_16=>CE_16,

			crtc_D=>zram_din,

			VMODE=>VMODE,

			A15_A14_A9_A8=> (A(15) & A(14) & A(9) & A(8)),
			D=>D,
			M1_n=>M1_n,
			MREQ_n=>MREQ_n or not RFSH_n,
			IORQ_n=>IORQ_n,
			RD_n=>RD_n,
			WR_n=>WR_n,

			crtc_type=>crtc_type,
			bvram_A=>vram_A,
			bvram_D=>vram_D,
			bvram_W=>vram_W,
			crtc_A=>zram_addr,
			crtc_R=>zram_rd,
			crtc_VSYNC=>n_crtc_vsync,
			int=>INT,
			palette_A=>palette_A,
			palette_D=>palette_D,
			palette_W=>palette_W,
			WAIT_n=>WAIT_n,
			SOUND_CLK=>SOUND_CLK,
			Dout=>asic_dout,
			RED=>RED,
			GREEN=>GREEN,
			BLUE=>BLUE,
			VBLANK=>VBLANK,
			HBLANK=>HBLANK,
			HSYNC=>HSYNC,
			VSYNC=>VSYNC
		);

	PPI : work.pio		 
		port map (
			addr(1 downto 0)=>A(9 downto 8),
			datain=>D,
			cs=>A(11),
			iowr=>not(IO_WR),
			iord=>not(IO_RD),
			cpuclk=>CLK, -- (no clocked this component normaly, so let's overclock it)

			PBI(7)=>'1', -- pull up (default)
			PBI(6)=>'1', -- pull up (default)
			PBI(5)=>'1', -- pull up (default)
			PBI(4)=>ppi_jumpers(3), --'1', --50Hz
			PBI(3)=>ppi_jumpers(2), --'1',
			PBI(2)=>ppi_jumpers(1), --zero,
			PBI(1)=>ppi_jumpers(0), --'1',
			PBI(0)=>n_crtc_vsync,

			PAI=>portAin,
			PAO=>portAout,
			PCO=>portC,
			DO=>ppi_dout
		);

   MMU : work.Amstrad_MMU
      port map (
			CLK=>CLK,
			reset=>not RESET_n,
			ram64k=>ram64k,
			A=>A,
			D=>D,
			wr_io_z80=>IO_WR,
			wr_z80=>MEM_WR,
			ram_A=>ram_A
		);

   PSG : work.YM2149
      port map (
			RESET_L=>RESET_n,

			CLK=>CLK,
			ENA=>not SOUND_CLK and CE_4P,
			I_SEL_L=>'1',

			I_A8=>'1',
			I_A9_L=>'0',
			I_BC1=>portC(6),
			I_BC2=>'1',
			I_BDIR=>portC(7),
			I_DA=>portAout,
			O_DA=>portAin,

			O_AUDIO_L=>audio_L,
			O_AUDIO_R=>audio_R,

			I_IOA=>kbd_out,
			I_IOB=>X"FF"
		);

   KBD : work.joykeyb_MUSER_amstrad_motherboard
		port map (
			CLK=>CLK,
			CE_4MHz=>CE_4P,
			joystick1=>JOYSTICK1,
			joystick2=>JOYSTICK2,
			PPI_portC=>portC(3 downto 0),
			PS2_CLK=>PS2_CLK,
			PS2_DATA=>PS2_DATA,
			key_reset=>key_reset,
			key_nmi=>key_nmi,
			PPI_portA=>kbd_out
		);

end BEHAVIORAL;


