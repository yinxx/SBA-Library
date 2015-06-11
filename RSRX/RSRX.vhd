------------------------------------------------------------------------------
-- RxBuf_Adapter.vhd
-- Buffered RX UART Adapter for SBA
--
-- Version 0.6
-- Date: 20141210
-- 16 bits Data Interface
--
--
-- Author:
-- (c) Miguel A. Risco Castillo
-- email: mrisco@accesus.com
-- web page: http://mrisco.accesus.com
-- sba webpage: http://sba.accesus.com
--
-- This code, modifications, derivate
-- work or based upon, can not be used
-- or distributed without the
-- complete credits on this header and
-- the consent of the author.
--
-- This version is released under the GNU/GLP license
-- http://www.gnu.org/licenses/gpl.html
-- if you use this component for your research please
-- include the appropriate credit of Author.
--
-- For commercial purposes request the appropriate
-- license from the author.
--
--
-- Notes:
--
-- v0.6
-- Modify of Baud Clock Process
-- Move some variables to signals
--
-- v0.4
-- Merge the two versions of RX_Adapter, with and without fifo buffer
--
-- v0.3.1
-- Minor error about RxData assign corrected
--
-- v0.3
-- Add Address to read Status without clear flags and buffer
--
-- v0.2
-- Fist version cloned from RX_Adapter v0.2, adding buffer
--
------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use work.SBA_config.all;
use work.SBA_package.all;

entity RX_Adapter is
generic (baud:positive:=57600; buffsize:positive:=8);
port (
      -- SBA Bus Interface
      CLK_I : in std_logic;
      RST_I : in std_logic;
      WE_I  : in std_logic;
      ADR_I : in std_logic_vector;
      STB_I : in std_logic;
      DAT_O : out std_logic_vector;
      -- UART Interface;
      RX    : in std_logic    -- RX UART input
   );
end RX_Adapter;

architecture RX_Arch of RX_Adapter is

constant BaudDV : integer := integer(real(sysfrec)/real(baud))-1;
type tstate  is (IdleSt, CheckSt ,StartSt, DataSt, StopSt);   -- Rx Serial Communication States

signal RXSt   : tstate;
signal BDclk  : std_logic;
signal RxShift: std_logic_vector(7 downto 0);
alias  RxData : std_logic_vector(7 downto 0) is DAT_O(7 downto 0);
signal BitCnt : integer range 0 to 9;
signal RXRDYi : std_logic;
signal RXi    : std_logic;

-- FIFO types and signals ------
type TBufData is array (0 to buffsize-1) of std_logic_vector(7 downto 0);
signal BufData : TBufData;
signal InP, OutP : natural range 0 to buffsize-1;
signal BufLen : natural range 0 to buffsize;
--------------------------------

begin

------------------------------------------------------------------------------
RX0: if buffsize>0 generate
begin

RxFifoProc: process (RST_I,CLK_I)
Variable cnt : integer range 0 to BaudDV/2;
--Variable InP, OutP : natural range 0 to buffsize-1;
--Variable BufLen : natural range 0 to buffsize;
Variable BufEmpt, BufFull : Boolean;

-- FIFO Procedures -------------
procedure Push(data:in std_logic_vector) is
begin
  if not BufFull then
    BufData(InP) <= data;
    if (InP < BuffSize-1) then InP<=InP+1; else InP<=0; end if;
    BufLen<=BufLen+1;
  end if;
end;

procedure Pull is
begin
  if not BufEmpt then
    if (OutP < BuffSize-1) then OutP<=OutP+1; else OutP<=0; end if;
    BufLen<=BufLen-1;
  end if;
end;
--------------------------------

begin
  if RST_I='1' then
    RxSt <= IdleSt;
    cnt := 0;
    RxRDYi<='0';
    BufFull:=false;
    BufEmpt:=true;

