library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Input_Processing_Block is
    Port ( 
        clk                : in  std_logic;
        rst                : in  std_logic;
        
        i_in               : in  data_t;
        q_in               : in  data_t;
        input_valid        : in  std_logic;
        
        envelope_out       : out data_t;
        theta_unwrapped_out: out data_t;
        theta_norm_out     : out data_t;
        
        -- [NEW PORT] Original Wrapped Phase for Output Rotation
        phase_wrapped_out  : out data_t; 
        
        buffers_enable     : out std_logic
    );
end Input_Processing_Block;

architecture Behavioral of Input_Processing_Block is

    component cordic_rect_to_polar
    port (
        clk : in std_logic;
        x_in : in std_logic_vector(31 downto 0);
        y_in : in std_logic_vector(31 downto 0);
        x_out : out std_logic_vector(31 downto 0);
        phase_out : out std_logic_vector(31 downto 0)
    );
    end component;

    constant PI_FIXED : data_t := to_signed(205887, 32); 
    constant TWO_PI   : data_t := to_signed(411774, 32);
    constant CORDIC_INV_GAIN : signed(31 downto 0) := to_signed(56281, 32);
    constant CORDIC_LATENCY : integer := 40; 

    signal cordic_x_slv, cordic_y_slv : std_logic_vector(31 downto 0);
    signal cordic_mag_slv, cordic_pha_slv : std_logic_vector(31 downto 0);
    
    signal envelope_raw, envelope_s, phase_raw : data_t;
    signal phase_high_res : signed(31 downto 0);
    signal env_mult_long : signed(63 downto 0);
    
    signal valid_sr : std_logic_vector(CORDIC_LATENCY downto 0) := (others => '0');
    signal buffers_enable_int : std_logic := '0';

    signal last_phase_wrapped, last_phase_unwrapped : data_t := (others => '0');
    signal theta_unwrapped_reg, theta_norm_reg : data_t := (others => '0');

begin

    cordic_x_slv <= std_logic_vector(i_in);
    cordic_y_slv <= std_logic_vector(q_in);

    CORDIC_INST : cordic_rect_to_polar
    port map (
        clk => clk, x_in => cordic_x_slv, y_in => cordic_y_slv,
        x_out => cordic_mag_slv, phase_out => cordic_pha_slv
    );

    -- Envelope Gain Correction
    envelope_raw <= signed(cordic_mag_slv);
    env_mult_long <= envelope_raw * CORDIC_INV_GAIN;
    envelope_s <= env_mult_long(47 downto 16);

    -- Phase Scale Correction
    phase_high_res <= signed(cordic_pha_slv);
    phase_raw <= resize(shift_right(phase_high_res, 13), 32);

    -- Delay Line
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then valid_sr <= (others => '0');
            else valid_sr <= valid_sr(CORDIC_LATENCY-1 downto 0) & input_valid; end if;
        end if;
    end process;
    
    buffers_enable_int <= valid_sr(CORDIC_LATENCY);
    buffers_enable     <= buffers_enable_int;

    -- Phase Logic
    process(clk)
        variable diff : data_t;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                last_phase_wrapped <= (others => '0'); last_phase_unwrapped <= (others => '0');
                theta_unwrapped_reg <= (others => '0'); theta_norm_reg <= (others => '0');
                envelope_out <= (others => '0');
                phase_wrapped_out <= (others => '0');
            elsif buffers_enable_int = '1' then
                diff := phase_raw - last_phase_wrapped;
                if diff > PI_FIXED then diff := diff - TWO_PI; elsif diff < -PI_FIXED then diff := diff + TWO_PI; end if;
                
                theta_unwrapped_reg <= last_phase_unwrapped + diff;
                
                last_phase_wrapped <= phase_raw;
                last_phase_unwrapped <= last_phase_unwrapped + diff;
                
                theta_norm_out <= diff;
                envelope_out   <= envelope_s;
                
                -- [NEW] Pass the raw wrapped phase out for the final stage
                phase_wrapped_out <= phase_raw; 
            end if;
        end if;
    end process;
    
    theta_unwrapped_out <= theta_unwrapped_reg;

end Behavioral;