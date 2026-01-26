library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;
use work.pkg_model_constants.ALL; -- Necessary to load test weights

entity MLP_Chain_Serial_tb is
end MLP_Chain_Serial_tb;

architecture Behavioral of MLP_Chain_Serial_tb is

    component MLP_Chain_Serial
        Port ( 
            clk        : in  std_logic;
            rst        : in  std_logic;
            start      : in  std_logic;
            input_vec  : in  data_array_t(0 to 15);
            
            -- Updated Interface with Weight Ports
            w_L1       : in  data_array_t;
            b_L1       : in  data_array_t;
            w_L2       : in  data_array_t;
            b_L2       : in  data_array_t;
            w_L3       : in  data_array_t;
            b_L3       : in  data_array_t;
            
            mlp_out    : out data_t;
            done       : out std_logic
        );
    end component;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal start : std_logic := '0';
    signal input_vec : data_array_t(0 to 15) := (others => (others => '0'));
    signal mlp_out : data_t;
    signal done : std_logic;

    constant clk_period : time := 10 ns;
    constant VAL_1 : data_t := to_signed(65536, 32);

begin

    uut: MLP_Chain_Serial PORT MAP (
        clk => clk,
        rst => rst,
        start => start,
        input_vec => input_vec,
        
        -- Driving inputs with Real Network constants for this test
        w_L1 => W_REAL_FC0_W,
        b_L1 => W_REAL_FC0_B,
        
        w_L2 => W_REAL_FC2_W,
        b_L2 => W_REAL_FC2_B,
        
        w_L3 => W_REAL_FC4_W,
        b_L3 => W_REAL_FC4_B,
        
        mlp_out => mlp_out,
        done => done
    );

    clk_process :process
    begin
        clk <= '0'; wait for clk_period/2; clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process
        variable start_time : time;
        variable cycles : integer;
    begin
        rst <= '1';
        wait for 100 ns;
        wait until falling_edge(clk);
        rst <= '0';
        wait for clk_period*5;

        report "--- TEST START: MLP Chain (Real Weights) ---";

        -- Input: All 1.0
        input_vec <= (others => VAL_1);

        -- Start Pulse
        wait until falling_edge(clk);
        start <= '1';
        start_time := now;
        wait for clk_period;
        start <= '0';

        -- Wait for completion (~1300 cycles)
        wait until done = '1' for 3000 * clk_period;

        if done = '1' then
            cycles := (now - start_time) / clk_period;
            report "SUCCESS: MLP Done!";
            report "Total Latency: " & integer'image(cycles) & " cycles";
            report "Output Value: " & integer'image(to_integer(mlp_out));
        else
            report "FAILURE: Timeout waiting for MLP Done" severity failure;
        end if;

        wait;
    end process;

end Behavioral;