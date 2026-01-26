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
        
        -- Outputs (Buffer States for Verification)
        buf_env_out  : out data_array_t(0 to 5); -- M=5
        buf_cos_out  : out data_array_t(0 to 5);
        buf_sin_out  : out data_array_t(0 to 5);
        
        -- Control Output
        stage_valid  : out std_logic -- Pulses when buffers update
    );
end Top_NeuralNet_S1;

architecture Behavioral of Top_NeuralNet_S1 is

    -- 1. Input Processing (Validated Block)
    component Input_Processing_Block
        Port ( 
            clk                : in  std_logic;
            rst                : in  std_logic;
            i_in               : in  data_t;
            q_in               : in  data_t;
            input_valid        : in  std_logic;
            envelope_out       : out data_t;
            theta_unwrapped_out: out data_t;
            theta_norm_out     : out data_t;
            buffers_enable     : out std_logic
        );
    end component;

    -- 2. LUTs (Validated Block)
    component LUT_Trig
        Port ( 
            clk      : in  std_logic;
            rst      : in  std_logic;
            x_in     : in  data_t;
            mode_sin : in  std_logic;
            y_out    : out data_t
        );
    end component;

    -- 3. Shift Register (Validated Block)
    component Shift_Register
        Generic ( DEPTH : integer );
        Port ( 
            clk      : in  std_logic;
            rst      : in  std_logic;
            enable   : in  std_logic;
            data_in  : in  data_t;
            data_out : out data_array_t
        );
    end component;

    -- Constants
    constant M : integer := 5;
    constant LUT_LATENCY : integer := 4; -- LUT_Trig pipeline depth

    -- Internal Signals
    signal envelope_s, theta_unwrapped, theta_norm : data_t;
    signal buffers_enable_raw : std_logic;
    
    signal cos_dp, sin_dp : data_t;
    
    -- Delay Lines for Synchronization
    -- We need to delay the 'enable' and 'envelope' signals to match the LUT latency
    signal enable_delay : std_logic_vector(0 to LUT_LATENCY-1);
    signal env_delay    : data_array_t(0 to LUT_LATENCY-1);
    
    signal buffers_write_en : std_logic;
    signal envelope_aligned : data_t;

begin

    -- ========================================================================
    -- 1. INPUT PROCESSING BLOCK (CORDIC + Phase Logic)
    -- ========================================================================
    INPUT_BLOCK : Input_Processing_Block
    port map (
        clk                 => clk,
        rst                 => rst,
        i_in                => i_in,
        q_in                => q_in,
        input_valid         => input_valid,
        envelope_out        => envelope_s,
        theta_unwrapped_out => theta_unwrapped,
        theta_norm_out      => theta_norm,
        buffers_enable      => buffers_enable_raw
    );

    -- ========================================================================
    -- 2. PARALLEL PATHS ALIGNMENT
    -- ========================================================================
    
    -- Path A: Phase -> LUTs -> Cos/Sin (Takes LUT_LATENCY cycles)
    LUT_COS : LUT_Trig port map(clk, rst, theta_norm, '0', cos_dp);
    LUT_SIN : LUT_Trig port map(clk, rst, theta_norm, '1', sin_dp);
    
    -- Path B & C: Delay Envelope and Enable to match LUTs
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                enable_delay <= (others => '0');
                env_delay <= (others => (others => '0'));
            else
                -- Shift Enable
                enable_delay(1 to LUT_LATENCY-1) <= enable_delay(0 to LUT_LATENCY-2);
                enable_delay(0) <= buffers_enable_raw;
                
                -- Shift Envelope Data
                env_delay(1 to LUT_LATENCY-1) <= env_delay(0 to LUT_LATENCY-2);
                env_delay(0) <= envelope_s;
            end if;
        end if;
    end process;
    
    buffers_write_en <= enable_delay(LUT_LATENCY-1);
    envelope_aligned <= env_delay(LUT_LATENCY-1);
    
    -- ========================================================================
    -- 3. BUFFERS (SHIFT REGISTERS)
    -- ========================================================================
    BUF_E : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, envelope_aligned, buf_env_out);
    BUF_C : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, cos_dp,           buf_cos_out);
    BUF_S : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, sin_dp,           buf_sin_out);

    -- Output Control Signal
    stage_valid <= buffers_write_en;

end Behavioral;