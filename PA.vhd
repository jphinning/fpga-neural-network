library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity PA is
  generic (
		  HD  : integer := 799;
        HFP : integer := 40;
        HSP : integer := 128;
        HBP : integer := 88;
		  
		  VD  : integer := 599;
		  VFP : integer := 1;
		  VSP : integer := 4;
		  VBP : integer := 23
    );
	port( iniciar_pausar   : in std_logic;
			dir : in std_logic; 
			vel : in std_logic_vector (1 downto 0);
			rst : in std_logic;
			clk : in std_logic; 
			SSD : out std_logic_vector (6 downto 0);
			AN  : out std_logic_vector (3 downto 0);
			RED   : out std_logic_vector (2 downto 0);
			GREEN : out std_logic_vector (2 downto 0);
			BLUE  : out std_logic_vector (1 downto 0);
			HS  : out std_logic;
			VS  : out std_logic);
end PA;

architecture Behavioral of PA is
	
	signal hPos : integer := 0;
	signal vPos : integer := 0;
	
	type matrix_19x4 is array (0 to 18, 0 to 3) of std_logic_vector(6 downto 0);
	type matrix_7x4 is array (0 to 6, 0 to 3) of std_logic_vector(6 downto 0);
	signal matrix_msg_inicial : matrix_19x4 := (("0011000", "1111010", "1100010", "1000011"),
															  ("1111010", "1100010", "1000011", "0110000"),
															  ("1100010", "1000011", "0110000", "1110000"),
															  ("1000011", "0110000", "1110000", "1100010"),
															  ("0110000", "1110000", "1100010", "1111111"),
															  ("1110000", "1100010", "1111111", "0001000"),
															  ("1100010", "1111111", "0001000", "0011000"),
															  ("1111111", "0001000", "0011000", "1110001"),
															  ("0001000", "0011000", "1110001", "1111001"),
															  ("0011000", "1110001", "1111001", "0110001"),
															  ("1110001", "1111001", "0110001", "0001000"),
															  ("1111001", "0110001", "0001000", "1110000"),
															  ("0110001", "0001000", "1110000", "1111001"),
															  ("0001000", "1110000", "1111001", "1100011"),
															  ("1110000", "1111001", "1100011", "1100010"),
															  ("1111001", "1100011", "1100010", "1111111"),
															  ("1100011", "1100010", "1111111", "0011000"),
															  ("1100010", "1111111", "0011000", "1111010"),
															  ("1111111", "0011000", "1111010", "1100010"));
															  
	signal matrix_msg_final : matrix_7x4 :=    (("1000011", "0011000", "1001000", "1111111"),
															  ("0011000", "1001000", "1111111", "1110001"),
															  ("1001000", "1111111", "1110001", "1111010"),
															  ("1111111", "1110001", "1111010", "1111111"),
															  ("1110001", "1111010", "1111111", "1000011"),
															  ("1111010", "1111111", "1000011", "0011000"),
															  ("1111111", "1000011", "0011000", "1001000"));
	
	type state_type is (msg_inicial, A, AB, B, BC, C, CD, D, DE, E, EF, F, FA, msg_final);
	signal state, next_state : state_type;
	
	signal counter : integer range 0 to 50e6 := 0;
	signal T1, T2 : integer range 0 to 50e6 := 0;
	signal iniciar_pausar_db : STD_LOGIC := '0';
	signal pause : STD_LOGIC := '1';
	
	signal ssd_signal: std_logic_vector(6 downto 0) := "1111111";

