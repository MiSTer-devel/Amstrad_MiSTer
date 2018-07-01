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
-- FPGAmstrad_amstrad_motherboard.KEYBOARD_driver
-- see KEYBOARD_controller.vhd
-- see Keyboard.vhd
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity KEYBOARD_driver is
    Port ( CLK : in  STD_LOGIC;
           enable : in  STD_LOGIC;
			  press : in STD_LOGIC;
			  unpress : in STD_LOGIC;
           portC : in  STD_LOGIC_VECTOR (3 downto 0);
			  joystick1 : in STD_LOGIC_VECTOR(5 downto 0);
           joystick2 : in STD_LOGIC_VECTOR(5 downto 0);
           keycode : in  STD_LOGIC_VECTOR (9 downto 0); -- e0 & e1 & scancode
           portA : out  STD_LOGIC_VECTOR (7 downto 0);
			  key_reset : out std_logic:='0';
			  key_reset_space : out std_logic:='0'
			  );
end KEYBOARD_driver;

architecture Behavioral of KEYBOARD_driver is
		type amstrad_decode_type is array(0 to 15,0 to 7) of STD_LOGIC_VECTOR(7 downto 0); --integer range 0 to 127;
		constant RESET_KEY:STD_LOGIC_VECTOR(7 downto 0):=x"7D"; -- page up
		constant RESET_KEY_SPACE:STD_LOGIC_VECTOR(7 downto 0):=x"29"; -- SPACE
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
			if RESET_KEY=keycode(7 downto 0) then
				if unpress='1' then
					key_reset<='0';
				elsif press='1' then
					key_reset<='1';
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
	end process;
	
	process(CLK)
		variable joystick1_8mem:std_logic_vector(7 downto 0):=(others=>'0');
		variable joystick2_8mem:std_logic_vector(7 downto 0):=(others=>'0');
	begin
		if rising_edge(CLK) then
			joystick1_8mem(5 downto 0):=joystick1(5) & joystick1(4) & joystick1(0) & joystick1(1) & joystick1(2) & joystick1(3);
			joystick2_8mem(5 downto 0):=joystick2(5) & joystick2(4) & joystick2(0) & joystick2(1) & joystick2(2) & joystick2(3);
			joystick1_8<=joystick1_8mem;
			joystick2_8<=joystick2_8mem;
		end if;
	end process;
	
	process(CLK)
		-- bad CLK to refresh keyboard102_pressing, it could be nicer having a sort of PS2_CLK
		--http://www.beyondlogic.org/keyboard/keybrd.htm
	begin
			if rising_edge(CLK) then
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
	end process;
end Behavioral;