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
		CLK4MHz   : in    std_logic; 
		joystick1 : in    std_logic_vector (5 downto 0); 
		joystick2 : in    std_logic_vector (5 downto 0); 
		PPI_portC : in    std_logic_vector (3 downto 0); 
		PS2_CLK   : in    std_logic; 
		PS2_DATA  : in    std_logic; 
		key_reset : out   std_logic_vector(1 downto 0); 
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
			CLK=>CLK4MHz,
			enable=>'1', --PPI_enable
			joystick1(5 downto 0)=>joystick1(5 downto 0),
			joystick2(5 downto 0)=>joystick2(5 downto 0),
			keycode(9 downto 0)=>keycode(9 downto 0),
			portC(3 downto 0)=>PPI_portC(3 downto 0),
			press=>press,
			unpress=>unpress,
			key_reset=>key_reset(1),
			key_reset_space=>key_reset(0),
			portA(7 downto 0)=>PPI_portA(7 downto 0)
		);
   
	cntrl : work.KEYBOARD_controller
		port map (
			CLK=>CLK4MHz,
			fok=>fok,
			scancode_in(7 downto 0)=>scancode(7 downto 0),
			keycode(9 downto 0)=>keycode(9 downto 0),
			press=>press,
			unpress=>unpress
		);

	kbd : work.Keyboard
		port map (
			clkin=>PS2_CLK,
			datain=>PS2_DATA,
			fclk=>CLK4MHz,
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
		ga_shunt   : in  std_logic;

		audio_AB   : out std_logic_vector(7 downto 0); 
		audio_BC   : out std_logic_vector(7 downto 0); 

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
		zram_rd    : out std_logic
	);
end Amstrad_motherboard;

architecture BEHAVIORAL of Amstrad_motherboard is
   attribute KEEP_HIERARCHY : string ;
   attribute BOX_TYPE       : string ;
   attribute HU_SET         : string ;

   signal A             : std_logic_vector (15 downto 0);
   signal D             : std_logic_vector (7 downto 0);
   signal IO_RD         : std_logic;
   signal IO_REQ        : std_logic;
   signal IO_WR         : std_logic;
   signal LED1          : std_logic;
   signal LED2          : std_logic;
   signal MEM_RD        : std_logic;
   signal MEM_WR        : std_logic;
   signal n_crtc_vsync  : std_logic;
   signal portC         : std_logic_vector (7 downto 0);
   signal WR_n          : std_logic;
   signal MREQ_n        : std_logic;
   signal IORQ_n        : std_logic;
   signal RD_n          : std_logic;
	signal MIX_DOUT      : std_logic_vector (7 downto 0):=(others=>'1');
	signal asic_dout     : std_logic_vector (7 downto 0):=(others=>'1');
	signal ppi_dout      : std_logic_vector (7 downto 0):=(others=>'1');
	signal mem_dout      : std_logic_vector (7 downto 0):=(others=>'1');
   signal portAout      : std_logic_vector (7 downto 0);
   signal kbd_out       : std_logic_vector (7 downto 0);
   signal portAin       : std_logic_vector (7 downto 0);
   signal WR            : std_logic;
   signal MREQ          : std_logic;
   signal RD            : std_logic;
   signal WAIT_n        : std_logic;
   signal INT           : std_logic;
   signal M1_n          : std_logic;
	signal SOUND_CLK     : std_logic;
   signal xram_A        : std_logic_vector (22 downto 0);
	
