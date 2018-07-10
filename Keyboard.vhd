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

-----------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity KEYBOARD_controller is
	Port (
		CLK : in  STD_LOGIC;
		CE  : in  STD_LOGIC;
		scancode_in : in  STD_LOGIC_VECTOR (7 downto 0);
		fok : in  STD_LOGIC; -- tic
		press : out  STD_LOGIC:='0'; -- tic
		unpress : out  STD_LOGIC:='0'; -- tic
		keycode : out  STD_LOGIC_VECTOR (9 downto 0)  --scancode,e0,e1
	);
end KEYBOARD_controller;

architecture Behavioral of KEYBOARD_controller is

begin

process(CLK)
	variable keycode_mem:std_logic_vector(keycode'range);
	--variable press_mem : std_logic:='0';
	--variable unpress_mem : std_logic:='0';
	variable is_e0:std_logic:='0';
	variable is_e1:std_logic:='0';
	variable releasing:boolean:=false;
begin
	if rising_edge(CLK) then
		if CE='1' then
			press<='0';
			unpress<='0';
			if fok='1' then

--	00  Key Detection Error or Overrun Error for Scan Code Set 1,
--	    replaces last key in the keyboard buffer if the buffer is full. 
--	AA  BAT Completion Code, keyboard sends this to indicate the keyboard
--	    test was successful.
--	EE  Echo Response, response to the Echo command.
--	F0  Break Code Prefix in Scan Code Sets 2 and 3.
--	FA  Acknowledge, keyboard sends this whenever a valid command or
--	    data byte is received (except on Echo and Resend commands).
--	FC  BAT Failure Code, keyboard sends this to indicate the keyboard
--	    test failed and stops scanning until a response or reset is sent.
--	FE  Resend, keyboard request resend of data when data sent to it is
--	    invalid or arrives with invalid parity.
--	FF  Key Detection Error or Overrun Error for Scan Code Set 2 or 3,
--	    replaces last key in the keyboard buffer if the buffer is full.
--	id  Keyboard ID Response, keyboard sends a two byte ID after ACK'ing
--	    the Read ID command.  The byte stream contains 83AB in LSB, MSB
--	    order.  The keyboard then resumes scanning.
		
				if scancode_in= x"AA" or scancode_in= x"EE" or scancode_in = x"FA" or scancode_in = x"FC" or scancode_in= x"FE" then
					--error
					is_e0:='0';
					is_e1:='0';
				elsif scancode_in= x"00" or scancode_in= x"FF"  then
					--ignore (overrun)
				elsif releasing and not(scancode_in = x"F0" or scancode_in= x"E0" or scancode_in= x"E1") then
					-- we are relaxing key RX_ShiftReg
					releasing:=false;
					unpress<='1';
					if scancode_in = x"61" then
						-- x61 idem que x55
						keycode_mem:=is_e0 & is_e1 & x"55";
					else
						keycode_mem:=is_e0 & is_e1 & scancode_in;
					end if;
					keycode<=keycode_mem;
					is_e0:='0';
					is_e1:='0';
				else
					if scancode_in = x"F0" then
						-- let's relax
						-- and so do zap next packet !
						releasing:=true;
					elsif scancode_in = x"E0" then
						-- we don't care : next packet is F0
						is_e0:='1';
					elsif scancode_in = x"E1" then
						-- we don't care : next packet is F0
						is_e1:='1';
					else
						-- it's a key
						if scancode_in = x"61" then
							-- x61 idem que x55
							keycode_mem:=is_e0 & is_e1 & x"55";
						else
							keycode_mem:=is_e0 & is_e1 & scancode_in;
						end if;
						keycode<=keycode_mem;
						is_e0:='0';
						is_e1:='0';
						press<='1';
					end if;
				end if;
			end if;
		end if;
	end if;
end process;

end Behavioral;

-----------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity KEYBOARD_driver is
    Port ( 
		CLK : in  STD_LOGIC;
		CE  : in  STD_LOGIC;
		enable : in  STD_LOGIC;
		press : in STD_LOGIC;
		unpress : in STD_LOGIC;
		portC : in  STD_LOGIC_VECTOR (3 downto 0);
		joystick1 : in STD_LOGIC_VECTOR(5 downto 0);
		joystick2 : in STD_LOGIC_VECTOR(5 downto 0);
		keycode : in  STD_LOGIC_VECTOR (9 downto 0); -- e0 & e1 & scancode
		portA : out  STD_LOGIC_VECTOR (7 downto 0);
		key_reset : out std_logic:='0';
		key_reset_space : out std_logic:='0';
		key_nmi: out std_logic:='0'
	);
end KEYBOARD_driver;

architecture Behavioral of KEYBOARD_driver is
	type amstrad_decode_type is array(0 to 15,0 to 7) of STD_LOGIC_VECTOR(7 downto 0); --integer range 0 to 127;
	constant RESET_KEY:STD_LOGIC_VECTOR(7 downto 0):=x"7D"; -- page up
	constant RESET_KEY_SPACE:STD_LOGIC_VECTOR(7 downto 0):=x"29"; -- SPACE
	constant NMI_KEY:STD_LOGIC_VECTOR(7 downto 0):=x"78"; -- F11
	constant NO_KEY:STD_LOGIC_VECTOR(7 downto 0):=x"FF"; -- x"00" is also another candidate of "NO_KEY" in PC 102 keyboard
	constant amstrad_decode:amstrad_decode_type:=(
			(x"75",x"74",x"72",x"01",x"0B",x"04",x"69",x"7A"),--  0 ligne 19 /\ -> \/ 9 6 3 Enter . -- Enter is "End" here
			(x"6B",x"70",x"83",x"0A",x"03",x"05",x"06",x"09"), --  1 ligne 18 <= COPY 7 8 5 1 2 0
			(x"71",x"5B",x"5A",x"5D",x"0C",x"12",x"59",x"14"), --  2 ligne 17 CLR [ Enter ] 4 SHIFT_LEFT \ CRTL_LEFT
			(x"55",x"4E",x"54",x"4D",x"52",x"4C",x"4A",x"49"), --  3 ligne 16 _ - @ P + : ? > -- _ is mapped in right shift key, because it's a missing key in PC 102 keyboard, needed to play "holdup.dsk"
			(x"45",x"46",x"44",x"43",x"4B",x"42",x"3A",x"41"), --  4 ligne 15 0_ 9_ O I L K M <
			(x"3E",x"3D",x"3C",x"35",x"33",x"3B",x"31",x"29"), --  5 ligne 14 8_ 7_ U Y H J N SPACE
			(x"36",x"2E",x"2D",x"2C",x"34",x"2B",x"32",x"2A"), --  6 ligne 13 6_ 5_ R T G F B V
			(x"25",x"26",x"24",x"1D",x"1B",x"23",x"21",x"22"), --  7 ligne 12 4_ 3_ E W S D C X
			(x"16",x"1E",x"76",x"15",x"0D",x"1C",x"58",x"1A"), --  8 ligne 11 1_ 2_ ESC Q TAB A CAPSLOCK Z
			(NO_KEY,NO_KEY,NO_KEY,NO_KEY,NO_KEY,NO_KEY,NO_KEY,x"66"), --  9 ligne 2 DEL
			(others=>NO_KEY), -- 10 osef
			(others=>NO_KEY), -- 11 osef
			(others=>NO_KEY), -- 12 osef
			(others=>NO_KEY), -- 13 osef
			(others=>NO_KEY), -- 14 osef
			(others=>NO_KEY) -- 15 osef
	);
	type keyb_type is array(7 downto 0) of std_logic_vector(7 downto 0);
	signal keyb:keyb_type;
	signal joystick1_8:std_logic_vector(7 downto 0);
	signal joystick2_8:std_logic_vector(7 downto 0);
begin

	keybscan : process(CLK)
		variable keyb_mem:keyb_type:=(others=>(others=>'0'));
	begin
		keyb<=keyb_mem;
		if rising_edge(CLK) then
			if CE='1' then
				if RESET_KEY=keycode(7 downto 0) then
					if unpress='1' then
						key_reset<='0';
					elsif press='1' then
						key_reset<='1';
					end if;
				elsif NMI_KEY=keycode(7 downto 0) then
					if unpress='1' then
						key_nmi<='0';
					elsif press='1' then
						key_nmi<='1';
					end if;
				elsif unpress='1' then
					for i in keyb'range loop
						if keyb_mem(i)=keycode(7 downto 0) then
							keyb_mem(i):=(others=>'0');
						end if;
					end loop;
				elsif press='1' then
					-- that sucks but... it's about pressing 8 keys at the same time, saying that some keys are double-keys, and I generally do up+right+jump+fire
					if keyb_mem(0)=x"00" or keyb_mem(0)=keycode(7 downto 0) then
						keyb_mem(0):=keycode(7 downto 0);
					elsif keyb_mem(1)=x"00" or keyb_mem(1)=keycode(7 downto 0) then
						keyb_mem(1):=keycode(7 downto 0);
					elsif keyb_mem(2)=x"00" or keyb_mem(2)=keycode(7 downto 0) then
						keyb_mem(2):=keycode(7 downto 0);
					elsif keyb_mem(3)=x"00" or keyb_mem(3)=keycode(7 downto 0) then
						keyb_mem(3):=keycode(7 downto 0);
					elsif keyb_mem(4)=x"00" or keyb_mem(4)=keycode(7 downto 0) then
						keyb_mem(4):=keycode(7 downto 0);
					elsif keyb_mem(5)=x"00" or keyb_mem(5)=keycode(7 downto 0) then
						keyb_mem(5):=keycode(7 downto 0);
					elsif keyb_mem(6)=x"00" or keyb_mem(6)=keycode(7 downto 0) then
						keyb_mem(6):=keycode(7 downto 0);
						-- for killapede.dsk each key seems double entries : so up+left+fire comes here
						-- In fact no, you can do ESC ESC in killepede.dsk and then choose others keys,
						--except if you take back arrows+space keys strangely.
					elsif keyb_mem(7)=x"00" or keyb_mem(7)=keycode(7 downto 0) then
						keyb_mem(7):=keycode(7 downto 0);
					else
						-- cheater !
						keyb_mem:=(others=>(others=>'0'));
					end if;
				end if;
				if RESET_KEY_SPACE=keycode(7 downto 0) then
					if unpress='1' then
						key_reset_space<='0';
					elsif press='1' then
						key_reset_space<='1';
					end if;
				end if;
			end if;
		end if;
	end process;
	
	process(CLK)
	begin
		if rising_edge(CLK) then
			joystick1_8<="00" & joystick1(5) & joystick1(4) & joystick1(0) & joystick1(1) & joystick1(2) & joystick1(3);
			joystick2_8<="00" & joystick2(5) & joystick2(4) & joystick2(0) & joystick2(1) & joystick2(2) & joystick2(3);
		end if;
	end process;

	process(CLK)
		-- bad CLK to refresh keyboard102_pressing, it could be nicer having a sort of PS2_CLK
		--http://www.beyondlogic.org/keyboard/keybrd.htm
	begin
		if rising_edge(CLK) then
			if CE='1' then
				portA<=(others=>'1');
				if enable='1' then
					for i in 7 downto 0 loop
						portA(i)<='1';
						--joystick
						if conv_integer(portC)=9 then
							if joystick1_8(i)='1' then
								portA(i)<='0';
							end if;
						end if;
						if conv_integer(portC)=6 then
							if joystick2_8(i)='1' then
								portA(i)<='0';
							end if;
						end if;
						for j in 6 downto 0 loop
							if keyb(j)=amstrad_decode(conv_integer(portC) mod 16,i) then
								portA(i)<='0';
							end if;
						end loop;
					end loop;
				end if;
			end if;
		end if;
	end process;
end Behavioral;

-----------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.ALL;

entity joykeyb is
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
end joykeyb;

architecture rtl of joykeyb is
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

end rtl;
