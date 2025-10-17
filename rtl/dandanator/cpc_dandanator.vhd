----------------------------------------------------------------------------------
--
-- Company: 		12Tone
-- Engineer: 		Daniel Leon - Dandare
-- 
-- Create Date:   2019/01/10
-- Design Name: 	CPC_Dandanator_Mini
-- Module Name:   CPC Dandanator - Behavioral 
-- Project Name: 	CPC Dandanator Mini
-- Target Devices:Xilinx xc9572xl 
-- Tool versions: ISE 14.7
-- Description: 
--
-- Dependencies: 
-- Revision 1.8 -> Change in Romdis for 664 and 1st gen 6128 Rom 7
--						 Minor cosmetic changes and WaitSignal2 insertion (commented)
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CPC_Dandanator is
	port ( Button: in std_logic;
			 Button2: in std_logic; 
			 nRomEN: in std_logic;	-- NEW in HW Version 1.3
			 nM1 : in std_logic;
			 nMreq: in std_logic;
			 nWr: in std_logic;
			 nRd: in std_logic;
             clk: in std_logic;
			 ceP: in std_logic;
             ceN: in std_logic; 
			 Rdy: in std_logic;
			 A15: in std_logic;
			 A14: in std_logic;
			 A13: in std_logic;		-- NEW IN 1.4
			 CHG_Txd: in std_logic;
			 nRst: in std_logic; -- FIXED in HW version 1.3 
			 DataBusIn : in std_logic_vector(7 downto 0);
             DataBusOut : out std_logic_vector(7 downto 0);
			 EXP : in std_logic;		-- NEW IN 1.4
			 
			 nNMI : out std_logic := 'Z';  -- CORRECTED FOR 1.3 and 1.4
			
			 Romdis : out std_logic := 'Z'; 
			 Ramdis : out std_logic := 'Z';
			 nEp_Ce: out std_logic := '1';
			 nEp_Wr: out std_logic := '1';
			 Ep_A18_14 : out std_logic_vector (4 downto 0) := "00000";
			 CHG_Rxd: out std_logic := '1');
	end CPC_Dandanator;

