library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Dense_Layer_tb is
end Dense_Layer_tb;

architecture Behavioral of Dense_Layer_tb is

    -- 1. Component Declaration
    component Dense_Layer
        Generic (
            NUM_INPUTS  : integer;
            NUM_OUTPUTS : integer;
            USE_TANH    : boolean
        );
        Port ( 
            clk        : in  std_logic;
            rst        : in  std_logic;
            start      : in  std_logic;
            input_vec  : in  data_array_t;
            weights    : in  data_array_t;
            biases     : in  data_array_t;
            output_vec : out data_array_t;
            done       : out std_logic
        );
    end component;

    -- 2. Configuration (Teste Simplificado 2x2)
    constant N_IN  : integer := 2;
    constant N_OUT : integer := 2;

    -- 3. Signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal start : std_logic := '0';
    
    signal input_vec : data_array_t(0 to N_IN-1) := (others => (others => '0'));
    signal weights   : data_array_t(0 to (N_IN * N_OUT)-1) := (others => (others => '0'));
    signal biases    : data_array_t(0 to N_OUT-1) := (others => (others => '0'));
    
    signal output_vec : data_array_t(0 to N_OUT-1);
    signal done : std_logic;

    constant clk_period : time := 10 ns;
    
    -- Constants Q16.16
    constant VAL_1    : data_t := to_signed(65536, 32);  -- 1.0
    constant VAL_HALF : data_t := to_signed(32768, 32);  -- 0.5
    constant VAL_0    : data_t := (others => '0');

begin

    -- 4. Instantiate UUT (Com Tanh Ativado)
    uut: Dense_Layer 
    Generic Map (
        NUM_INPUTS  => N_IN,
        NUM_OUTPUTS => N_OUT,
        USE_TANH    => true
    )
    Port Map (
        clk => clk,
        rst => rst,
        start => start,
        input_vec => input_vec,
        weights => weights,
        biases => biases,
        output_vec => output_vec,
        done => done
    );

    -- Clock
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus
    stim_proc: process
        variable timeout_cnt : integer;
        variable res0, res1 : integer;
    begin
        -- Reset Seguro
        rst <= '1';
        start <= '0';
        wait for 100 ns;
        wait until falling_edge(clk);
        rst <= '0';
        wait for clk_period*2;

        report "--- TESTE 1: Matriz Identidade 2x2 ---";
        -- Objetivo: 
        -- Neuron 0 = (In0 * 1.0 + In1 * 0.0) + 0 = In0 -> Tanh(In0)
        -- Neuron 1 = (In0 * 0.0 + In1 * 1.0) + 0 = In1 -> Tanh(In1)
        
        -- Inputs: [1.0, 0.5]
        input_vec(0) <= VAL_1;
        input_vec(1) <= VAL_HALF;
        
        -- Pesos: [1, 0,  0, 1] (Matriz Identidade achatada)
        -- Layout: [W00, W01, W10, W11]
        weights(0) <= VAL_1; -- W00
        weights(1) <= VAL_0; -- W01
        weights(2) <= VAL_0; -- W10
        weights(3) <= VAL_1; -- W11
        
        biases <= (others => (others => '0'));

        -- Disparo Seguro
        wait until falling_edge(clk);
        start <= '1';
        wait for clk_period;
        start <= '0';

        -- Esperar conclusão (Timeout)
        timeout_cnt := 0;
        loop
            wait until rising_edge(clk);
            if done = '1' then
                exit;
            end if;
            timeout_cnt := timeout_cnt + 1;
            if timeout_cnt > 200 then
                report "FALHA: Timeout! Done não subiu." severity failure;
            end if;
        end loop;
        
        wait for clk_period; 

        -- Verificar Saída
        res0 := to_integer(output_vec(0));
        res1 := to_integer(output_vec(1));
        
        report "Out[0] (Tanh 1.0): " & integer'image(res0) & " (Exp: ~49912)";
        report "Out[1] (Tanh 0.5): " & integer'image(res1) & " (Exp: ~30285)";
        
        -- Tolerância de +/- 50 devido à LUT
        assert abs(res0 - 49912) < 50 report "Falha Neuronio 0" severity error;
        assert abs(res1 - 30285) < 50 report "Falha Neuronio 1" severity error;

        report "--- TESTE 2: Soma e Bias ---";
        wait for clk_period*5;
        
        -- Inputs: [1.0, 1.0]
        input_vec(0) <= VAL_1;
        input_vec(1) <= VAL_1;
        
        -- Pesos: [0.5, 0.5,  0, 0] 
        -- Neuron 0 = 1*0.5 + 1*0.5 = 1.0 + Bias(0.5) = 1.5 -> Tanh(1.5)
        weights(0) <= VAL_HALF;
        weights(1) <= VAL_HALF;
        weights(2) <= VAL_0;
        weights(3) <= VAL_0;
        
        -- Bias: [0.5, 0]
        biases(0) <= VAL_HALF;
        
        wait until falling_edge(clk);
        start <= '1';
        wait for clk_period;
        start <= '0';
        
        wait until done = '1';
        wait for clk_period;
        
        res0 := to_integer(output_vec(0));
        
        -- Tanh(1.5) approx 0.9051 * 65536 = 59319
        report "Out[0] (Tanh 1.5): " & integer'image(res0) & " (Exp: ~59319)";
        assert abs(res0 - 59319) < 50 report "Falha Neuronio 0 (Teste 2)" severity error;

        report "--- FIM DO TESTE DENSE_LAYER ---";
        wait;
    end process;

end Behavioral;