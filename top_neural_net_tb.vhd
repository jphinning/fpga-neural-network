library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.pkg_neural_types.ALL;

entity NeuralNet_Complete_tb is
end NeuralNet_Complete_tb;

architecture Behavioral of NeuralNet_Complete_tb is

    component NeuralNet_Complete
        Generic (
            M           : integer := 5;
            N_FILTERS   : integer := 16;
            KERNEL_SIZE : integer := 4
        );
        Port ( 
            clk          : in  std_logic;
            rst          : in  std_logic;
            i_in         : in  data_t;
            q_in         : in  data_t;
            input_valid  : in  std_logic;
            i_out        : out data_t;
            q_out        : out data_t;
            output_valid : out std_logic;
            processing   : out std_logic;
            net_ready    : out std_logic
        );
    end component;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal i_in : data_t := (others => '0');
    signal q_in : data_t := (others => '0');
    signal input_valid : std_logic := '0';
    signal i_out : data_t;
    signal q_out : data_t;
    signal output_valid : std_logic;
    signal processing : std_logic;
    signal net_ready : std_logic;

    constant clk_period : time := 10 ns;
    
    file file_VECTORS : text open read_mode is "validation_vectors_final.txt";
    constant TOLERANCE : integer := 1000;
    
    -- Warm-up: 5 samples for buffer fill + 1 sample for the pipeline lag we found
    constant WARMUP_COUNT : integer := 7;

begin

    uut: NeuralNet_Complete 
    Generic Map ( M => 5, N_FILTERS => 16, KERNEL_SIZE => 4 )
    Port Map (
        clk => clk, rst => rst,
        i_in => i_in, q_in => q_in, input_valid => input_valid,
        i_out => i_out, q_out => q_out, output_valid => output_valid,
        processing => processing, net_ready => net_ready
    );

    clk_process :process
    begin
        clk <= '0'; wait for clk_period/2; clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process
        variable v_ILINE     : line;
        variable v_I_IN, v_Q_IN : integer;
        variable v_I_EXP, v_Q_EXP : integer;
        
        -- [NEW] Variables to store the previous expected value (Delay Line)
        variable v_I_EXP_PREV : integer := 0;
        variable v_Q_EXP_PREV : integer := 0;
        
        variable v_I_ACT, v_Q_ACT : integer;
        variable v_ERR_I, v_ERR_Q : integer;
        
        variable sample_cnt  : integer := 0;
        variable timeout_cnt : integer := 0;
    begin
        report "--- SIMULATION STARTED ---";
        rst <= '1'; wait for 100 ns; rst <= '0';
        wait until rising_edge(clk); wait for clk_period*10;

        while not endfile(file_VECTORS) loop
            sample_cnt := sample_cnt + 1;
            
            -- 1. Read Current Line (Sample N)
            readline(file_VECTORS, v_ILINE);
            read(v_ILINE, v_I_IN);
            read(v_ILINE, v_Q_IN);
            read(v_ILINE, v_I_EXP);
            read(v_ILINE, v_Q_EXP);
            
            -- 2. Send Input N to DUT
            wait until falling_edge(clk);
            i_in <= to_signed(v_I_IN, 32);
            q_in <= to_signed(v_Q_IN, 32);
            input_valid <= '1';
            wait for clk_period;
            input_valid <= '0';
            
            -- 3. Warm-up Phase
            if sample_cnt <= WARMUP_COUNT then
                 report "Sample " & integer'image(sample_cnt) & " (Warm-up): Filling pipeline.";
                 -- Store current expectation to be checked in next loop iteration
                 v_I_EXP_PREV := v_I_EXP;
                 v_Q_EXP_PREV := v_Q_EXP;
                 
                 wait for clk_period * 20; 
            else
                -- 4. Steady State Check
                timeout_cnt := 0;
                loop
                    wait until rising_edge(clk);
                    
                    if output_valid = '1' then
                        v_I_ACT := to_integer(i_out);
                        v_Q_ACT := to_integer(q_out);
                        
                        -- [KEY CHANGE] Compare Actual Output against PREVIOUS Expected Value
                        -- The output arriving now corresponds to the input sent in the previous iteration
                        v_ERR_I := abs(v_I_ACT - v_I_EXP_PREV);
                        v_ERR_Q := abs(v_Q_ACT - v_Q_EXP_PREV);
                        
                        if (v_ERR_I <= TOLERANCE) and (v_ERR_Q <= TOLERANCE) then
                            report "Sample " & integer'image(sample_cnt) & " PASS: " &
                                   "I_out=" & integer'image(v_I_ACT) & " (Exp:" & integer'image(v_I_EXP_PREV) & ")";
                        else
                             report "Sample " & integer'image(sample_cnt) & " FAIL: " &
                                    "I_out=" & integer'image(v_I_ACT) & " (Exp:" & integer'image(v_I_EXP_PREV) & ") " &
                                    "Q_out=" & integer'image(v_Q_ACT) & " (Exp:" & integer'image(v_Q_EXP_PREV) & ")"
                                    severity warning;
                        end if;
                        
                        exit; 
                    end if;
                    
                    timeout_cnt := timeout_cnt + 1;
                    if timeout_cnt > 5000 then 
                        report "TIMEOUT Sample " & integer'image(sample_cnt) severity failure; exit; 
                    end if;
                end loop;
                
                -- Store current expectation for the *next* check
                v_I_EXP_PREV := v_I_EXP;
                v_Q_EXP_PREV := v_Q_EXP;
                
                wait for clk_period * 20;
            end if;
            
        end loop;

        report "--- SIMULATION FINISHED ---";
        wait;
    end process;

end Behavioral;