architecture Behavioral of CPC_Dandanator is

	type ZoneArray is array (0 to 1) of std_logic_vector(4 downto 0); -- ZoneArray is the slot selection for the eeprom memory (2 simultaneous slots) + Alternate Slot 0
	shared variable FRZone : std_logic_vector (1 downto 0); -- This will hold the FollowRomE lower bits for zone0 -> so available slots are 28,29,30 and 31 for this zone.
	shared variable WaitSignal : std_logic :='1'; -- Sync wait with CPC so fetch is done in the right place
   --shared variable WaitSignal2 : std_logic :='1'; -- Sync wait with CPC so data (write) fetch is done in the right place
	
	shared variable OpFetchD: std_logic_vector(7 downto 0); -- Z80 Op fetched from the bus on M1 cycle
	shared variable DataFetchD: std_logic_vector (7 downto 0); -- Data fetched from the bus during Memory Read cycle
	signal OpReady: bit := '0'; -- A new Op has been captured from the bus during a M1 Cycle
	signal RETOpCode: bit := '0'; -- The captured Z80 Op is a "RET" (0xC9)
	signal LDAHLOpCode : bit := '0'; -- The captured Z80 Op is "LD A,(HL)" (0x7E)
	signal CmdTrigger: bit := '0'; -- A sequence of Dandanator Command has been detected
	signal DDNTR_CommandReady: std_logic := '0'; -- full dandanator command is ready for process (opcode and data)
	shared variable FDCnt : natural range 0 to 3 := 0;	-- Counter for trigger. Any consecutive number of FD Prefix > 2 will trigger the command
	signal Disable_Commands: std_logic := '0'; -- Disable Dandanator commands until reset
	
	shared variable Dly_ZoneSlotCE: std_logic_vector(1 downto 0) := "00"; -- Delayed action : ZoneSlotCE
	shared variable Dly_ZoneAlloc:  std_logic_vector(1 downto 0) := "00"; -- Delayed action: high bit (A15) of zone allocation in memoy map. A14 is always 0
	shared variable Dly_ReqDisable : std_logic := '0'; -- Delayed action :Request to Disable Dandanator commands
	shared variable Dly_FollowRomEN : std_logic := '0'; -- Delayed action : Request to activate FollowromEn
	shared variable RetWait : std_logic := '0'; -- Wait for RET signal
	shared variable SerialOps : std_logic :='0'; -- Serial operations enable/disable
	shared variable nWrE: std_logic := '1'; -- Status for allowing/ban eeprom write operations
	shared variable RXLineStat: std_logic := '1'; -- Status of CH340G RX line (ie: CPC Transmit)
	shared variable FollowRomEN: std_logic := '0'; -- Only map Zones in Rom Area if RomEN is active
	shared variable ZoneSlotCE: bit_vector (1 downto 0):= "10"; -- Status of Ep_Ce as per slot operations
	shared variable ZoneAlloc: bit_vector (1 downto 0) := "00"; -- high bit (A15) of zone allocation in memoy map. A14 is always 0
	shared variable ZoneSlotN: ZoneArray; -- Hold of slots to zones mapping
	
	signal nEepAct : std_logic := '1'; -- Intermediate var - Optimize?
	signal nEpChipE: std_logic := '1'; -- Holds the status for Eeprom Activation output (CE)
	signal nm1delay:std_logic := '1'; -- used to skip clk cycles in M1
	signal BusHack: std_logic := '0'; -- Replace bus contents on ld a,(hl)
	

	begin

		process (clk, ceN, Rdy)										-- Set wait detection as in Z80 in M1 and WR and RD
		-- ---------------------------------------------------------------	
			begin
                if rising_edge(clk) then
                    if ceN = '1' then
                        WaitSignal:=Rdy;
                    end if;
				end if;
			end process;
		
		
		
		process (clk, ceP, nRst)										-- Fetch OpCode
		-- ---------------------------------------------------------------	

			begin	
clk1 :    if rising_edge(clk) then							
cep1:          if ceP = '1' then
rstchk1: 	 if nRst='1' then									-- Sync Reset
				   nm1delay <= nM1;								-- M1 opcode in is in rising of T3
nm1rd:			if (nRd='0' and nm1delay='0' and nMreq='0' and WaitSignal='1') then -- m1delay forces out the first rising with M1=0, ie: T2
					  OpFetchD := DataBusIn;						-- Capture the databus, OpCode
					  OpReady <= '1';								-- Set OpCode as ready
checkret:		  if DatabusIn = x"C9" then					-- Signal RET for delayed action (C9 Opcode)
					    RETOpCode<='1';							-- Warning, SET 1,C - SET 1,(IX+n),C - SET 1, (IY+N),C - DDC9 nop - FDC9 nop - EDC9 nop...
					  else											-- ... Also trigger RETOpcode
						 RETOpCode<='0';	
					  end if checkret;
checkldahl:		  if DatabusIn = x"7E" then					-- Signal LDAHL for data substitution (7E Opcode)
					    LDAHLOpCode<='1';						-- Warning, LD A,(IX+n) - LD A,(IY+n) - BIT 7,(HL) - BIT 7,(IX+n), BIT 7, (IY+n) also..
					  else											-- ..Altered by bushack
						 LDAHLOpCode<='0';	
					  end if checkldahl;						
					else
					  OpReady <='0';								-- Not new opfetch in rising edge.
					end if nm1rd;	
			    else		 											-- Reset is active
 				   OpReady<='0';
				   RETOpCode<='0';
				   LDAHLOpCode<='0';
			    end if rstchk1;
               end if cep1;
			  end if clk1;		
			end process; 
						
			
			
		process (clk, ceN, nRst)										-- Trigger Detect
		-- ---------------------------------------------------------------		
			begin
