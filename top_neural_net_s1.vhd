--------------------------------------------------------------------------------
-- Enhanced Stage 1 Wrapper
-- Outputs theta_unwrapped which is needed for the backend recombination
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Top_NeuralNet_S1 is
    Port ( 
        clk          : in  std_logic;
        rst          : in  std_logic;
        
        -- Inputs
        i_in         : in  data_t;
        q_in         : in  data_t;
        input_valid  : in  std_logic;
        
        -- Outputs (Buffer States)
        buf_env_out  : out data_array_t(0 to 5); -- M=5
        buf_cos_out  : out data_array_t(0 to 5);
        buf_sin_out  : out data_array_t(0 to 5);
        
        -- Theta sincronizado para o backend
        theta_unwrapped_out : out data_t;
        
        -- Control Output
        stage_valid  : out std_logic
    );
end Top_NeuralNet_S1;

architecture Behavioral of Top_NeuralNet_S1 is

    component Input_Processing_Block
        Port ( 
            clk, rst : in std_logic; 
            i_in, q_in : in data_t; 
            input_valid : in std_logic; 
            envelope_out, theta_unwrapped_out, theta_norm_out : out data_t;
            phase_wrapped_out : out data_t; -- [IMPORTANTE] Porta da Fase Crua
            buffers_enable : out std_logic 
        );
    end component;

    component LUT_Trig
        Port ( clk, rst : in std_logic; x_in : in data_t; mode_sin : in std_logic; y_out : out data_t );
    end component;

    component Shift_Register
        Generic ( DEPTH : integer );
        Port ( clk, rst, enable : in std_logic; data_in : in data_t; data_out : out data_array_t );
    end component;

    constant M : integer := 5;
    constant LUT_LATENCY : integer := 4;

    signal envelope_s, theta_unwrapped, theta_norm, phase_wrapped : data_t;
    signal buffers_enable_raw : std_logic;
    
    signal cos_dp, sin_dp : data_t;
    
    -- Delay Lines
    signal enable_delay : std_logic_vector(0 to LUT_LATENCY-1);
    signal env_delay    : data_array_t(0 to LUT_LATENCY-1);
    
    -- Delay Line para Theta
    signal theta_delay  : data_array_t(0 to LUT_LATENCY-1);
    
    signal buffers_write_en : std_logic;
    signal envelope_aligned : data_t;
    signal theta_aligned    : data_t;

begin

    INPUT_BLOCK : Input_Processing_Block
    port map (
        clk => clk, rst => rst, i_in => i_in, q_in => q_in, input_valid => input_valid,
        envelope_out => envelope_s, 
        theta_unwrapped_out => theta_unwrapped, -- Usado internamente para delta
        theta_norm_out => theta_norm,
        phase_wrapped_out => phase_wrapped,     -- [IMPORTANTE] Usado para saída
        buffers_enable => buffers_enable_raw
    );

    LUT_COS : LUT_Trig port map(clk, rst, theta_norm, '0', cos_dp);
    LUT_SIN : LUT_Trig port map(clk, rst, theta_norm, '1', sin_dp);
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                enable_delay <= (others => '0');
                env_delay <= (others => (others => '0'));
                theta_delay <= (others => (others => '0'));
            else
                -- Shift Enable
                enable_delay(1 to LUT_LATENCY-1) <= enable_delay(0 to LUT_LATENCY-2);
                enable_delay(0) <= buffers_enable_raw;
                
                -- Shift Envelope Data
                env_delay(1 to LUT_LATENCY-1) <= env_delay(0 to LUT_LATENCY-2);
                env_delay(0) <= envelope_s;
                
                -- [CORREÇÃO] Shift Theta usando phase_wrapped (Raw -PI a +PI)
                -- Não usar theta_unwrapped aqui, pois ele estoura a LUT!
                theta_delay(1 to LUT_LATENCY-1) <= theta_delay(0 to LUT_LATENCY-2);
                theta_delay(0) <= phase_wrapped; 
            end if;
        end if;
    end process;
    
    buffers_write_en <= enable_delay(LUT_LATENCY-1);
    envelope_aligned <= env_delay(LUT_LATENCY-1);
    
    theta_aligned    <= theta_delay(LUT_LATENCY-1);
    
    BUF_E : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, envelope_aligned, buf_env_out);
    BUF_C : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, cos_dp,           buf_cos_out);
    BUF_S : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, sin_dp,           buf_sin_out);

    stage_valid <= buffers_write_en;
    theta_unwrapped_out <= theta_aligned;

end Behavioral;