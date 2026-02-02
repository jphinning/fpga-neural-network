library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.pkg_neural_types.ALL;
use work.pkg_model_constants.ALL;

entity Conv_Layer_Serial_tb is
end Conv_Layer_Serial_tb;

architecture Behavioral of Conv_Layer_Serial_tb is

    component Conv_Layer_Serial
        Generic ( N_FILTERS, KERNEL_SIZE, M : integer );
        Port ( 
            clk, rst, start : in std_logic;
            buf_env, buf_cos, buf_sin : in data_array_t;
            x_flat_out : out data_array_t; done : out std_logic 
        );
    end component;

    constant M : integer := 5;
    constant N_FILTERS : integer := 16;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal start : std_logic := '0';
    
    -- Local Buffers to simulate history
    signal buf_env : data_array_t(0 to M) := (others => (others => '0'));
    signal buf_cos : data_array_t(0 to M) := (others => (others => '0'));
    signal buf_sin : data_array_t(0 to M) := (others => (others => '0'));
    
    signal x_flat_out : data_array_t(0 to 15);
    signal done : std_logic;

    constant clk_period : time := 10 ns;
    file file_VECTORS : text open read_mode is "vectors_s2_conv.txt";

begin

    uut: Conv_Layer_Serial 
    Generic Map (N_FILTERS => 16, KERNEL_SIZE => 4, M => 5)
    Port Map (
        clk, rst, start, buf_env, buf_cos, buf_sin, x_flat_out, done
    );

    clk_process :process
    begin
        clk <= '0'; wait for clk_period/2; clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process
        variable v_ILINE : line;
        variable v_ENV, v_COS, v_SIN : integer;
        variable v_EXP_FLAT : integer;
        variable v_ACT_FLAT : integer;
        variable sample_cnt : integer := 0;
        variable errors_in_sample : integer;
    begin
        rst <= '1'; wait for 100 ns; rst <= '0'; wait for clk_period*5;

        while not endfile(file_VECTORS) loop
            sample_cnt := sample_cnt + 1;
            readline(file_VECTORS, v_ILINE);
            
            -- 1. Read Inputs (Newest values)
            read(v_ILINE, v_ENV); read(v_ILINE, v_COS); read(v_ILINE, v_SIN);
            
            -- 2. Shift Local Buffers (Simulate Shift Register behavior)
            wait until falling_edge(clk);
            -- Shift right
            buf_env(1 to M) <= buf_env(0 to M-1);
            buf_cos(1 to M) <= buf_cos(0 to M-1);
            buf_sin(1 to M) <= buf_sin(0 to M-1);
            -- Insert at head
            buf_env(0) <= to_signed(v_ENV, 32);
            buf_cos(0) <= to_signed(v_COS, 32);
            buf_sin(0) <= to_signed(v_SIN, 32);
            
            -- 3. Trigger Conv
            wait for clk_period; -- Wait for shift to settle
            start <= '1'; wait for clk_period; start <= '0';
            
            -- 4. Wait Done
            wait until done = '1' for 1000 * clk_period;
            
            if done = '1' then
                -- 5. Check 16 Filters
                errors_in_sample := 0;
                for f in 0 to 15 loop
                    read(v_ILINE, v_EXP_FLAT);
                    v_ACT_FLAT := to_integer(x_flat_out(f));
                    
                    if abs(v_ACT_FLAT - v_EXP_FLAT) > 200 then
                        errors_in_sample := errors_in_sample + 1;
                        if errors_in_sample = 1 then -- Report only first error per sample
                             report "S2 Sample " & integer'image(sample_cnt) & " Filter " & integer'image(f) & 
                                    " FAIL. Got:" & integer'image(v_ACT_FLAT) & " Exp:" & integer'image(v_EXP_FLAT) severity error;
                        end if;
                    end if;
                end loop;
                
                if errors_in_sample = 0 then
                    report "S2 Sample " & integer'image(sample_cnt) & " PASS";
                end if;
            else
                report "Timeout S2 Sample " & integer'image(sample_cnt) severity failure;
            end if;
            
            wait for clk_period*10;
        end loop;
        report "TEST S2 FINISHED";
        wait;
    end process;
end Behavioral;