-- FIFO
    InP<=0;
    OutP<=0;
    BufLen<=0;

    if (debug=1) then
      Report "RX Baud: " &  integer'image(baud) & " real: " &integer'image(integer(real(sysfrec)/real((BaudDV+1))));
    end if;

  elsif rising_edge(CLK_I) then
    case RxSt is
      when IdleSt  => if RXi = '0' then
                        RxSt <= CheckSt;
                        cnt := 0;
                      end if;
      when CheckSt => if RXi = '1' then
                        RxSt <= IdleSt;
                      elsif cnt = BaudDV/2 then
                        RxSt <= StartSt;
                      else
                        cnt := cnt+1;
                      end if;
      when StartSt => if BitCnt = 1 then
                        RxSt <= DataSt;
                      end if;
      when DataSt  => if BitCnt = 8 then
                        Push(RxShift);
                        RxSt <= StopSt;
                      end if;
      when StopSt  => if RXi = '1' then
                        RxSt <= IdleSt;
                      end if;  
    end case;                     

    if BufEmpt then RXRDYi <= '0'; else RXRDYi <= '1'; end if;
    RxData <= BufData(OutP);
    if STB_I = '1' and WE_I= '0' and ADR_I(0)='0' and  RXRDYi='1' then Pull; end if;
    if BufLen = BuffSize then BufFull := true; else BufFull := false; end if;
    if BufLen = 0 then BufEmpt := true; else BufEmpt := false; end if;

  end if;
end process RxFifoProc;

end generate;

------------------------------------------------------------------------------

RX1: if buffsize=0 generate
begin

RxStProc: process (RST_I,CLK_I)
Variable cnt : integer range 0 to BaudDV/2;
begin
  if RST_I='1' then
    RxSt <= IdleSt;
    RxData <= (others=>'0');
    RXRDYi <= '0';
    cnt := 0;

    if (debug=1) then
      Report "RX Baud: " &  integer'image(baud) & " real: " &integer'image(integer(real(sysfrec)/real((BaudDV+1))));
    end if;

  elsif rising_edge(CLK_I) then
    case RxSt is
      when IdleSt  => if RXi = '0' then
                        RxSt <= CheckSt;
                        cnt := 0;
                      end if;
      when CheckSt => if RXi = '1' then
                        RxSt <= IdleSt;
                      elsif cnt = BaudDV/2 then
                        RxSt <= StartSt;
                      else
                        cnt := cnt+1;
                      end if;
      when StartSt => if BitCnt = 1 then
                        RxSt <= DataSt;
                      end if;
      when DataSt  => if BitCnt = 8 then
                        RxData <= RxShift;
                        RXRDYi <= '1';
                        RxSt <= StopSt;
                      end if;
      when StopSt  => if RXi = '1' then
                        RxSt <= IdleSt;
                      end if;
    end case;

    if STB_I = '1' and WE_I= '0' and RXRDYi='1' then RXRDYi <= '0'; end if;

  end if;
end process RxStProc;

end generate;

------------------------------------------------------------------------------

--RxShiftProc: process (RxSt,BDclk)
--begin
--  if RxSt=IdleSt then
--    RxShift<= (others=>'0');
--    BitCnt <= 0;
--  elsif rising_edge(BDclk) then
--    RxShift <= RXi & RxShift(7 downto 1);
--    BitCnt <= BitCnt + 1;
--  end if;
--end process RxShiftProc;

RxShiftProc:process (CLK_I, RxSt, BDclk)
begin
  if RxSt=IdleSt then
    RxShift<= (others=>'0');
    BitCnt <= 0;
  elsif rising_edge(CLK_I) then
    if (BDclk='1') then 
      RxShift <= RXi & RxShift(7 downto 1);
      BitCnt <= BitCnt + 1;
    end if;
  end if;
end process;


-- Sync incoming RX (anti metastable) ---
syncproc: process(RST_I, CLK_I) is
begin
  if RST_I='1' then
    RXi <= '1';
  elsif rising_edge(CLK_I) then
    RXi <= RX;
  end if;
end process;

BaudGen: process (RxSt,CLK_I)
Variable cnt: integer range 0 to BaudDV;
begin
  if (RxSt=IdleSt) or (RxSt=CheckSt) or (RxSt=StopSt)then
    BDclk <= '0';
    cnt:=0;
  elsif rising_edge(CLK_I) then
    if cnt=BaudDV then
      BDclk <= '1';
      cnt := 0;
    else   
      BDclk <= '0';
      cnt:=cnt+1;
    end if;
  end if;
end process BaudGen;

DAT_O(15) <= RXRDYi;

end architecture RX_Arch;