library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Pooling_ReLU_Block_tb is
end Pooling_ReLU_Block_tb;

architecture Behavioral of Pooling_ReLU_Block_tb is

    -- 1. Componente Sob Teste
    component Pooling_ReLU_Block
        Generic (
            INPUT_SIZE : integer := 3
        );
        Port ( 
            clk             : in  std_logic;
            rst             : in  std_logic;
            
            data_in_env     : in  data_array_t(0 to INPUT_SIZE-1);
            data_in_cos     : in  data_array_t(0 to INPUT_SIZE-1);
            data_in_sin     : in  data_array_t(0 to INPUT_SIZE-1);
            
            pool_reciprocal : in  data_t;
            data_out        : out data_t
        );
    end component;

    -- 2. Configuração (3 elementos por canal, total 9 elementos)
    constant TEST_SIZE : integer := 3;
    
    -- Sinais
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    
    signal data_in_env : data_array_t(0 to TEST_SIZE-1) := (others => (others => '0'));
    signal data_in_cos : data_array_t(0 to TEST_SIZE-1) := (others => (others => '0'));
    signal data_in_sin : data_array_t(0 to TEST_SIZE-1) := (others => (others => '0'));
    
    signal pool_reciprocal : data_t := (others => '0');
    signal data_out : data_t;

    constant clk_period : time := 10 ns;
    
    -- Constantes Q16.16
    constant VAL_1    : data_t := to_signed(65536, 32);   -- 1.0
    constant VAL_NEG  : data_t := to_signed(-65536, 32);  -- -1.0
    constant VAL_10   : data_t := to_signed(655360, 32);  -- 10.0
    
    -- Recíproco para média de 9 elementos (1/9)
    -- 1/9 = 0.11111... * 65536 = 7281.77 -> 7282
    constant RECIP_1_9 : data_t := to_signed(7282, 32);

begin

    -- 3. Instanciação
    uut: Pooling_ReLU_Block 
    Generic Map ( INPUT_SIZE => TEST_SIZE )
    Port Map (
        clk => clk,
        rst => rst,
        data_in_env => data_in_env,
        data_in_cos => data_in_cos,
        data_in_sin => data_in_sin,
        pool_reciprocal => pool_reciprocal,
        data_out => data_out
    );

    -- Clock
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Estímulos
    stim_proc: process
        variable v_out_int : integer;
    begin
        -- Reset
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for clk_period*2;

        report "--- TESTE 1: Média Simples (Tudo 1.0) ---";
        -- Configurar Recíproco (1/9)
        pool_reciprocal <= RECIP_1_9;
        
        -- Todas as entradas = 1.0
        data_in_env <= (others => VAL_1);
        data_in_cos <= (others => VAL_1);
        data_in_sin <= (others => VAL_1);
        
        -- Esperar Latência (2 ciclos no pipeline interno)
        wait for clk_period * 3;
        
        -- Esperado: (9 * 1.0) / 9 = 1.0 (65536)
        v_out_int := to_integer(data_out);
        report "Out (Tudo 1.0): " & integer'image(v_out_int) & " (Exp: ~65536)";
        assert abs(v_out_int - 65536) < 10 report "Falha Teste 1" severity error;

        report "--- TESTE 2: ReLU (Ignorar Negativos) ---";
        -- Entradas mistas
        -- Env: [10, -10, 10] -> Soma efetiva: 20 (o -10 vira 0)
        -- Cos: [0, 0, 0]     -> Soma: 0
        -- Sin: [-5, -5, -5]  -> Soma: 0 (todos negativos viram 0)
        
        data_in_env(0) <= VAL_10; 
        data_in_env(1) <= to_signed(-655360, 32); -- -10.0
        data_in_env(2) <= VAL_10;
        
        data_in_cos <= (others => (others => '0'));
        data_in_sin <= (others => to_signed(-327680, 32)); -- -5.0
        
        wait for clk_period * 3;
        
        -- Esperado: Soma = 10 + 0 + 10 + 0... = 20.0
        -- Média: 20.0 / 9 = 2.222...
        -- 2.222 * 65536 = 145635
        
        v_out_int := to_integer(data_out);
        report "Out (ReLU Check): " & integer'image(v_out_int) & " (Exp: ~145635)";
        assert abs(v_out_int - 145635) < 10 report "Falha Teste 2 (ReLU)" severity error;

        report "--- FIM DO TESTE POOLING ---";
        wait;
    end process;

end Behavioral;