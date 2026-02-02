library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Complex_Mult_Output_tb is
end Complex_Mult_Output_tb;

architecture Behavioral of Complex_Mult_Output_tb is

    -- 1. Updated Component Declaration
    component Complex_Mult_Output
    Port ( 
        clk     : in  std_logic;
        rst     : in  std_logic; -- Added
        en      : in  std_logic; -- Added
        real_in : in  data_t;
        imag_in : in  data_t;
        cos_in  : in  data_t;
        sin_in  : in  data_t;
        i_out   : out data_t;
        q_out   : out data_t
    );
    end component;
    
    -- 2. Signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal en  : std_logic := '0'; -- Control signal
    
    signal real_in : data_t := (others => '0');
    signal imag_in : data_t := (others => '0');
    signal cos_in  : data_t := (others => '0');
    signal sin_in  : data_t := (others => '0');

    signal i_out : data_t;
    signal q_out : data_t;

    constant clk_period : time := 10 ns;
    
    -- Constants Q16.16
    constant VAL_ONE      : data_t := to_signed(65536, 32);
    constant VAL_ZERO     : data_t := to_signed(0, 32);
    constant VAL_HALF     : data_t := to_signed(32768, 32); 
    constant VAL_NEG_ONE  : data_t := to_signed(-65536, 32);

begin

    uut: Complex_Mult_Output PORT MAP (
        clk     => clk,
        rst     => rst,
        en      => en,
        real_in => real_in,
        imag_in => imag_in,
        cos_in  => cos_in,
        sin_in  => sin_in,
        i_out   => i_out,
        q_out   => q_out
    );

    -- Clock Generation
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus
    stim_proc: process
    begin
        -- Reset / Setup
        rst <= '1';
        en  <= '0';
        wait for 100 ns;    
        wait until falling_edge(clk);
        rst <= '0';
        wait for clk_period;

        report "--- STARTING TEST: Complex_Mult_Output ---";

        -- CASE 1: Identity (Rotation by 0 degrees)
        -- Input: 1 + j0, Rot: Cos=1, Sin=0
        real_in <= VAL_ONE;
        imag_in <= VAL_ZERO;
        cos_in  <= VAL_ONE;
        sin_in  <= VAL_ZERO;
        
        -- Pulse Enable
        wait until falling_edge(clk);
        en <= '1';
        wait for clk_period; 
        en <= '0'; -- Turn off enable to test Hold
        
        -- Check Result (Output is registered, available after clock edge)
        wait for 1 ns; 
        assert i_out = VAL_ONE report "Fail Case 1: I_out incorrect" severity error;
        assert q_out = VAL_ZERO report "Fail Case 1: Q_out incorrect" severity error;
        
        -- Wait a bit to verify HOLD behavior
        wait for clk_period * 2;
        -- Changing inputs shouldn't change output if EN=0
        real_in <= VAL_ZERO; 
        wait for clk_period;
        assert i_out = VAL_ONE report "Fail Hold: Output changed without Enable" severity error;

        -- CASE 2: Rotation by 90 degrees
        -- Input: 1 + j0, Rot: Cos=0, Sin=1
        real_in <= VAL_ONE;
        imag_in <= VAL_ZERO;
        cos_in  <= VAL_ZERO;
        sin_in  <= VAL_ONE;
        
        wait until falling_edge(clk);
        en <= '1';
        wait for clk_period;
        en <= '0';
        
        wait for 1 ns;
        assert i_out = VAL_ZERO report "Fail Case 2: I_out incorrect" severity error;
        assert q_out = VAL_ONE  report "Fail Case 2: Q_out incorrect" severity error;

        -- CASE 3: Complex Input Rotation
        -- Input: 0 + j1, Rot: Cos=0, Sin=1
        -- Expected: -1 + j0
        real_in <= VAL_ZERO;
        imag_in <= VAL_ONE;
        cos_in  <= VAL_ZERO;
        sin_in  <= VAL_ONE;
        
        wait until falling_edge(clk);
        en <= '1';
        wait for clk_period;
        en <= '0';
        
        wait for 1 ns;
        assert i_out = VAL_NEG_ONE report "Fail Case 3: I_out incorrect" severity error;
        assert q_out = VAL_ZERO report "Fail Case 3: Q_out incorrect" severity error;

        -- CASE 4: Scaling (Fractional Multiply)
        -- Input: 2.0 + j0, Rot: Cos=0.5, Sin=0
        -- Expected: 1.0 + j0
        real_in <= to_signed(131072, 32); -- 2.0
        imag_in <= VAL_ZERO;
        cos_in  <= VAL_HALF; -- 0.5
        sin_in  <= VAL_ZERO;
        
        wait until falling_edge(clk);
        en <= '1';
        wait for clk_period;
        en <= '0';
        
        wait for 1 ns;
        if (to_integer(i_out) >= 65535) and (to_integer(i_out) <= 65537) then
             report "Case 4 Success: Scaling OK";
        else
             report "Fail Case 4: Scaling incorrect. I_out=" & integer'image(to_integer(i_out)) severity error;
        end if;

        report "--- TEST FINISHED ---";
        wait;
    end process;

end Behavioral;