begin

	MREQ<=not MREQ_n;
	IO_REQ<=not IORQ_n;

	WR<=not WR_n;
	RD<=not RD_n;

	IO_RD<=RD and IO_REQ;
	IO_WR<=WR and IO_REQ;

	MEM_RD<=RD and MREQ;
	MEM_WR<=WR and MREQ;
	
	ram_A<=xram_A;
	ram_W<=MEM_WR and not MEM_RD;
	ram_R<=MEM_RD and not MEM_WR;
	ram_Dout<=D;
	mem_dout<=ram_Din when (MEM_RD='1' and MEM_WR='0') else (others=>'1');

	fdc_sel <= A(10) & A(8) & A(7) & A(0);
	fdc_wr  <= IO_WR;
	fdc_rd  <= IO_RD;
	fdc_dout<= D;

	MIX_DOUT<=asic_dout and ppi_dout and mem_dout and fdc_din;

	CPU : work.T80pa
		port map (
			BUSRQ_n=>'1',
			CLK=>CLK,
			CEN_p=>CE_4P and WAIT_n,
			CEN_n=>CE_4N,
			DI=>MIX_DOUT,
			INT_n=>not INT,
			NMI_n=>'1',
			RESET_n=>RESET_n, -- '1'der time constraint test
			WAIT_n=>'1',
			A=>A,
			BUSAK_n=>open,
			DO=>D,
			HALT_n=>open,
			IORQ_n=>IORQ_n,
			MREQ_n=>MREQ_n,
			M1_n=>M1_n,
			RD_n=>RD_n,
			RFSH_n=>open,
			WR_n=>WR_n
		);

	ASIC : work.Amstrad_ASIC
		port map (
			A15_A14_A9_A8(3)=>A(15),
			A15_A14_A9_A8(2)=>A(14),
			A15_A14_A9_A8(1)=>A(9),
			A15_A14_A9_A8(0)=>A(8),
			crtc_D(7 downto 0)=>zram_din(7 downto 0),
			D(7 downto 0)=>D(7 downto 0),
			R2D2(7 downto 0)=>MIX_DOUT(7 downto 0),
			IO_ACK=>IO_REQ and not M1_n,
			IO_REQ_R=>IO_RD,
			IO_REQ_W=>IO_WR,
			MEM_RD=>MEM_RD,
			VMODE=>VMODE,
			M1_n=>M1_n,
			nCLK4_1=>CLK and CE_4N,
			CLK16MHz=>CLK and CE_16,
			reset=>not RESET_n,
			crtc_type=>crtc_type,
			ga_shunt=>ga_shunt,
			bvram_A(14 downto 0)=>vram_A(14 downto 0),
			bvram_D(7 downto 0)=>vram_D(7 downto 0),
			bvram_W=>vram_W,
			crtc_A(15 downto 0)=>zram_addr(15 downto 0),
			crtc_R=>zram_rd,
			crtc_VSYNC=>n_crtc_vsync,
			int=>INT,
			palette_A(13 downto 0)=>palette_A(13 downto 0),
			palette_D(7 downto 0)=>palette_D(7 downto 0),
			palette_W=>palette_W,
			WAIT_n=>WAIT_n,
			SOUND_CLK=>SOUND_CLK,
			Dout(7 downto 0)=>asic_dout(7 downto 0), --inout
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
			datain(7 downto 0)=>D(7 downto 0),
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

			PAI(7 downto 0)=>portAin(7 downto 0),
			PAO(7 downto 0)=>portAout(7 downto 0),
			PCO(7 downto 0)=>portC(7 downto 0),
			DO(7 downto 0)=>ppi_dout(7 downto 0)
		);

   MMU : work.Amstrad_MMU
      port map (
			CLK=>CLK,
			reset=>not RESET_n,
			A(15 downto 0)=>A(15 downto 0),
			D(7 downto 0)=>D(7 downto 0),
			wr_io_z80=>IO_WR,
			wr_z80=>MEM_WR,
			ram_A(22 downto 0)=>xram_A(22 downto 0)
		);

   PSG : work.YM2149
      port map (
			CLK=>CLK,
			ENA=>not SOUND_CLK and CE_4P,
			I_A8=>'1',
			I_A9_L=>'0',
			I_BC1=>portC(6),
			I_BC2=>'1',
			I_BDIR=>portC(7),
			I_DA(7 downto 0)=>portAout(7 downto 0),
			I_IOA(7 downto 0)=>kbd_out(7 downto 0),
			I_SEL_L=>'1',
			RESET_L=>RESET_n,
         O_AUDIO_AB(7 downto 0)=>audio_AB,
			O_AUDIO_BC(7 downto 0)=>audio_BC,
			O_DA(7 downto 0)=>portAin(7 downto 0),
			O_DA_OE_L=>open
		);

   KBD : work.joykeyb_MUSER_amstrad_motherboard
		port map (
			CLK4MHz=>CLK and CE_4N,
			joystick1(5 downto 0)=>JOYSTICK1(5 downto 0),
			joystick2(5 downto 0)=>JOYSTICK2(5 downto 0),
			PPI_portC(3 downto 0)=>portC(3 downto 0),
			PS2_CLK=>PS2_CLK,
			PS2_DATA=>PS2_DATA,
			key_reset=>key_reset,
			PPI_portA(7 downto 0)=>kbd_out(7 downto 0)
		);

end BEHAVIORAL;


