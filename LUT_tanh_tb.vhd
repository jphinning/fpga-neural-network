library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity LUT_Tanh_tb is
end LUT_Tanh_tb;

architecture Behavioral of LUT_Tanh_tb is

    component LUT_Tanh
    Port ( 
        clk    : in  std_logic;
        rst    : in  std_logic;
        x_in   : in  data_t;
        y_out  : out data_t
    );
    end component;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal x_in : data_t := (others => '0');
    signal y_out : data_t;

    constant clk_period : time := 10 ns;
    
    -- Constants Q16.16
    constant VAL_ONE : integer := 65536;
    constant VAL_HALF : integer := 32768;

begin

    uut: LUT_Tanh PORT MAP (
        clk => clk,
        rst => rst,
        x_in => x_in,
        y_out => y_out
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
        -- Reset
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for clk_period*2;

        report "--- STARTING LUT_TANH TEST ---";

        -- CASE 1: Input 0.0 -> Expect Tanh(0) = 0.0
        x_in <= to_signed(0, 32);
        wait for clk_period * 5; -- Wait for pipeline latency (~4 cycles)
        
        report "Input: 0.0 | Output: " & integer'image(to_integer(y_out));
        assert to_integer(y_out) = 0 report "Fail Case 1: Tanh(0) != 0" severity warning;

        -- CASE 2: Input 1.0 -> Expect Tanh(1.0) approx 0.76159
        -- 0.76159 * 65536 = 49912
        x_in <= to_signed(VAL_ONE, 32);
        wait for clk_period * 5;
        
        report "Input: 1.0 | Output: " & integer'image(to_integer(y_out)) & " (Exp: ~49912)";
        -- Allow small error due to interpolation
        assert abs(to_integer(y_out) - 49912) < 50 report "Fail Case 2: Tanh(1.0) precision" severity warning;

        -- CASE 3: Input -1.0 -> Expect Tanh(-1.0) approx -0.76159 (-49912)
        x_in <= to_signed(-VAL_ONE, 32);
        wait for clk_period * 5;
        
        report "Input: -1.0 | Output: " & integer'image(to_integer(y_out)) & " (Exp: ~ -49912)";
        assert abs(to_integer(y_out) - (-49912)) < 50 report "Fail Case 3: Tanh(-1.0) precision" severity warning;

        -- CASE 4: Input 0.5 -> Expect Tanh(0.5) approx 0.46211
        -- 0.46211 * 65536 = 30285
        x_in <= to_signed(VAL_HALF, 32);
        wait for clk_period * 5;
        
        report "Input: 0.5 | Output: " & integer'image(to_integer(y_out)) & " (Exp: ~30285)";
        assert abs(to_integer(y_out) - 30285) < 50 report "Fail Case 4: Tanh(0.5) precision" severity warning;

        -- CASE 5: Saturation (Input 4.0) -> Expect Tanh(4.0) approx 0.999... -> 1.0 (65536)
        x_in <= to_signed(4 * VAL_ONE, 32);
        wait for clk_period * 5;
        
        report "Input: 4.0 | Output: " & integer'image(to_integer(y_out));
        assert to_integer(y_out) > 65000 report "Fail Case 5: Tanh(4.0) should saturate near 1.0" severity warning;

        report "--- END OF TEST ---";
        wait;
    end process;

end Behavioral;