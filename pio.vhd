--    {@{@{@{@{@{@
--  {@{@{@{@{@{@{@{@  This code is covered by CoreAmstrad synthesis r005.2
--  {@    {@{@    {@  A core of Amstrad CPC 6128 running on MiST-board platform
--  {@{@{@{@{@{@{@{@
--  {@  {@{@{@{@  {@  CoreAmstrad is implementation of FPGAmstrad on MiST-board
--  {@{@        {@{@   Contact : renaudhelias@gmail.com
--  {@{@{@{@{@{@{@{@   @see http://code.google.com/p/mist-board/
--    {@{@{@{@{@{@     @see FPGAmstrad at CPCWiki
--
--
--------------------------------------------------------------------------------
-- Mixage of source code from Tobi and DevilMarkus.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--                                                                          --
-- Copyright (c) 2009 Tobias Gubener                                        -- 
-- Subdesign CPC T-REX by TobiFlex                                          --
--                                                                          --
-- This source file is free software: you can redistribute it and/or modify --
-- it under the terms of the GNU General Public License as published        --
-- by the Free Software Foundation, either version 3 of the License, or     --
-- (at your option) any later version.                                      --
--                                                                          --
-- This source file is distributed in the hope that it will be useful,      --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of           --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            --
-- GNU General Public License for more details.                             --
--                                                                          --
-- You should have received a copy of the GNU General Public License        --
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.    --
--                                                                          --
------------------------------------------------------------------------------
------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity pio is
    port (
	addr			: in STD_LOGIC_VECTOR (1 downto 0);
	datain			: in STD_LOGIC_VECTOR (7 downto 0);
	cs				: in STD_LOGIC;
	iowr			: in STD_LOGIC;
	iord			: in STD_LOGIC;
	cpuclk			: in STD_LOGIC;
	
	PBI				: in STD_LOGIC_VECTOR (7 downto 0);
	--PAI CPC.java
	--readPort()
	-- case PPI_PORT_B:
	--        result = 0x5e | (crtc.isVSync() ? 0x01 : 0);
	--        break;
	-- case PSG_PORT_A:
	--        result = keyboard.readSelectedRow();
	--        break;
	PAI				: in STD_LOGIC_VECTOR (7 downto 0);		--Keyboarddaten
	PAO     		: out STD_LOGIC_VECTOR (7 downto 0);		--sounddaten
	PCO     		: out STD_LOGIC_VECTOR (7 downto 0);		--tastatur und steuerung
	DO		     	: out STD_LOGIC_VECTOR (7 downto 0)
    );
end pio;

architecture logic of pio is
begin

process (cpuclk)
	constant IO_WRITE:STD_LOGIC:='0';
	constant IO_READ:STD_LOGIC:='1';

	variable	PAdir		: STD_LOGIC:=IO_READ;
	variable	PBdir		: STD_LOGIC:=IO_READ;
	variable	PCHdir		: STD_LOGIC:=IO_READ;
	variable	PCLdir		: STD_LOGIC:=IO_READ;
	variable PBmode : std_logic:='0';
	variable PAmode : std_logic:='0';
	variable PAmode2 : std_logic:='0'; -- if 1 then PAmode is ignored : MODE 2.
	
	--variable	PDdir		: STD_LOGIC:=IO_WRITE;
	
	variable DO_mem :std_logic_vector(7 downto 0):=(others=>'1');
	
	-- PIO is the only one component using a "low state" RESET.
	
	-- (datasheet)
	-- Port A: One 8-bit data output latch/buffer and one 8-bit data input latch
	-- Port B: One 8-bit data input/output latch/buffer and one 8-bit data input buffer
	-- Port C: One 8-bit data output latch/buffer and one 8-bit data input buffer (no latch for input)
	
	--protected int output = 0xff;
	variable PAO_mem:std_logic_vector(7 downto 0):=(others=>'1');
	variable PBO_mem:std_logic_vector(7 downto 0):=(others=>'1');
	variable PCO_mem:std_logic_vector(7 downto 0):=(others=>'1');
	variable PDO_mem:std_logic_vector(7 downto 0):=(others=>'1'); -- PORT_CONTROL
	--protected int input = 0xff;
	variable PAI_mem:std_logic_vector(7 downto 0):=(others=>'1');
	variable PBI_mem:std_logic_vector(7 downto 0):=(others=>'1');
	variable PCI_mem:std_logic_vector(7 downto 0):=(others=>'1');
	
	variable PortC_status_maskH_0:std_logic_vector(3 downto 0);
	variable PortC_status_maskL_0:std_logic_vector(3 downto 0);
begin 

	
	IF rising_edge(cpuclk) THEN
	
		--mode 2: port A mode 2, port B mode 0, port C bits output-SUCCEEDED
		--mode 2: port A mode 2, port B mode 0, port C bits input-SUCCEEDED
		--1.mode 1: port A mode 1 (input), port B mode 0, port C bits output-SUCCEEDED
		--2.mode 1: port A mode 1 (output), port B mode 0, port C bits output-SUCCEEDED
		--3.mode 1: port A mode 1 (input), port B mode 0, port C bits input-SUCCEEDED
		--4.mode 1: port A mode 1 (output), port B mode 0, port C bits input-FAILED
		--mode 0: bit set-SUCCEEDED
		--mode 0: bit clear-SUCCEEDED
		--mode 0: psg control with bit set/reset-SUCCEEDED
		--mode 0: port a output latch r/w-SUCCEEDED
		--mode 0: port b output latch r/w-SUCCEEDED
		--mode 0: port c output latch r/w-SUCCEEDED
		--mode 0: port a control write reset test-SUCCEEDED
		--mode 0: port b control write reset test-SUCCEEDED
		--mode 0: port c control write reset test-SUCCEEDED
		--mode 0: port a read-SUCCEEDED
		--mode 0: port c read-SUCCEEDED
		--mode 0: port a read-SUCCEEDED
		--mode 0: port b read-SUCCEEDED
		--mode 0: port c read-SUCCEEDED
		--mode 0: port c mixed input/output-SUCCEEDED
		--mode 0: ppi port a output-SUCCEEDED
		--ppi control read-SUCCEEDED
		--ppi port reset from control-SUCCEEDED

		--(datasheet) 5. Port C Status Read
		--(datasheet) Input et Output de la doc sont inversé par rapport au tests,
		--input de test c'est IO_READ
		--ouput de test c'est IO_WRITE
		if PAMode2='1' then
			if PBMode='0' then
				--01111XXX - validated arnoldemu !
				--mode 2: port A mode 2, port B mode 0, port C bits output-SUCCEEDED
				--mode 2: port A mode 2, port B mode 0, port C bits input-SUCCEEDED
				PortC_status_maskH_0:="0000"; -- mask and
				PortC_status_maskL_0:="0111"; -- mask and
			elsif PBdir=IO_READ then -- Group B
				--01111101
				PortC_status_maskH_0:="0000"; -- mask and
				PortC_status_maskL_0:="0000"; -- mask and
			else --PBdir=IO_WRITE then -- Group B
				--01111111
				PortC_status_maskH_0:="0000"; -- mask and
				PortC_status_maskL_0:="0000"; -- mask and
			end if;
		elsif PAMode='1' and PAdir=IO_READ then -- Group A
			if PBMode='0' then
				--tableau ligne 2 : groupA[mode 1 output] groupB[mode 0]
				--1.mode 1: port A mode 1 (input), port B mode 0, port C bits output-SUCCEEDED
				-- bit7 et bit6 écrit via set/reset bit fonction.
				--3.mode 1: port A mode 1 (input), port B mode 0, port C bits input-SUCCEEDED
				--01XX1XXX
				PortC_status_maskH_0:="0011"; -- mask and 
				PortC_status_maskL_0:="0111"; -- mask and
			elsif PBdir=IO_READ then -- Group B
				--01XX1101
				PortC_status_maskH_0:="0011"; -- mask and
				PortC_status_maskL_0:="0000"; -- mask and
			else --PBdir=IO_WRITE then -- Group B
				--01XX1111
				PortC_status_maskH_0:="0011"; -- mask and
				PortC_status_maskL_0:="0000"; -- mask and
			end if;
		elsif PAMode='1' then -- and PAdir=IO_WRITE Group A
			if PBMode='0' then
				--tableau ligne 1 : groupeA[mode 1 input] groupB[mode 0]
				--2.mode 1: port A mode 1 (output), port B mode 0, port C bits output-SUCCEEDED
				--4.mode 1: port A mode 1 (output), port B mode 0, port C bits input-FAILED
				-- 07 -> 27
				-- 00 -> 20
				-- 10 -> 20
				-- 30 => 20
				--XX111XXX => arnoldemu : XX100XXX ?
				PortC_status_maskH_0:="1100"; -- mask and
				PortC_status_maskL_0:="0111"; -- mask and
			elsif PBdir=IO_READ then -- Group B
				--XX111101
				PortC_status_maskH_0:="1100"; -- mask and
				PortC_status_maskL_0:="0000"; -- mask and
			else --PBdir=IO_WRITE then -- Group B
				--XX111111
				PortC_status_maskH_0:="1100"; -- mask and
				PortC_status_maskL_0:="0000"; -- mask and
			end if;
		elsif PBMode='1' and PBdir=IO_READ then -- Group B
			--XXXXX101
			PortC_status_maskH_0:="1111"; -- mask and
			PortC_status_maskL_0:="1000"; -- mask and
		elsif PBMode='1' then -- and PBdir=IO_WRITE then -- Group B
			--XXXXX111
			PortC_status_maskH_0:="1111"; -- mask and
			PortC_status_maskL_0:="1000"; -- mask and
		elsE
			PortC_status_maskH_0:="1111"; -- mask and
			PortC_status_maskL_0:="1111"; -- mask and
		end if;
		
		
		
		
		
		
		
		
		IF cs='0' AND iowr='0' THEN -- writePort
		
			--mechanisms
			-- INTR : "the CPU when a terminal receives data from the CPU"
			-- INTR : to low level at the falling edge of the not(WR) signal
			-- Donc passer ici tout les INTR à 0 si INTE=1
		
			IF addr(1 downto 0)="00" THEN
				--ports[PORT_A].write()
				PAO_mem:=datain;
			elsif addr(1 downto 0)="01" THEN
				--ports[PORT_B].write()
				PBO_mem:=datain;
			elsIF addr(1 downto 0)="10" THEN
--CPC.java : mapping du PORT_C
--writePort()
--	case PPI_PORT_C:
--        psg.setBDIR_BC2_BC1(PSG_VALUES[value >> 6], ppi.readOutput(PPI8255.PORT_A));
--        keyboard.setSelectedRow(value & 0x0f);
--        break;
				--ports[PORT_C].write()
				--if (inputDevice == null) input = value;
				PCO_mem := (datain and (PortC_status_maskH_0 & PortC_status_maskL_0)) or (PCO_mem and not(PortC_status_maskH_0 & PortC_status_maskL_0));
				
				
				
			elsIF addr(1 downto 0)="11" then
				-- setControl(value);
				PDO_mem:=datain;
				if datain(7)='1' THEN
					-- choix du mode de travail des ports A, B et C
					
					-- Bit 0    IO-Cl    Direction for Port C, lower bits (always 0=Output in CPC)
					-- Bit 1    IO-B     Direction for Port B             (always 1=Input in CPC)
					-- Bit 2    MS0      Mode for Port B and Port Cl      (always zero in CPC)
					-- Bit 3    IO-Ch    Direction for Port C, upper bits (always 0=Output in CPC)
					-- Bit 4    IO-A     Direction for Port A             (0=Output, 1=Input)
					-- Bit 5,6  MS0,MS1  Mode for Port A and Port Ch      (always zero in CPC)
					-- Bit 7    SF       Must be "1" to setup the above bits
					
					--int mode = (value & 0x08) != 0 ? 0 : 0xf0;
					
					--*.setPortMode()
					PCHdir := datain(3); -- 0x08
					PCLdir := datain(0); -- 0x01
					PAdir  := datain(4); -- 0x10 ('1':IO_READ)
					PBdir  := datain(1); -- 0x02
					PBmode := datain(2);
					PAmode := datain(5);
					PAmode2:= datain(6);
					
					--CAUTION: Writing to PIO Control Register (with Bit7 set), automatically resets PIO Ports A,B,C to 00h each!
					--(datasheet) The output registers for ports A and C are cleared to 0 each time data is written in the command register and the mode is changed, but the port B state is undefined
					
					--Programmer le PPI remet à 0 la valeur du port de donnée
					--ports[PORT_A].write(0);
					PAO_mem:="00000000";
					--ports[PORT_B].write(0);
					PBO_mem:="00000000";
					--ports[PORT_C].write(0);
					PCO_mem:="00000000";
				elsE
					-- controle du Port C bit à bit

					-- Bit 0    B        New value for the specified bit (0=Clear, 1=Set)
					-- Bit 1-3  N0,N1,N2 Specifies the number of a bit (0-7) in Port C
					-- Bit 4-6  -        Not Used
					-- Bit 7    SF       Must be "0" in this case
					
					-- IOPort ioPort = ports[PORT_C];
-- int mask = 1 << ((value >> 1) & 0x07);
--
-- if ((value & 0x01) == 0) // Reset Bit
-- {
--	  ioPort.write(ioPort.readOutput() & (mask ^ 0xff));
-- } else // Set Bit
-- {
--	  ioPort.write(ioPort.readOutput() | mask);
-- }
				

				
					--JavaCPC ports[PORT_C].write() et Bit Set/Unset
					-- ioPort.readOutput() c'est pas getOutput() !!!
					--IF PCHdir=IO_READ THEN
					--	PCO_mem(7 downto 4):="0000";
					--end if;
					--IF PCLdir=IO_READ THEN
					--	PCO_mem(3 downto 0):="0000";
					--end if;

					
					CASE datain(3 downto 1) IS --int mask
						WHEN "000" => PCO_mem(0) := datain(0);
						WHEN "001" => PCO_mem(1) := datain(0);
						WHEN "010" => PCO_mem(2) := datain(0);
						WHEN "011" => PCO_mem(3) := datain(0);
						WHEN "100" => PCO_mem(4) := datain(0);
						WHEN "101" => PCO_mem(5) := datain(0);
						WHEN "110" => PCO_mem(6) := datain(0);
						WHEN OTHERS => PCO_mem(7) := datain(0);
					END CASE;
					
					
					--ports[PORT_C].write()
					--if datain(3)='1' then
					--	PCO_mem(3) := datain(0);
					--end if;
					--if datain(2)='1' then
					--	PCO_mem(2) := datain(0);
					--end if;
					--if datain(1)='1' then
					--	PCO_mem(1) := datain(0);
					--end if;
				end if;
			END IF;
			--PAO <= PAO_mem;
			--PCO<=PCO_mem;
			
			--mechanisms
			-- /OBF : "indicates that data is written to the specified port"
			-- /OBF : to low level at the rising edge of the not(WR) signal
			-- Donc passer ici tout les OBF à 0 si on écrit sur le port adéquat.

			
		END IF;

		
		IF cs='0' AND iord='0' THEN -- readPort
		
			--mechanisms
			-- INTR : "signal for the CPU of the data fetched into the input latch
			-- INTR : to low level at the falling edge of the not(RD) signal
			-- Donc passer ici tout les INTR à 0 si INTE=1
			
			

		
			IF addr(1 downto 0)="00" THEN	--Keyboarddaten
				--ports[PORT_A].read()
				--inputDevice.readPort()
				PAI_mem := PAI;
				IF PAdir=IO_READ THEN
					DO_mem := PAI_mem;
				elsE
					DO_mem := PAO_mem;
				END IF;	
			elsIF addr(1 downto 0)="01" THEN
				--ports[PORT_B].read()
				--inputDevice.readPort()
				PBI_mem := PBI;
				IF PBdir=IO_READ then
					DO_mem := PBI_mem;
				elsE
					DO_mem := PBO_mem;
				end if;
			elsIF addr(1 downto 0)="10" THEN
				--ports[PORT_C].read()
				--inputDevice.readPort()
				PCI_mem := x"FF";
				

				
				
				IF PCHdir=IO_READ THEN
					--DO_mem(7 downto 4) := (PCI_mem(7 downto 4) and PortC_status_maskH_0) or (PCO_mem(7 downto 4) and not(PortC_status_maskH_0)); -- PCI
					DO_mem(7 downto 4) := PCI_mem(7 downto 4) and PortC_status_maskH_0; -- PCI

					-- hack test arnoldemu :
					if PAMode2='0' and PAMode='1' and PAdir=IO_WRITE and PBMode='0' then -- Group A
						DO_mem(5):='1'; -- tape motor parasite in D(4) ?
					end if;
					
				elsE
					DO_mem(7 downto 4) := (PCO_mem(7 downto 4) and PortC_status_maskH_0) or (PCO_mem(7 downto 4) and not(PortC_status_maskH_0));
				end if;
				if PCLdir=IO_READ then
					--DO_mem(3 downto 0) := (PCI_mem(3 downto 0) and PortC_status_maskL_0) or (PCO_mem(3 downto 0) and not(PortC_status_maskL_0)); -- PCI
					DO_mem(3 downto 0) := PCI_mem(3 downto 0) and PortC_status_maskL_0; -- PCI
				elsE
					DO_mem(3 downto 0) := (PCO_mem(3 downto 0) and PortC_status_maskL_0) or (PCO_mem(3 downto 0) and not(PortC_status_maskL_0));
				end if;
				
			elsE
				
				--(datasheet) Illegal Condition
			
				--ports[PORT_D].read()
				--inputDevice.readPort()
				--PDI_mem := PDI;
				DO_mem:=PDO_mem; -- en IO_WRITE !
			END IF;
		else
			DO_mem:=x"FF";
		END IF;
		
		--mechanisms
		-- IBF : "indicates that data is fetched into the input latch"
		-- IBF : to low level at the rising edge of not(RD)
		-- Donc passer ici tout les IBF à 0
		
		-- If a port is defined as input, then it's output's will be at high impedance. A device connected to a port of the 8255 will see &FF on the port outputs. 
		if PAdir=IO_WRITE then
			PAO <= PAO_mem; --PPI8255.writePort()
		elsE
			PAO <= x"FF";
		end if;
		DO <= DO_mem; --PPI8255.readPort()
		if PCHdir=IO_WRITE then
			PCO(7 downto 4) <= PCO_mem(7 downto 4); --PPI8255.writePort()
		else
			PCO(7 downto 4) <= x"F";
		end if;
		if PCLdir=IO_WRITE then
			PCO(3 downto 0)<=PCO_mem(3 downto 0); --PPI8255.writePort()
		elsE
			PCO(3 downto 0) <= x"F";
		end if;
	END IF;
	
	
END process;
end logic;
