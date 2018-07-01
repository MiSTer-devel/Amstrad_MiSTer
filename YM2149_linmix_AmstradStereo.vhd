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
-- FPGAmstrad_amstrad_motherboard.YM2149 patched for Amstrad
-- AB|BC stereo channels (as in Amstrad)
--------------------------------------------------------------------------------
--
-- A simulation model of YM2149 (AY-3-8910 with bells on)

-- Copyright (c) MikeJ - Jan 2005
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
-- The latest version of this file can be found at: www.fpgaarcade.com
--
-- Email support@fpgaarcade.com
--
-- Revision list
--
-- version 001 initial release
--
-- Clues from MAME sound driver and Kazuhiro TSUJIKAWA
--
-- These are the measured outputs from a real chip for a single Isolated channel into a 1K load (V)
-- vol 15 .. 0
-- 3.27 2.995 2.741 2.588 2.452 2.372 2.301 2.258 2.220 2.198 2.178 2.166 2.155 2.148 2.141 2.132
-- As the envelope volume is 5 bit, I have fitted a curve to the not quite log shape in order
-- to produced all the required values.
-- (The first part of the curve is a bit steeper and the last bit is more linear than expected)
--
-- NOTE, this component uses LINEAR mixing of the three analogue channels, and is only
-- accurate for designs where the outputs are buffered and not simply wired together.
-- The ouput level is more complex in that case and requires a larger table.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;

-- Amstrad : AB et BC stereo outputs.
entity YM2149 is
	generic (
		MOCK:boolean:=false
	);
  port (
  -- data bus
  I_DA                : in  std_logic_vector(7 downto 0);
  O_DA                : out std_logic_vector(7 downto 0);
  O_DA_OE_L           : out std_logic;
  -- control
  I_A9_L              : in  std_logic;
  I_A8                : in  std_logic;
  I_BDIR              : in  std_logic;
  I_BC2               : in  std_logic;
  I_BC1               : in  std_logic;
  I_SEL_L             : in  std_logic;

  O_AUDIO_AB             : out std_logic_vector(7 downto 0);
  O_AUDIO_BC             : out std_logic_vector(7 downto 0);
  -- port a
  I_IOA               : in  std_logic_vector(7 downto 0);
--  O_IOA               : out std_logic_vector(7 downto 0);
--  O_IOA_OE_L          : out std_logic;
  -- port b
--  I_IOB               : in  std_logic_vector(7 downto 0);
--  O_IOB               : out std_logic_vector(7 downto 0);
--  O_IOB_OE_L          : out std_logic;

  ENA                 : in  std_logic; -- clock enable for higher speed operation
  RESET_L             : in  std_logic;
  CLK                 : in  std_logic  -- note 6 Mhz
  );
end;

architecture RTL of YM2149 is
  type  array_16x8   is array (0 to 15) of std_logic_vector(7 downto 0);
  type  array_3x12   is array (1 to 3) of std_logic_vector(11 downto 0);

  signal cnt_div              : std_logic_vector(3 downto 0) := (others => '0');
  signal noise_div            : std_logic := '0';
  signal ena_div              : std_logic;
  signal ena_div_noise        : std_logic;
  signal poly17               : std_logic_vector(16 downto 0) := (others => '0');

  -- registers
  signal addr                 : std_logic_vector(7 downto 0);
  signal busctrl_addr         : std_logic;
  signal busctrl_we           : std_logic;
  signal busctrl_re           : std_logic;

  signal reg                  : array_16x8;
  signal env_reset            : std_logic;
  signal ioa_inreg            : std_logic_vector(7 downto 0);
  --signal iob_inreg            : std_logic_vector(7 downto 0);

  signal noise_gen_cnt        : std_logic_vector(4 downto 0);
  signal noise_gen_op         : std_logic;
  signal tone_gen_cnt         : array_3x12 := (others => (others => '0'));
  signal tone_gen_op          : std_logic_vector(3 downto 1) := "000";

  signal env_gen_cnt          : std_logic_vector(15 downto 0);
  signal env_ena              : std_logic;
  signal env_hold             : std_logic;
  signal env_inc              : std_logic;
  signal env_vol              : std_logic_vector(4 downto 0);

  signal tone_ena_l_AB           : std_logic;
  signal tone_src_AB             : std_logic;
  signal noise_ena_l_AB          : std_logic;
  signal chan_vol_AB             : std_logic_vector(4 downto 0);

  signal tone_ena_l_BC           : std_logic;
  signal tone_src_BC             : std_logic;
  signal noise_ena_l_BC          : std_logic;
  signal chan_vol_BC             : std_logic_vector(4 downto 0);

  signal dac_amp_AB              : std_logic_vector(7 downto 0);
  signal audio_mix_AB            : std_logic_vector(9 downto 0);
  signal audio_final_AB          : std_logic_vector(9 downto 0);
  signal dac_amp_BC              : std_logic_vector(7 downto 0);
  signal audio_mix_BC            : std_logic_vector(9 downto 0);
  signal audio_final_BC          : std_logic_vector(9 downto 0);
