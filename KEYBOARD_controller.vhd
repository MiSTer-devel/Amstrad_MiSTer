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
-- FPGAmstrad_amstrad_motherboard.KEYBOARD_controller
-- see KEYBOARD_driver.vhd
-- see Keyboard.vhd
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity KEYBOARD_controller is
    Port ( CLK : in  STD_LOGIC;
				scancode_in : in  STD_LOGIC_VECTOR (7 downto 0);
           fok : in  STD_LOGIC; -- tic
           press : out  STD_LOGIC:='0'; -- tic
			  unpress : out  STD_LOGIC:='0'; -- tic
           keycode : out  STD_LOGIC_VECTOR (9 downto 0)); --scancode,e0,e1
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
end process;

end Behavioral;

