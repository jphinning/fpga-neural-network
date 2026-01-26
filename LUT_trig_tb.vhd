library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity LUT_Trig_tb is
end LUT_Trig_tb;

architecture Behavioral of LUT_Trig_tb is

    component LUT_Trig
    Port ( 
        clk    : in  std_logic;
        rst    : in  std_logic;
        x_in   : in  data_t; 
        mode_sin : in std_logic; 
        y_out  : out data_t
    );
    end component;
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal x_in : data_t := (others => '0');
    signal mode_sin : std_logic := '0';
    signal y_out : data_t;

    constant clk_period : time := 10 ns;
    
    -- Constants Q16.16
    -- Pi approx 3.14159 * 65536 = 205887
    constant PI_VAL : integer := 205887;
    constant HALF_PI : integer := 102943;
    constant VAL_ONE : integer := 65536;

begin

    uut: LUT_Trig PORT MAP (
        clk => clk,
        rst => rst,
        x_in => x_in,
        mode_sin => mode_sin,
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
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for clk_period*2;

        report "--- STARTING LUT_TRIG TEST ---";

        -- === TEST COSINE (Mode = 0) ===
        mode_sin <= '0'; 

        -- Case 1: Cos(0) -> 1.0 (65536)
        x_in <= to_signed(0, 32);
        wait for clk_period * 5;
        report "Cos(0): " & integer'image(to_integer(y_out)) & " (Exp: 65536)";
        assert abs(to_integer(y_out) - VAL_ONE) < 50 severity warning;

        -- Case 2: Cos(Pi/2) -> 0.0
        x_in <= to_signed(HALF_PI, 32);
        wait for clk_period * 5;
        report "Cos(Pi/2): " & integer'image(to_integer(y_out)) & " (Exp: 0)";
        assert abs(to_integer(y_out)) < 100 severity warning;

        -- Case 3: Cos(Pi) -> -1.0 (-65536)
        x_in <= to_signed(PI_VAL, 32);
        wait for clk_period * 5;
        report "Cos(Pi): " & integer'image(to_integer(y_out)) & " (Exp: -65536)";
        assert abs(to_integer(y_out) - (-VAL_ONE)) < 50 severity warning;

        -- === TEST SINE (Mode = 1) ===
        mode_sin <= '1';

        -- Case 4: Sin(0) -> 0.0
        x_in <= to_signed(0, 32);
        wait for clk_period * 5;
        report "Sin(0): " & integer'image(to_integer(y_out)) & " (Exp: 0)";
        assert abs(to_integer(y_out)) < 50 severity warning;

        -- Case 5: Sin(Pi/2) -> 1.0
        x_in <= to_signed(HALF_PI, 32);
        wait for clk_period * 5;
        report "Sin(Pi/2): " & integer'image(to_integer(y_out)) & " (Exp: 65536)";
        assert abs(to_integer(y_out) - VAL_ONE) < 50 severity warning;

        -- Case 6: Sin(-Pi/2) -> -1.0
        x_in <= to_signed(-HALF_PI, 32);
        wait for clk_period * 5;
        report "Sin(-Pi/2): " & integer'image(to_integer(y_out)) & " (Exp: -65536)";
        assert abs(to_integer(y_out) - (-VAL_ONE)) < 50 severity warning;

        report "--- END OF TEST ---";
        wait;
    end process;

end Behavioral;