begin

do_mock:if MOCK generate
	O_DA<=I_IOA;
end generate;

dont_mock:if not(MOCK) generate

  -- cpu i/f
  p_busdecode            : process(I_BDIR, I_BC2, I_BC1, addr, I_A9_L, I_A8)
    variable cs : std_logic;
    variable sel : std_logic_vector(2 downto 0);
  begin
    -- BDIR BC2 BC1 MODE
    --   0   0   0  inactive
    --   0   0   1  address
    --   0   1   0  inactive
    --   0   1   1  read
    --   1   0   0  address
    --   1   0   1  inactive
    --   1   1   0  write
    --   1   1   1  read
    busctrl_addr <= '0';
    busctrl_we <= '0';
    busctrl_re <= '0';

    cs := '0';
    if (I_A9_L = '0') and (I_A8 = '1') and (addr(7 downto 4) = "0000") then
      cs := '1';
    end if;

--  protected static final int[] STATES = {
--    INACTIVE, LATCH, INACTIVE, READ, LATCH, INACTIVE, WRITE, LATCH
--  };
	 
    sel := (I_BDIR & I_BC2 & I_BC1);
    case sel is
      when "000" => null;						--IGNORED
      when "001" => busctrl_addr <= '1';	--IGNORED
      when "010" => null;
      when "011" => busctrl_re   <= cs;
      when "100" => busctrl_addr <= '1';	--IGNORED
      when "101" => null;						--IGNORED
      when "110" => busctrl_we   <= cs;
      when "111" => busctrl_addr <= '1';
      when others => null;
    end case;
  end process;

	-- OSEF : pas branché...
  p_oe                   : process(busctrl_re)
  begin
    -- if we are emulating a real chip, maybe clock this to fake up the tristate typ delay of 100ns
    O_DA_OE_L <= not (busctrl_re);
  end process;

  --
  -- LATCHED, useful when emulating a real chip in circuit. Nasty as gated clock.
  --
  p_waddr                : process(reset_l, clk) --busctrl_addr)
  begin
    -- looks like registers are latches in real chip, but the address is caught at the end of the address state.
    if (RESET_L = '0') then
      addr <= (others => '0');
    elsif falling_edge(clk) then
      if busctrl_addr='1' then
			addr <= I_DA;
		end if;
    end if;
  end process;

  p_wdata                : process(reset_l, clk, addr) --process(reset_l, busctrl_we, addr)
  begin
    if (RESET_L = '0') then
      reg <= (others => (others => '0'));
    elsif falling_edge(clk) then
		env_reset <= '0';
		if busctrl_we='1' then
        case addr(3 downto 0) is
          when x"0" => reg(0)  <= I_DA;
          when x"1" => reg(1)  <= I_DA;
          when x"2" => reg(2)  <= I_DA;
          when x"3" => reg(3)  <= I_DA;
          when x"4" => reg(4)  <= I_DA;
          when x"5" => reg(5)  <= I_DA;
          when x"6" => reg(6)  <= I_DA;
          when x"7" => reg(7)  <= I_DA;
          when x"8" => reg(8)  <= I_DA;
          when x"9" => reg(9)  <= I_DA;
          when x"A" => reg(10) <= I_DA;
          when x"B" => reg(11) <= I_DA;
          when x"C" => reg(12) <= I_DA;
          when x"D" => reg(13) <= I_DA; env_reset <= '1';
          when x"E" => reg(14) <= I_DA;
          when x"F" => reg(15) <= I_DA;
          when others => null;
        end case;
		  end if;
    end if;
  end process;
  
  p_rdata                : process(busctrl_re, addr, reg, ioa_inreg)
  begin
    O_DA <= (others => '1'); -- 'X'
    if (busctrl_re = '1') then -- not necessary, but useful for putting 'X's in the simulator
		if addr(7 downto 4)=x"0" then
			case addr(3 downto 0) is
			  when x"0" => O_DA <= reg(0) ;
			  when x"1" => O_DA <= "0000" & reg(1)(3 downto 0) ;
			  when x"2" => O_DA <= reg(2) ;
			  when x"3" => O_DA <= "0000" & reg(3)(3 downto 0) ;
			  when x"4" => O_DA <= reg(4) ;
			  when x"5" => O_DA <= "0000" & reg(5)(3 downto 0) ;
			  when x"6" => O_DA <= "000"  & reg(6)(4 downto 0) ;
			  when x"7" => O_DA <= reg(7) ;
			  when x"8" => O_DA <= "000"  & reg(8)(4 downto 0) ;
			  when x"9" => O_DA <= "000"  & reg(9)(4 downto 0) ;
			  when x"A" => O_DA <= "000"  & reg(10)(4 downto 0) ;
			  when x"B" => O_DA <= reg(11);
			  when x"C" => O_DA <= reg(12);
			  when x"D" => O_DA <= "0000" & reg(13)(3 downto 0);
			  when x"E" => if (reg(7)(6) = '0') then -- input
								  O_DA <= ioa_inreg;
								else
								  O_DA <= reg(14); -- read output reg
								end if;
			  when x"F" => if (Reg(7)(7) = '0') then
								  O_DA <= x"FF";
								else
								  O_DA <= reg(15);
								end if;
			  when others => null;
			end case;
		else
			O_DA <= (others => '1'); -- 'X'
		end if;
    end if;
  end process;
  --
  p_divider              : process
  begin
    wait until rising_edge(CLK);
    -- / 8 when SEL is high and /16 when SEL is low
    if (ENA = '1') then
      ena_div <= '0';
      ena_div_noise <= '0';
      if (cnt_div = "0000") then
        cnt_div <= (not I_SEL_L) & "111";
        ena_div <= '1';

        noise_div <= not noise_div;
        if (noise_div = '1') then
          ena_div_noise <= '1';
        end if;
      else
        cnt_div <= cnt_div - "1";
      end if;
    end if;
  end process;

  p_noise_gen            : process
    variable noise_gen_comp : std_logic_vector(4 downto 0);
    variable poly17_zero : std_logic;
  begin
    wait until rising_edge(CLK);

    if (reg(6)(4 downto 0) = "00000") then
      noise_gen_comp := "00000";
    else
      noise_gen_comp := (reg(6)(4 downto 0) - "1");
    end if;

    poly17_zero := '0';
    if (poly17 = "00000000000000000") then poly17_zero := '1'; end if;

    if (ENA = '1') then

      if (ena_div_noise = '1') then -- divider ena

        if (noise_gen_cnt >= noise_gen_comp) then
          noise_gen_cnt <= "00000";
          poly17 <= (poly17(0) xor poly17(2) xor poly17_zero) & poly17(16 downto 1);
        else
          noise_gen_cnt <= (noise_gen_cnt + "1");
        end if;
      end if;
    end if;
  end process;
  noise_gen_op <= poly17(0);

  p_tone_gens            : process
    variable tone_gen_freq : array_3x12;
    variable tone_gen_comp : array_3x12;
  begin
    wait until rising_edge(CLK);

    -- looks like real chips count up - we need to get the Exact behaviour ..
    tone_gen_freq(1) := reg(1)(3 downto 0) & reg(0);
    tone_gen_freq(2) := reg(3)(3 downto 0) & reg(2);
    tone_gen_freq(3) := reg(5)(3 downto 0) & reg(4);
    -- period 0 = period 1
    for i in 1 to 3 loop
      if (tone_gen_freq(i) = x"000") then
        tone_gen_comp(i) := x"000";
      else
        tone_gen_comp(i) := (tone_gen_freq(i) - "1");
      end if;
    end loop;

    if (ENA = '1') then
      for i in 1 to 3 loop
        if (ena_div = '1') then -- divider ena

          if (tone_gen_cnt(i) >= tone_gen_comp(i)) then
            tone_gen_cnt(i) <= x"000";
            tone_gen_op(i) <= not tone_gen_op(i);
          else
            tone_gen_cnt(i) <= (tone_gen_cnt(i) + "1");
          end if;
        end if;
      end loop;
    end if;
  end process;

  p_envelope_freq        : process
    variable env_gen_freq : std_logic_vector(15 downto 0);
    variable env_gen_comp : std_logic_vector(15 downto 0);
  begin
    wait until rising_edge(CLK);
    env_gen_freq := reg(12) & reg(11);
    -- envelope freqs 1 and 0 are the same.
    if (env_gen_freq = x"0000") then
      env_gen_comp := x"0000";
    else
      env_gen_comp := (env_gen_freq - "1");
    end if;

    if (ENA = '1') then
      env_ena <= '0';
      if (ena_div = '1') then -- divider ena
        if (env_gen_cnt >= env_gen_comp) then
          env_gen_cnt <= x"0000";
          env_ena <= '1';
        else
          env_gen_cnt <= (env_gen_cnt + "1");
        end if;
      end if;
    end if;
  end process;

  p_envelope_shape       : process(CLK)
    variable is_bot    : boolean;
    variable is_bot_p1 : boolean;
    variable is_top_m1 : boolean;
    variable is_top    : boolean;
  begin
        -- envelope shapes
        -- C AtAlH
        -- 0 0 x x  \___
        --
        -- 0 1 x x  /___
        --
        -- 1 0 0 0  \\\\
        --
        -- 1 0 0 1  \___
        --
        -- 1 0 1 0  \/\/
        --           ___
        -- 1 0 1 1  \
        --
        -- 1 1 0 0  ////
        --           ___
        -- 1 1 0 1  /
        --
        -- 1 1 1 0  /\/\
        --
        -- 1 1 1 1  /___
    if rising_edge(CLK) then
		 if (env_reset = '1') then
			-- load initial state
			if (reg(13)(2) = '0') then -- attack
			  env_vol <= "11111";
			  env_inc <= '0'; -- -1
			else
			  env_vol <= "00000";
			  env_inc <= '1'; -- +1
			end if;
			env_hold <= '0';
		else
	 
			is_bot    := (env_vol = "00000");
			is_bot_p1 := (env_vol = "00001");
			is_top_m1 := (env_vol = "11110");
			is_top    := (env_vol = "11111");

			if (ENA = '1') then
			  if (env_ena = '1') then
				 if (env_hold = '0') then
					if (env_inc = '1') then
					  env_vol <= (env_vol + "00001");
					else
					  env_vol <= (env_vol + "11111");
					end if;
				 end if;

				 -- envelope shape control.
				 if (reg(13)(3) = '0') then
					if (env_inc = '0') then -- down
					  if is_bot_p1 then env_hold <= '1'; end if;
					else
					  if is_top then env_hold <= '1'; end if;
					end if;
				 else
					if (reg(13)(0) = '1') then -- hold = 1
					  if (env_inc = '0') then -- down
						 if (reg(13)(1) = '1') then -- alt
							if is_bot    then env_hold <= '1'; end if;
						 else
							if is_bot_p1 then env_hold <= '1'; end if;
						 end if;
					  else
						 if (reg(13)(1) = '1') then -- alt
							if is_top    then env_hold <= '1'; end if;
						 else
							if is_top_m1 then env_hold <= '1'; end if;
						 end if;
					  end if;

					elsif (reg(13)(1) = '1') then -- alternate
					  if (env_inc = '0') then -- down
						 if is_bot_p1 then env_hold <= '1'; end if;
						 if is_bot    then env_hold <= '0'; env_inc <= '1'; end if;
					  else
						 if is_top_m1 then env_hold <= '1'; end if;
						 if is_top    then env_hold <= '0'; env_inc <= '0'; end if;
					  end if;
					end if;

				 end if;
			  end if;
		  end if;
      end if;
    end if;
  end process;
  
  p_chan_mixer           : process(cnt_div, reg, tone_gen_op)
  begin
    tone_ena_l_AB  <= '1'; tone_src_AB <= '1';
    noise_ena_l_AB <= '1'; chan_vol_AB <= "00000";
    tone_ena_l_BC  <= '1'; tone_src_BC <= '1';
    noise_ena_l_BC <= '1'; chan_vol_BC <= "00000";
    case cnt_div(1 downto 0) is
      when "00" =>
		  --A
        tone_ena_l_AB  <= reg(7)(0); tone_src_AB <= tone_gen_op(1); chan_vol_AB <=  reg(8)(4 downto 0);
        noise_ena_l_AB <= reg(7)(3);
		  --C
        tone_ena_l_BC  <= reg(7)(2); tone_src_BC <= tone_gen_op(3); chan_vol_BC <= reg(10)(4 downto 0);
        noise_ena_l_BC <= reg(7)(5);
      when "01" =>
		  --B
        tone_ena_l_BC  <= reg(7)(1); tone_src_BC <= tone_gen_op(2); chan_vol_BC <=  reg(9)(4 downto 0);
        noise_ena_l_BC <= reg(7)(4);
		  --B
        tone_ena_l_AB  <= reg(7)(1); tone_src_AB <= tone_gen_op(2); chan_vol_AB <=  reg(9)(4 downto 0);
        noise_ena_l_AB <= reg(7)(4);
      when "10" => null;
      when "11" => null; -- tone gen outputs become valid on this clock
	  when others => null;
    end case;
  end process;

  p_op_mixer_AB             : process
    variable chan_mixed : std_logic;
    variable chan_amp : std_logic_vector(4 downto 0);
	 variable O_AUDIO_AB_mem:std_logic_vector(7 downto 0):=x"00";
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then

      chan_mixed := (tone_ena_l_AB or tone_src_AB) and (noise_ena_l_AB or noise_gen_op);

      chan_amp := (others => '0');
      if (chan_mixed = '1') then
        if (chan_vol_AB(4) = '0') then
          if (chan_vol_AB(3 downto 0) = "0000") then -- nothing is easy ! make sure quiet is quiet
            chan_amp := "00000";
          else
            chan_amp := chan_vol_AB(3 downto 0) & '1'; -- make sure level 31 (env) = level 15 (tone)
          end if;
        else
          chan_amp := env_vol(4 downto 0);
        end if;
      end if;

      dac_amp_AB <= x"00";
      case chan_amp is
        when "11111" => dac_amp_AB <= x"FF";
        when "11110" => dac_amp_AB <= x"D9";
        when "11101" => dac_amp_AB <= x"BA";
        when "11100" => dac_amp_AB <= x"9F";
        when "11011" => dac_amp_AB <= x"88";
        when "11010" => dac_amp_AB <= x"74";
        when "11001" => dac_amp_AB <= x"63";
        when "11000" => dac_amp_AB <= x"54";
        when "10111" => dac_amp_AB <= x"48";
        when "10110" => dac_amp_AB <= x"3D";
        when "10101" => dac_amp_AB <= x"34";
        when "10100" => dac_amp_AB <= x"2C";
        when "10011" => dac_amp_AB <= x"25";
        when "10010" => dac_amp_AB <= x"1F";
        when "10001" => dac_amp_AB <= x"1A";
        when "10000" => dac_amp_AB <= x"16";
        when "01111" => dac_amp_AB <= x"13";
        when "01110" => dac_amp_AB <= x"10";
        when "01101" => dac_amp_AB <= x"0D";
        when "01100" => dac_amp_AB <= x"0B";
        when "01011" => dac_amp_AB <= x"09";
        when "01010" => dac_amp_AB <= x"08";
        when "01001" => dac_amp_AB <= x"07";
        when "01000" => dac_amp_AB <= x"06";
        when "00111" => dac_amp_AB <= x"05";
        when "00110" => dac_amp_AB <= x"04";
        when "00101" => dac_amp_AB <= x"03";
        when "00100" => dac_amp_AB <= x"03";
        when "00011" => dac_amp_AB <= x"02";
        when "00010" => dac_amp_AB <= x"02";
        when "00001" => dac_amp_AB <= x"01";
        when "00000" => dac_amp_AB <= x"00";
        when others => null;
      end case;

      if (cnt_div(1 downto 0) = "10") then
        audio_mix_AB   <= (others => '0');
        audio_final_AB <= audio_mix_AB;
      else
        audio_mix_AB   <= audio_mix_AB + ("00" & dac_amp_AB);
      end if;

      if (RESET_L = '0') then
        O_AUDIO_AB_mem(7 downto 0) := "00000000";
      else
        if (audio_final_AB(9) = '0') then
          O_AUDIO_AB_mem(7 downto 0) := audio_final_AB(8 downto 1);
        else -- clip
          O_AUDIO_AB_mem(7 downto 0) := x"FF";
        end if;
      end if;
		O_AUDIO_AB<=O_AUDIO_AB_mem;
    end if;
  end process;
  
  p_op_mixer_BC             : process
    variable chan_mixed : std_logic;
    variable chan_amp : std_logic_vector(4 downto 0);
	 variable O_AUDIO_BC_mem:std_logic_vector(7 downto 0):=x"00";
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then

      chan_mixed := (tone_ena_l_BC or tone_src_BC) and (noise_ena_l_BC or noise_gen_op);

      chan_amp := (others => '0');
      if (chan_mixed = '1') then
        if (chan_vol_BC(4) = '0') then
          if (chan_vol_BC(3 downto 0) = "0000") then -- nothing is easy ! make sure quiet is quiet
            chan_amp := "00000";
          else
            chan_amp := chan_vol_BC(3 downto 0) & '1'; -- make sure level 31 (env) = level 15 (tone)
          end if;
        else
          chan_amp := env_vol(4 downto 0);
        end if;
      end if;

      dac_amp_BC <= x"00";
      case chan_amp is
        when "11111" => dac_amp_BC <= x"FF";
        when "11110" => dac_amp_BC <= x"D9";
        when "11101" => dac_amp_BC <= x"BA";
        when "11100" => dac_amp_BC <= x"9F";
        when "11011" => dac_amp_BC <= x"88";
        when "11010" => dac_amp_BC <= x"74";
        when "11001" => dac_amp_BC <= x"63";
        when "11000" => dac_amp_BC <= x"54";
        when "10111" => dac_amp_BC <= x"48";
        when "10110" => dac_amp_BC <= x"3D";
        when "10101" => dac_amp_BC <= x"34";
        when "10100" => dac_amp_BC <= x"2C";
        when "10011" => dac_amp_BC <= x"25";
        when "10010" => dac_amp_BC <= x"1F";
        when "10001" => dac_amp_BC <= x"1A";
        when "10000" => dac_amp_BC <= x"16";
        when "01111" => dac_amp_BC <= x"13";
        when "01110" => dac_amp_BC <= x"10";
        when "01101" => dac_amp_BC <= x"0D";
        when "01100" => dac_amp_BC <= x"0B";
        when "01011" => dac_amp_BC <= x"09";
        when "01010" => dac_amp_BC <= x"08";
        when "01001" => dac_amp_BC <= x"07";
        when "01000" => dac_amp_BC <= x"06";
        when "00111" => dac_amp_BC <= x"05";
        when "00110" => dac_amp_BC <= x"04";
        when "00101" => dac_amp_BC <= x"03";
        when "00100" => dac_amp_BC <= x"03";
        when "00011" => dac_amp_BC <= x"02";
        when "00010" => dac_amp_BC <= x"02";
        when "00001" => dac_amp_BC <= x"01";
        when "00000" => dac_amp_BC <= x"00";
        when others => null;
      end case;

      if (cnt_div(1 downto 0) = "10") then
        audio_mix_BC   <= (others => '0');
        audio_final_BC <= audio_mix_BC;
      else
        audio_mix_BC   <= audio_mix_BC + ("00" & dac_amp_BC);
      end if;

      if (RESET_L = '0') then
        O_AUDIO_BC_mem(7 downto 0) := "00000000";
      else
        if (audio_final_BC(9) = '0') then
          O_AUDIO_BC_mem(7 downto 0) := audio_final_BC(8 downto 1);
        else -- clip
          O_AUDIO_BC_mem(7 downto 0) := x"FF";
        end if;
      end if;
		O_AUDIO_BC<=O_AUDIO_BC_mem;
    end if;
  end process;

--  p_io_ports             : process(reg)
--  begin
--    --O_IOA <= reg(14);
--
--    --O_IOA_OE_L <= not reg(7)(6);
----    O_IOB <= reg(15);
----    O_IOB_OE_L <= not reg(7)(7);
--  end process;

  p_io_ports_inreg       : process
  begin
    wait until rising_edge(CLK);
    ioa_inreg <= I_IOA;
--    iob_inreg <= I_IOB;
  end process;
  
end generate;
end architecture RTL;
