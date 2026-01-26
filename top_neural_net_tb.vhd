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
        clk          : in  std_logic;
        rst          : in  std_logic;
        i_in         : in  data_t;
        q_in         : in  data_t;
        input_valid  : in  std_logic; 
        
        buf_env_out  : out data_array_t(0 to 5);
        buf_cos_out  : out data_array_t(0 to 5);
        buf_sin_out  : out data_array_t(0 to 5);
        stage_valid  : out std_logic
    );
    end component;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal i_in, q_in : data_t := (others => '0');
    signal input_valid : std_logic := '0';
    
    signal buf_env_out, buf_cos_out, buf_sin_out : data_array_t(0 to 5);
    signal stage_valid : std_logic;

    constant clk_period : time := 10 ns;
    constant INPUT_FILE_NAME : string := "validation_vectors_100.txt";
    file file_VECTORS : text open read_mode is INPUT_FILE_NAME;

begin

    uut: Top_NeuralNet_S1 PORT MAP (
        clk => clk, rst => rst,
        i_in => i_in, q_in => q_in, input_valid => input_valid,
        buf_env_out => buf_env_out,
        buf_cos_out => buf_cos_out,
        buf_sin_out => buf_sin_out,
        stage_valid => stage_valid
    );

    clk_process :process
    begin
        clk <= '0'; wait for clk_period/2; clk <= '1'; wait for clk_period/2;
    end process;

    -- PRODUTOR
    proc_producer: process
        variable v_ILINE : line;
        variable v_I, v_Q, v_DUMMY : integer;
        variable v_SPACE : character;
    begin
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for clk_period*20; 

        report "--- START S1 TEST ---";

        while not endfile(file_VECTORS) loop
            readline(file_VECTORS, v_ILINE);
            read(v_ILINE, v_I);
            -- read(v_ILINE, v_SPACE); -- uncomment if needed
            read(v_ILINE, v_Q);
            
            wait until falling_edge(clk);
            i_in <= to_signed(v_I, 32);
            q_in <= to_signed(v_Q, 32);
            input_valid <= '1';
            wait for clk_period;
            input_valid <= '0';
            
            -- Wait for processing (~50 cycles)
            wait for clk_period * 60; 
        end loop;
        
        wait for clk_period * 200;
        report "--- END S1 TEST ---";
        wait;
    end process;

    -- MONITOR
    proc_monitor: process
    begin
        wait until rst = '0';
        loop
            wait until rising_edge(clk);
            if stage_valid = '1' then
                report "Buffer Update!" &
                       " Env[0]: " & integer'image(to_integer(buf_env_out(0))) & 
                       " Cos[0]: " & integer'image(to_integer(buf_cos_out(0)));
            end if;
        end loop;
    end process;

end Behavioral;