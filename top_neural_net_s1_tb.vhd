library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.pkg_neural_types.ALL;

entity Top_NeuralNet_S1_tb is
end Top_NeuralNet_S1_tb;

architecture Behavioral of Top_NeuralNet_S1_tb is

    component Top_NeuralNet_S1
    Port ( 
        clk, rst : in std_logic;
        i_in, q_in : in data_t;
        input_valid : in std_logic;
        buf_env_out, buf_cos_out, buf_sin_out : out data_array_t(0 to 5);
        stage_valid : out std_logic
    );
    end component;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal i_in, q_in : data_t := (others => '0');
    signal input_valid : std_logic := '0';
    
    signal buf_env_out, buf_cos_out, buf_sin_out : data_array_t(0 to 5);
    signal stage_valid : std_logic;

    constant clk_period : time := 10 ns;
    file file_VECTORS : text open read_mode is "vectors_s1_input.txt";

begin

    uut: Top_NeuralNet_S1 PORT MAP (
        clk, rst, i_in, q_in, input_valid,
        buf_env_out, buf_cos_out, buf_sin_out, stage_valid
    );

    clk_process :process
    begin
        clk <= '0'; wait for clk_period/2; clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process
        variable v_ILINE : line;
        variable v_I, v_Q : integer;
        variable v_EXP_ENV, v_EXP_COS, v_EXP_SIN : integer;
        variable v_ACT_ENV, v_ACT_COS, v_ACT_SIN : integer;
        variable sample_cnt : integer := 0;
        
        -- Buffers para guardar a expectativa da amostra N e comparar na N+1
        variable prev_exp_env, prev_exp_cos, prev_exp_sin : integer := 0;
        
    begin
        rst <= '1'; wait for 100 ns; rst <= '0'; wait for clk_period*20; 

        while not endfile(file_VECTORS) loop
            sample_cnt := sample_cnt + 1;
            readline(file_VECTORS, v_ILINE);
            
            -- Read Inputs and Expected
            read(v_ILINE, v_I); read(v_ILINE, v_Q);
            read(v_ILINE, v_EXP_ENV); read(v_ILINE, v_EXP_COS); read(v_ILINE, v_EXP_SIN);
            
            wait until falling_edge(clk);
            i_in <= to_signed(v_I, 32); q_in <= to_signed(v_Q, 32);
            input_valid <= '1'; wait for clk_period; input_valid <= '0';
            
            -- Wait for Stage Valid
            wait until stage_valid = '1' for 200 * clk_period;
            
            if stage_valid = '1' then
                -- Wait for stability
                wait for clk_period; 

                v_ACT_ENV := to_integer(buf_env_out(0));
                v_ACT_COS := to_integer(buf_cos_out(0));
                v_ACT_SIN := to_integer(buf_sin_out(0));
                
                -- Lógica de Correção de Latência:
                -- Na Amostra 1, apenas guardamos o esperado.
                -- Na Amostra 2, comparamos o Obtido (que é o dado da 1) com o Esperado guardado da 1.
                
                if sample_cnt > 1 then
                    report "S1 Check Sample " & integer'image(sample_cnt-1) & 
                           " | ENV Got:" & integer'image(v_ACT_ENV) & " Exp:" & integer'image(prev_exp_env) &
                           " | COS Got:" & integer'image(v_ACT_COS) & " Exp:" & integer'image(prev_exp_cos);

                    if (abs(v_ACT_ENV - prev_exp_env) < 500) and 
                       (abs(v_ACT_COS - prev_exp_cos) < 500) and 
                       (abs(v_ACT_SIN - prev_exp_sin) < 500) then
                        -- Pass
                    else
                        report "FAIL S1 Sample " & integer'image(sample_cnt-1) severity error;
                    end if;
                else
                    report "S1 Sample 1: Ignorando check (Pipeline Fill)";
                end if;
                
                -- Atualiza o buffer de expectativa para a próxima iteração
                prev_exp_env := v_EXP_ENV;
                prev_exp_cos := v_EXP_COS;
                prev_exp_sin := v_EXP_SIN;

            else
                report "Timeout S1 Sample " & integer'image(sample_cnt) severity failure;
            end if;
            
            wait for clk_period * 20;
        end loop;
        report "TEST S1 FINISHED";
        wait;
    end process;
end Behavioral;