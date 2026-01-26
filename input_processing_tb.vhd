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
    begin
        -- 1. Reset
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for clk_period*5;

        report "--- TESTE 1: Latência CORDIC ---";
        -- Envia pulso
        i_in <= VAL_ONE; -- I=1.0
        q_in <= (others => '0'); -- Q=0.0
        input_valid <= '1';
        wait for clk_period;
        input_valid <= '0';
        
        -- Espera a resposta (Deve demorar ~20-21 ciclos)
        wait until buffers_enable = '1';
        report "Sucesso: buffers_enable subiu!";
        
        -- Verifica valores (I=1, Q=0 -> Env=1, Phase=0)
        -- Nota: O CORDIC tem um ganho de ~1.647, mas assumindo normalização ou modo Scale compensado.
        -- Se o IP não tiver compensação, o envelope será ~1.647 * VAL_ONE.
        
        -- === TESTE 2: Lógica de Fase (Wrap) ===
        report "--- TESTE 2: Fase Wrap ---";
        wait for clk_period * 5;
        
        -- Envia I=-1, Q=0 (Fase = PI)
        i_in <= to_signed(-65536, 32); 
        q_in <= (others => '0');
        input_valid <= '1';
        wait for clk_period;
        input_valid <= '0';
        
        wait until buffers_enable = '1';
        -- Aqui diff deve ser PI - 0 = PI.
        
        wait for clk_period * 5;
        
        -- Envia I=-1, Q=-0.1 (Fase = -PI + delta) -> Deve gerar salto grande negativo
        -- A lógica deve corrigir (-PI - PI = -2PI -> Ajusta +2PI -> delta pequeno)
        i_in <= to_signed(-65536, 32);
        q_in <= to_signed(-6553, 32); -- Pequeno negativo
        input_valid <= '1';
        wait for clk_period;
        input_valid <= '0';
        
        wait until buffers_enable = '1';
        
        report "--- FIM DO TESTE ---";
        wait;
    end process;

end Behavioral;