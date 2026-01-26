library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Top_NeuralNet_S3_tb is
end Top_NeuralNet_S3_tb;

architecture Behavioral of Top_NeuralNet_S3_tb is

    component Top_NeuralNet_S3
    Port ( 
        clk, rst : in std_logic;
        i_in, q_in : in data_t;
        input_valid : in std_logic;
        real_mlp_out, imag_mlp_out : out data_t;
        stage_valid : out std_logic
    );
    end component;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal i_in, q_in : data_t := (others => '0');
    signal input_valid : std_logic := '0';
    signal real_out, imag_out : data_t;
    signal stage_valid : std_logic;
    
    constant clk_period : time := 10 ns;
    constant VAL_1 : data_t := to_signed(65536, 32);

begin

    uut: Top_NeuralNet_S3 PORT MAP (clk, rst, i_in, q_in, input_valid, real_out, imag_out, stage_valid);

    clk_process :process begin
        clk <= '0'; wait for clk_period/2; clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process
    begin
        rst <= '1'; wait for 100 ns; rst <= '0'; wait for clk_period*20;

        report "--- TESTE S3: Cadeia Completa (Conv + MLPs) ---";
        
        -- Injetar 1.0 (Encher buffer)
        for k in 1 to 8 loop
            wait until falling_edge(clk);
            i_in <= VAL_1; q_in <= (others => '0');
            input_valid <= '1'; wait for clk_period; input_valid <= '0';
            
            -- Esperar processamento (~450 Conv + ~1300 MLP = ~1800 ciclos)
            wait until stage_valid = '1' for 3000 * clk_period;
            
            if stage_valid = '1' then
                report "Amostra " & integer'image(k) & " OK. Real=" & integer'image(to_integer(real_out)) & " Imag=" & integer'image(to_integer(imag_out));
            else
                report "TIMEOUT Amostra " & integer'image(k) severity error;
            end if;
            
            wait for clk_period * 100;
        end loop;
        
        wait;
    end process;

end Behavioral;