clk2:	  if rising_edge(clk) then
cen1:       if ceN = '1' then
rstchk3:     if nRst='1' then
oprdychk:	   if OpReady='1' then 							-- New Instruction										 
chktrig:			  if OpFetchD = x"FD"  then				-- 0xFD Prefix
						 if FDCnt<3 then
						   FDCnt:= FDCnt+1;						-- Increment FD counter
					    end if; 
						 CmdTrigger <= '0';						-- and clear Cmd Trigger
					  else
chkcnt:		 	    if (FDCnt>2) then		 				-- Trigger instruction
						   CmdTrigger <= '1';					-- Set/ Reset Command Trigger
						 else 
						   CmdTrigger <= '0';
						 end if chkcnt;	
					    FDCnt := 0;								-- Reset Trigger count if not an FD opfetch, but do not clear cmdTrigger until next falling edge
					  end if chktrig;		
				   end if oprdychk;
			    else													-- On reset -> Reset Trigger counter and Cmd Trigger
				   FDCnt:=0;
					CmdTrigger<='0';
			    end if  rstchk3;	
               end if cen1;
			  end if clk2;
			end process;	
			
			
			
		process (clk, ceP, nRst)										-- Command data (capture databus on Memory Read cycle)
		-- ---------------------------------------------------------------	
			begin
clk3:	  if rising_edge(clk) then
cep2:      if ceP = '1' then
rstchk4:     if nRst='1' then
wrchk:			if nMreq='0' and nWr='0' and CmdTrigger='1' and WaitSignal= '1' then -- May we use WaitSignal2?
						DataFetchD:=DataBusIn;
						DDNTR_CommandReady<='1';
					else
						DDNTR_CommandReady<='0';
					end if wrchk;
			    else
				   DDNTR_CommandReady<='0';
			    end if rstchk4;
               end if cep2;
			  end if clk3;
			end process;




		process (clk, ceN, nRst, Button)								-- Commands
		-- ---------------------------------------------------------------
			begin
clk4:	  if rising_edge(clk) then
cen2:       if ceN = '1' then
rstchk5:     if nRst='1' then	
waitret:		  if RETOpCode='0' or RetWait='0' then
dischk: 		    if Disable_Commands='0' then
cmdrdychk:		   if DDNTR_CommandReady = '1' then
					     RetWait:='0'; -- Always clear delayed action if there is a command in between
opcase:				  case OpFetchD is
							when x"77" =>	-- ld (iy+n),a (Configuration) 77
dtcase:						    case DataFetchD(7) is
									  when '0'  => SerialOps:=DataFetchD(0);
														nWrE:=not DataFetchD(1);
													   RXLineStat:=DataFetchD(2);
														FRZone(0):=DataFetchD(3);
														FRZone(1):=DataFetchD(4);
									  when others=> 