begin
	
	process (clk, rst, iniciar_pausar_db)
	variable debounce_time : integer range 0 to 501e3;
	begin
		if rising_edge(clk) then
			debounce_time := debounce_time + 1;
			if debounce_time >= 500e3 then
				debounce_time := 0;
					iniciar_pausar_db <= iniciar_pausar;
			end if;

		end if;
		if rising_edge(iniciar_pausar_db) then
			pause <= not pause;
		end if;
		if rst = '1' then
			pause <= '1';
		end if;		
	end process;
	
	process (clk, rst)
	variable timer_segundo : integer range 0 to 501e5 := 0;
	variable timer_rot : integer range 0 to 121 := 0;
	begin
		if rst = '1' then
			state <= msg_inicial;
			timer_segundo := 0;
			timer_rot := 0;
		elsif rising_edge(clk) and pause = '0' then
			if state /= msg_inicial then
				if timer_segundo >= 50e6 then
					timer_segundo := 0;
					timer_rot := timer_rot + 1;
				end if;
				if timer_rot >= 120 then
					timer_rot := 0;
					state <= msg_final;
				end if;
				timer_segundo := timer_segundo + 1;
			end if;
			if ((state = A) or (state = B) or (state = C) or (state = D) or (state = E) or (state = F)) then
				if counter >= T1 then
					counter <= 0;
					state <= next_state;
				else
					counter <= counter + 1;
				end if;
			else
				if counter >= T2 then
					counter <= 0;
					state <= next_state;
				else
					counter <= counter + 1;
				end if;
			end if;
		end if;
	end process;
	 
	process (state, dir)
	begin
		case state is
			when msg_inicial => next_state <= A;
			when A => if dir = '0' then next_state <= AB; else next_state <= FA; end if;
			when AB => if dir = '0' then next_state <= B; else next_state <= A; end if;
			when B => if dir = '0' then next_state <= BC; else next_state <= AB; end if;
			when BC => if dir = '0' then next_state <= C; else next_state <= B; end if;
			when C => if dir = '0' then next_state <= CD; else next_state <= BC; end if;
			when CD => if dir = '0' then next_state <= D; else next_state <= C; end if;
			when D => if dir = '0' then next_state <= DE; else next_state <= CD; end if;
			when DE => if dir = '0' then next_state <= E; else next_state <= D; end if;
			when E => if dir = '0' then next_state <= EF; else next_state <= DE; end if;
			when EF => if dir = '0' then next_state <= F; else next_state <= E; end if;
			when F => if dir = '0' then next_state <= FA; else next_state <= EF; end if;
			when FA => if dir = '0' then next_state <= A; else next_state <= F; end if;
			when msg_final => next_state <= msg_final;
		end case;
	end process;

	process (clk, rst, state)
	variable count: natural  range 0 to 25000:=0;
	variable refresh: natural  range 0 to 3:=0;
	variable in_clk: STD_LOGIC:='0';
	variable timer_msg: natural range 0 to 55e6 := 0;
	variable linha: integer range 0 to 20 := 0;
	begin

		if rising_edge(clk) then
			if rst = '1' then
				timer_msg := 0;
				linha := 0;
			end if;
			if(count>2500) then
				count:=0;
				refresh:=refresh+1;
				if(refresh>=4) then
					refresh:=0;
				end if;
			else
				count:= count+1;
			end if;
			if timer_msg >= 25e6 then
				timer_msg := 0;
				linha := linha + 1;
				if (state = msg_inicial and linha >= 19) or (state = msg_final and linha >= 7) or (state /= msg_inicial and state /= msg_final) then
					linha := 0;
				end if;
			else
				timer_msg := timer_msg + 1;
			end if;
		end if;
		case state is
				when msg_inicial =>
					CASE refresh is
						when 0 =>
								AN <= "1110";
								ssd_signal <= matrix_msg_inicial(linha, 3);
						when 1 		=> 
								AN <= "1101";
								ssd_signal <= matrix_msg_inicial(linha, 2);
						when 2 		=> 
								AN <= "1011";
								ssd_signal <= matrix_msg_inicial(linha, 1);
						when OTHERs => 
								AN <= "0111";
								ssd_signal <= matrix_msg_inicial(linha, 0);
					end case;
				when A => ssd_signal <= "0111111"; AN <= "1110";
				when AB => ssd_signal <= "0011111"; AN <= "1110";
				when B => ssd_signal <= "1011111"; AN <= "1110";
				when BC => ssd_signal <= "1001111"; AN <= "1110";
				when C => ssd_signal <= "1101111"; AN <= "1110";
				when CD => ssd_signal <= "1100111"; AN <= "1110";
				when D => ssd_signal <= "1110111"; AN <= "1110";
				when DE => ssd_signal <= "1110011"; AN <= "1110";
				when E => ssd_signal <= "1111011"; AN <= "1110";
				when EF => ssd_signal <= "1111001"; AN <= "1110";
				when F => ssd_signal <= "1111101"; AN <= "1110";
				when FA => ssd_signal <= "0111101"; AN <= "1110";
				when msg_final => 
					CASE refresh is
						when 0 =>
								AN <= "1110";
								ssd_signal <= matrix_msg_final(linha, 3);
						when 1 		=> 
								AN <= "1101";
								ssd_signal <= matrix_msg_final(linha, 2);
						when 2 		=> 
								AN <= "1011";
								ssd_signal <= matrix_msg_final(linha, 1);
						when OTHERs => 
								AN <= "0111";
								ssd_signal <= matrix_msg_final(linha, 0);
					end case;
		end case;
	end process;
	
	with vel select
		T1 <= 6e6  when "00",
				12e6 when "01",
				24e6 when "10",
				48e6 when others;
				
	with vel select
		T2 <= 2e6  when "00",
				4e6  when "01",
				8e6  when "10",
				16e6 when others;
				
	SSD <= ssd_signal;
				
				
	process(clk, rst)
	begin
		if rst = '1' then
			hPos <= 0;
		elsif (clk'event and clk = '1') then
			if (hPos = (HD + HFP + HSP + HBP)) then
				hPos <= 0;
			else
				hPos <= hPos + 1;
			end if;
		end if;		
	end process;
	
	process(clk, rst)
	begin
		if rst = '1' then
			vPos <= 0;
		elsif (clk'event and clk = '1') then
			if (hPos = (HD + HFP + HSP + HBP)) then
				if (vPos = (VD + VFP + VSP + VBP)) then
					vPos <= 0;
				else
					vPos <= vPos + 1;
				end if;
			end if;	
		end if;		
	end process;
	
	process(clk, rst, vPos)
	begin
		if rst = '1' then
			VS <= '0';
		elsif(clk'event and clk = '1') then
			if (vPos <= (VD + VFP)) or (vPos > (VD + VFP + VSP)) then
				VS <= '1';
			else
				VS <= '0';
			end if;
		end if;
	end process;
	
	process(clk, rst, hPos)
	begin
		if rst = '1' then
			HS <= '0';
		elsif(clk'event and clk = '1') then
			if (hPos <= (HD + HFP)) or (hPos > (HD + HFP + HSP)) then
				HS <= '1';
			else
				HS <= '0';
			end if;
		end if;
	end process;
	
	process(clk, rst, vPos, hPos)
	begin
		if rst = '1' OR state = msg_final OR state = msg_inicial then
			RED <= "010";
			GREEN <= "010";
			BLUE <= "01";	
		elsif clk'event and clk = '1' then
			if ((hPos >= 300 and hPos <= 330) and (vPos >= 145 and vPos <= 285)) then
				if ssd_signal = "1111101" or ssd_signal = "0111101" or ssd_signal = "1111001" then
					RED <= "111";
					GREEN <= "000";
					BLUE <= "00";
				else
					RED <= "010";
					GREEN <= "010";
					BLUE <= "01";					
				end if;	
			
			elsif ((hPos >= 300 and hPos <= 330) and (vPos >= 315 and vPos <= 455)) then
				if ssd_signal = "1111011" or ssd_signal = "1110011" or ssd_signal = "1111001" then
					RED <= "111";
					GREEN <= "000";
					BLUE <= "00";
				else 
					RED <= "010";
					GREEN <= "010";
					BLUE <= "01";	
				end if;
				
			elsif ((hPos >= 330 and hPos <= 470) and (vPos >= 455 and vPos <= 485)) then							
				if ssd_signal = "1110111" or ssd_signal = "1100111" or ssd_signal = "1110011" then
					RED <= "111";
					GREEN <= "000";
					BLUE <= "00";
				else
					RED <= "010";
					GREEN <= "010";
					BLUE <= "01";				
				end if;
				
			elsif ((hPos >= 470 and hPos <= 500) and (vPos >= 315 and vPos <= 455)) then
				if ssd_signal = "1101111" or ssd_signal = "1001111" or ssd_signal = "1100111" then
					RED <= "111";
					GREEN <= "000";
					BLUE <= "00";
				else
					RED <= "010";
					GREEN <= "010";
					BLUE <= "01";				
				end if;
			
			elsif ((hPos >= 470 and hPos <= 500) and (vPos >= 145 and vPos <= 285)) then				
				if ssd_signal = "1011111" or ssd_signal = "0011111" or ssd_signal = "1001111" then
					RED <= "111";
					GREEN <= "000";
					BLUE <= "00";
				else
					RED <= "010";
					GREEN <= "010";
					BLUE <= "01";					
				end if;
				
			elsif ((hPos >= 330 and hPos <= 470) and (vPos >= 115 and vPos <= 145)) then					
				if ssd_signal = "0111111" or ssd_signal = "0111101" or ssd_signal = "0011111" then
					RED <= "111";
					GREEN <= "000";
					BLUE <= "00";
				else
					RED <= "010";
					GREEN <= "010";
					BLUE <= "01";						
				end if;
			elsif ((hPos >= 330 and hPos <= 470) and (vPos >= 285 and vPos <= 315)) then		
					RED <= "010";
					GREEN <= "010";
					BLUE <= "01";	
			else
				RED <= "000";
				GREEN <= "000";
				BLUE <= "00";
			end if;			
		end if;
	end process;


end Behavioral;
