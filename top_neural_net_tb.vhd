library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.pkg_neural_types.ALL;

entity Top_NeuralNet_Final_tb is
end Top_NeuralNet_Final_tb;

architecture Behavioral of Top_NeuralNet_Final_tb is

    component Top_NeuralNet_Final
    Port ( 
        clk, rst : in std_logic;
        i_in, q_in : in data_t;
        input_valid : in std_logic;
        i_out, q_out : out data_t;
        output_valid : out std_logic
    );
    end component;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal i_in, q_in : data_t := (others => '0');
    signal input_valid : std_logic := '0';
    signal i_out, q_out : data_t;
    signal output_valid : std_logic;
    
    constant clk_period : time := 10 ns;
    
    -- Files
    constant INPUT_FILE_NAME : string := "validation_vectors_final.txt";
    constant OUTPUT_FILE_NAME : string := "vhdl_output_dump.txt";
    
    file file_VECTORS : text open read_mode is INPUT_FILE_NAME;
    
    -- Number of warm-up samples to skip (M=5 + 1 for safety)
    constant WARMUP_SAMPLES : integer := 6;

begin

    uut: Top_NeuralNet_Final PORT MAP (clk, rst, i_in, q_in, input_valid, i_out, q_out, output_valid);

    clk_process :process begin
        clk <= '0'; wait for clk_period/2; clk <= '1'; wait for clk_period/2;
    end process;

    -- Producer: Feeds Data
    proc_producer: process
        variable v_ILINE : line;
        variable v_I, v_Q : integer;
    begin
        rst <= '1'; input_valid <= '0'; wait for 100 ns; rst <= '0'; wait for clk_period*20; 

        while not endfile(file_VECTORS) loop
            readline(file_VECTORS, v_ILINE);
            
            -- [FIXED] Read I and Q directly. 
            -- 'read' automatically skips spaces, so we don't need a dummy read.
            read(v_ILINE, v_I); 
            read(v_ILINE, v_Q); 
            -- Ignore the rest of the line (Expected outputs) for the producer
            
            wait until falling_edge(clk);
            i_in <= to_signed(v_I, 32); 
            q_in <= to_signed(v_Q, 32);
            input_valid <= '1'; wait for clk_period; input_valid <= '0';
            
            -- Wait for processing (~1800 cycles)
            wait for clk_period * 2000; 
        end loop;
        wait;
    end process;

    -- Consumer: Writes to File and Checks Results
    proc_consumer: process
        file file_CHECK : text open read_mode is INPUT_FILE_NAME;
        
        -- File handle for output
        file file_DUMP  : text open write_mode is OUTPUT_FILE_NAME;
        
        variable v_ILINE : line;
        variable v_OLINE : line; -- Output Line buffer
        
        variable v_I_EXP, v_Q_EXP, v_DUMMY : integer;
        variable v_I_ACT, v_Q_ACT : integer;
        variable v_ERR_I, v_ERR_Q : integer;
        variable sample_cnt : integer := 0;
    begin
        -- Write Header to Dump File
        write(v_OLINE, string'("Index, I_out, Q_out"));
        writeline(file_DUMP, v_OLINE);
    
        wait until rst = '0';
        while not endfile(file_CHECK) loop
            wait until rising_edge(clk) and output_valid = '1';
            
            -- [SAFETY] Small delay to ensure signals are stable
            wait for 1 ns;
            
            sample_cnt := sample_cnt + 1;
            
            -- Read Expected from Input File
            readline(file_CHECK, v_ILINE);
            
            -- Skip inputs (Col 1 and 2)
            read(v_ILINE, v_DUMMY); 
            read(v_ILINE, v_DUMMY); 
            
            -- Read Expected Outputs (Col 3 and 4)
            read(v_ILINE, v_I_EXP); 
            read(v_ILINE, v_Q_EXP); 
            
            -- Capture Actual VHDL Output
            v_I_ACT := to_integer(i_out);
            v_Q_ACT := to_integer(q_out);
            
            -- Write to Dump File
            write(v_OLINE, sample_cnt);
            write(v_OLINE, string'(", "));
            write(v_OLINE, v_I_ACT);
            write(v_OLINE, string'(", "));
            write(v_OLINE, v_Q_ACT);
            writeline(file_DUMP, v_OLINE);
            
            -- Check Error ONLY after warm-up
            if sample_cnt > WARMUP_SAMPLES then
                v_ERR_I := abs(v_I_ACT - v_I_EXP);
                v_ERR_Q := abs(v_Q_ACT - v_Q_EXP);
                
                -- Tolerance of 500 (approx 0.007 in Q16.16)
                if (v_ERR_I > 500) or (v_ERR_Q > 500) then
                    report "FAIL Sample " & integer'image(sample_cnt) & 
                           " | I=" & integer'image(v_I_ACT) & " (Exp:" & integer'image(v_I_EXP) & ")" &
                           " | Q=" & integer'image(v_Q_ACT) & " (Exp:" & integer'image(v_Q_EXP) & ")"
                           severity warning;
                else
                    report "PASS Sample " & integer'image(sample_cnt) & 
                           " | I=" & integer'image(v_I_ACT) & " Q=" & integer'image(v_Q_ACT);
                end if;
            else
                report "INFO: Skipping Check for Warm-up Sample " & integer'image(sample_cnt);
            end if;
        end loop;
        wait;
    end process;

end Behavioral;