immdly:												if DataFetchD(6) = '1' then	-- if actions are waiting for a RET opcode to be executed
														  RetWait:='1';
														  Dly_ReqDisable:=DataFetchD(5);
														  Dly_FollowRomEN:=DataFetchD(4);		
														  Dly_ZoneAlloc:=DataFetchD(3 downto 2);
														  Dly_ZoneSlotCE:=DataFetchD(1 downto 0);
														else			-- else actions are executed immediately
														  RetWait:='0';
														  Disable_Commands<=DataFetchD(5);
														  ZoneAlloc :=  to_bitvector(DataFetchD(3 downto 2));
														  ZoneSlotCE := to_bitvector(DataFetchD(1 downto 0));
														end if immdly;
								end case dtcase;
							when x"70" =>			-- ld (iy+n),b (zone 0) 70
								ZoneSlotCE(0) := to_bit(DataFetchD(5));
								ZoneSlotN(0) := DataFetchD(4 downto 0);									
							when x"71" =>			-- ld (iy+n),c (zone 1) 71
								ZoneSlotCE(1) := to_bit(DataFetchD(5));
								ZoneSlotN(1) := DataFetchD(4 downto 0);										 
							when others =>
								    --  Shouldn't arrive here under normal code operation from Z80
						 end case opcase; 
					  end if cmdrdychk;
					end if dischk;	
				  else -- at this point, CPLD was waiting for RET and Fetched Op is a RET
				    RetWait:='0'; -- Reset Wait Status and execute delayed commands
				    ZoneSlotCE := to_bitvector(Dly_ZoneSlotCE);
				    ZoneAlloc := to_bitvector(Dly_ZoneAlloc);
				    Disable_Commands <= Dly_ReqDisable;
				    FollowRomEN := Dly_FollowRomEN;
				    if Dly_FollowRomEN = '1' then
				      ZoneSlotN(0)(1 downto 0) := FRZone;		-- Select slot for ZONE0 FollowROMEN
					  ZoneSlotN(0)(4 downto 2) :="111";
				    end if;
			      end if waitret; 
			    else
				  SerialOps:='0';
				  nWrE:='1';
				  if Button='1' then 
				    ZoneSlotN:=("00000","00000");
				 else 
				    ZoneSlotN:=("11111","00000");
				  end if;
				  if Button2='1' then 
				    ZoneSlotCE:="10";
				  else
				    ZoneSlotCE:="11";
				  end if;	
				  ZoneAlloc:="00";
				  FRZone:="00";
				  RXLineStat:='1';
				  FollowRomEN:='0';
				  Disable_Commands<='0';
				  RetWait:='0';
				  Dly_FollowRomEN:='0';
				  Dly_ReqDisable:='0';
				  Dly_ZoneSlotCE:="00";
				  Dly_ZoneAlloc:="00";
			    end if rstchk5;	
               end if cen2;
			  end if clk4;	
			end process;
			
			

	-- Eeprom activation mapper

	BusHack <= '1' when nM1='1' and LDAHLOpCode='1' and nMreq='0' and nRd='0' and SerialOps='1' else
				  '0';
	
	nEepAct	<= '1' when FollowRomEN='1' and nRomEN='1' and A14=A15  else -- this ensures dandanator is not activated in rom area when ROMEN is not active
					'0' when nMreq='0' and A14='0' and A15=to_stdulogic(ZoneAlloc(0)) and to_stdulogic(ZoneSlotCE(0))='0' else
					'0' when nMreq='0' and A14='1' and A15=to_stdulogic(ZoneAlloc(1)) and to_stdulogic(ZoneSlotCE(1))='0' else
					'1';
	
	nEp_Wr <= nWrE or nWr; -- Write is both WR from Z80 and variable from CPLD (eeprom ops)
	nEpChipE <= '0' when nEepAct='0' and nRd='0' and BusHack='0' else
					'0' when nEepAct='0' and nWrE='0' and nWr='0' and BusHack='0'else
					'1';  -- Activation of CE of External eeprom 	
	
	nEp_Ce  	<= nEpChipE; -- actual CE activation	
	
	Romdis 	<= '1' when BusHack='1' else
					'1' when nEpChipE='0' else -- if either CE is active or Bus is hacked, force internal RAM and ROM deactivation
					'Z';
	Ramdis 	<= '1' when BusHack='1' else
					 --not nEpChipE and not nRd; -- Only Ram on Reads. Make 6128 writes work as 464 writes 
				   '1' when nEpChipE='0' else   
					'Z';

	Ep_A18_14 	<= ZoneSlotN(0) when A14='0' and A15=to_stdulogic(ZoneAlloc(0)) else 	-- Actual Eeprom zone mapper of addresses		
						ZoneSlotN(1);

	CHG_Rxd <= RXLineStat;
	
		
	DatabusOut(7 downto 1) <= 	"0000000" when BusHack='1' else
									"ZZZZZZZ";
	DatabusOut(0) <=  CHG_Txd when BusHack='1' else
						'Z';
					
	end Behavioral;

			
			
