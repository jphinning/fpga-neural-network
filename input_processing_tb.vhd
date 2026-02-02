library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Input_Processing_Block_tb is
end Input_Processing_Block_tb;

architecture Behavioral of Input_Processing_Block_tb is

    component Input_Processing_Block
    Port ( 
        clk                : in  std_logic;
        rst                : in  std_logic;
        i_in               : in  data_t;
        q_in               : in  data_t;
        input_valid        : in  std_logic;
        envelope_out       : out data_t;
        theta_unwrapped_out: out data_t;
        theta_norm_out     : out data_t;
        buffers_enable     : out std_logic
    );
    end component;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal i_in : data_t := (others => '0');
    signal q_in : data_t := (others => '0');
    signal input_valid : std_logic := '0';
    
    signal envelope_out : data_t;
    signal theta_unwrapped_out : data_t;
    signal theta_norm_out : data_t;
    signal buffers_enable : std_logic;

    constant clk_period : time := 10 ns;
    
    -- Constants Q16.16
    constant VAL_ONE : data_t := to_signed(65536, 32); 
    constant VAL_NEG_ONE : data_t := to_signed(-65536, 32);
    constant VAL_HALF : data_t := to_signed(32768, 32);
    constant PI_VAL : integer := 205887;

begin

    uut: Input_Processing_Block PORT MAP (
        clk => clk,
        rst => rst,
        i_in => i_in,
        q_in => q_in,
        input_valid => input_valid,
        envelope_out => envelope_out,
        theta_unwrapped_out => theta_unwrapped_out,
        theta_norm_out => theta_norm_out,
        buffers_enable => buffers_enable
    );

    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    stim_proc: process
        variable env_int : integer;
        variable theta_int : integer;
    begin
        -- 1. Reset
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for clk_period*5;

        report "--- TESTE 1: Ganho CORDIC e Latência ---";
        -- Envia I=1.0, Q=0.0
        -- Esperado: Envelope ~ 1.0 (65536) pois o ganho foi compensado
        -- Esperado: Theta ~ 0
        i_in <= VAL_ONE; 
        q_in <= (others => '0');
        input_valid <= '1';
        wait for clk_period;
        input_valid <= '0';
        
        -- Espera a resposta (Latencia definida no bloco, ex: 40 ciclos)
        wait until buffers_enable = '1';
        
        -- [CORREÇÃO]: Esperar 2 ciclos para o dado passar pelo registrador de saída
        wait for clk_period * 2; 
        
        env_int := to_integer(envelope_out);
        theta_int := to_integer(theta_unwrapped_out);
        
        report "Case 1 Output -> Env: " & integer'image(env_int) & " Theta: " & integer'image(theta_int);
        
        -- Verifica Ganho: Aceita erro de +/- 100 (0.15%)
        if abs(env_int - 65536) < 100 then
            report "PASS: Envelope Gain Correct";
        else
            report "FAIL: Envelope Gain Incorrect (Exp ~65536)" severity error;
        end if;
        
        -- Verifica Fase
        assert abs(theta_int) < 100 report "FAIL: Phase 0 Incorrect" severity error;

        
        -- === TESTE 2: Fase 180 Graus ===
        report "--- TESTE 2: Fase PI ---";
        wait for clk_period * 10;
        
        -- Envia I=-1.0, Q=0.0
        i_in <= VAL_NEG_ONE;
        q_in <= (others => '0');
        input_valid <= '1';
        wait for clk_period;
        input_valid <= '0';
        
        wait until buffers_enable = '1';
        wait for clk_period * 2; -- [CORREÇÃO] Espera extra
        
        theta_int := to_integer(theta_unwrapped_out);
        report "Case 2 Output -> Theta: " & integer'image(theta_int);
        
        -- Espera PI (205887)
        if abs(theta_int - PI_VAL) < 1000 then -- Tolerância maior para fase CORDIC
            report "PASS: Phase PI Correct";
        else
            report "FAIL: Phase PI Incorrect" severity error;
        end if;


        -- === TESTE 3: Fase Wrap (Continuidade) ===
        report "--- TESTE 3: Fase Wrap ---";
        wait for clk_period * 10;
        
        -- Envia um valor logo abaixo de -PI (Ex: -1.0, -0.1)
        -- A lógica deve detectar o salto de +PI para -PI e fazer o unwrap
        i_in <= VAL_NEG_ONE;
        q_in <= to_signed(-6553, 32); -- -0.1
        input_valid <= '1';
        wait for clk_period;
        input_valid <= '0';
        
        wait until buffers_enable = '1';
        wait for clk_period * 2; -- [CORREÇÃO] Espera extra
        
        theta_int := to_integer(theta_unwrapped_out);
        
        -- O theta unwrapped deve continuar crescendo positivamente (passou de PI)
        -- Anterior era ~205887. Novo deve ser ~212000.
        report "Case 3 Output -> Theta Unwrapped: " & integer'image(theta_int);
        
        if theta_int > 210000 then
             report "PASS: Phase Unwrap Logic";
        else
             report "FAIL: Phase Wrap failed (Value too low)" severity error;
        end if;
        
        report "--- FIM DO TESTE ---";
        wait;
    end process;

end Behavioral;