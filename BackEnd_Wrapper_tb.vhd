library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.pkg_neural_types.ALL;

entity BackEnd_Wrapper_tb is
end BackEnd_Wrapper_tb;

architecture Behavioral of BackEnd_Wrapper_tb is

    component BackEnd_Wrapper
        Port ( 
            clk, rst, start : in std_logic;
            x_flat_in : in data_array_t(0 to 15);
            theta_in : in data_t;
            i_out, q_out : out data_t;
            done : out std_logic
        );
    end component;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal start : std_logic := '0';
    
    signal x_flat_in : data_array_t(0 to 15) := (others => (others => '0'));
    signal theta_in : data_t := (others => '0');
    signal i_out, q_out : data_t;
    signal done : std_logic;
    
    constant clk_period : time := 10 ns;
    file file_VECTORS : text open read_mode is "vectors_backend.txt";

begin

    uut: BackEnd_Wrapper PORT MAP (clk, rst, start, x_flat_in, theta_in, i_out, q_out, done);

    clk_process :process begin
        clk <= '0'; wait for clk_period/2; clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process
        variable v_ILINE : line;
        variable v_VAL, v_THETA : integer;
        variable v_I_EXP, v_Q_EXP : integer;
        variable sample_cnt : integer := 0;
    begin
        rst <= '1'; wait for 100 ns; rst <= '0'; wait for clk_period*10;

        while not endfile(file_VECTORS) loop
            sample_cnt := sample_cnt + 1;
            readline(file_VECTORS, v_ILINE);
            
            -- Read x_flat (16 values)
            for i in 0 to 15 loop
                read(v_ILINE, v_VAL);
                x_flat_in(i) <= to_signed(v_VAL, 32);
            end loop;
            
            -- Read Theta
            read(v_ILINE, v_THETA);
            theta_in <= to_signed(v_THETA, 32);
            
            -- Read Expected
            read(v_ILINE, v_I_EXP); read(v_ILINE, v_Q_EXP);
            
            -- Trigger
            wait until falling_edge(clk);
            start <= '1'; wait for clk_period; start <= '0';
            
            -- Wait Done
            wait until done = '1' for 3000 * clk_period;
            
            if done = '1' then
                -- [UPDATE] Check both I and Q
                if (abs(to_integer(i_out) - v_I_EXP) < 1000) and 
                   (abs(to_integer(q_out) - v_Q_EXP) < 1000) then 
                    report "Sample " & integer'image(sample_cnt) & " PASS";
                else
                    report "Sample " & integer'image(sample_cnt) & " FAIL." &
                           " I: Got=" & integer'image(to_integer(i_out)) & " Exp=" & integer'image(v_I_EXP) &
                           " Q: Got=" & integer'image(to_integer(q_out)) & " Exp=" & integer'image(v_Q_EXP) 
                           severity error;
                end if;
            else
                report "TIMEOUT Sample " & integer'image(sample_cnt) severity failure;
            end if;
            
            wait for clk_period * 50;
        end loop;
        report "TEST END";
        wait;
    end process;

end Behavioral;