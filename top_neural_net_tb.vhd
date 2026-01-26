library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.pkg_neural_types.ALL;

entity Top_NeuralNet_S2_tb is
end Top_NeuralNet_S2_tb;

architecture Behavioral of Top_NeuralNet_S2_tb is

    component Top_NeuralNet_S2
    Port ( 
        clk, rst : in std_logic;
        i_in, q_in : in data_t;
        input_valid : in std_logic;
        x_flat_out : out data_array_t(0 to 15);
        stage_valid : out std_logic
    );
    end component;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal i_in, q_in : data_t := (others => '0');
    signal input_valid : std_logic := '0';
    
    signal x_flat_out : data_array_t(0 to 15);
    signal stage_valid : std_logic;

    constant clk_period : time := 10 ns;
    
    -- Para teste controlado, vamos injetar valor fixo 1.0 (Q16.16)
    -- Isso replica o teste "validação_conv_layer" do Python
    constant VAL_1 : data_t := to_signed(65536, 32);

begin

    uut: Top_NeuralNet_S2 PORT MAP (
        clk, rst, i_in, q_in, input_valid, x_flat_out, stage_valid
    );

    clk_process :process
    begin
        clk <= '0'; wait for clk_period/2; clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process
        variable filter_0 : integer;
        variable expected_val : integer := 38020; -- 32664 * 1.164 (Ganho CORDIC)
    begin
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for clk_period*20; 

        report "--- INICIANDO TESTE S2 (Conv Layer) ---";
        report "Injetando 1.0 constante para encher buffer...";

        -- Vamos enviar 10 amostras iguais para encher o buffer e estabilizar
        for k in 1 to 10 loop
            
            -- Envia I=1.0, Q=0.0
            wait until falling_edge(clk);
            i_in <= VAL_1;
            q_in <= (others => '0');
            input_valid <= '1';
            wait for clk_period;
            input_valid <= '0';
            
            -- Espera o processamento (Latencia CORDIC + Conv Serial ~ 450 ciclos)
            wait until stage_valid = '1' for 600 * clk_period;
            
            if stage_valid = '1' then
                filter_0 := to_integer(x_flat_out(0));
                report "Amostra " & integer'image(k) & " -> Filtro 0: " & integer'image(filter_0);
                
                -- A partir da amostra 6, o buffer está cheio de 1.0s
                if k >= 6 then
                    if abs(filter_0 - expected_val) < 2000 then
                        report "  [PASS] Valor consistente com Python + CORDIC Gain!";
                    else
                        report "  [CHECK] Valor diferente. Esperado ~" & integer'image(expected_val);
                    end if;
                end if;
            else
                report "TIMEOUT na Amostra " & integer'image(k) severity error;
            end if;
            
            wait for clk_period * 50; -- Intervalo
        end loop;
        
        report "--- FIM TESTE S2 ---";
        wait;
    end process;

end Behavioral;