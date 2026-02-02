--------------------------------------------------------------------------------
-- Complete Neural Network Integration (Production Version)
-- Pipeline: Input Processing -> Conv Layer -> MLP Backend -> Output
-- Properly handles theta propagation from Stage 1 to Stage 3
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity NeuralNet_Complete is
    Generic (
        M           : integer := 5;   -- Memory depth
        N_FILTERS   : integer := 16;  -- Number of conv filters
        KERNEL_SIZE : integer := 4    -- Conv kernel size
    );
    Port ( 
        clk          : in  std_logic;
        rst          : in  std_logic;
        
        -- Raw IQ Input
        i_in         : in  data_t;
        q_in         : in  data_t;
        input_valid  : in  std_logic;
        
        -- Final Output
        i_out        : out data_t;
        q_out        : out data_t;
        output_valid : out std_logic;
        
        -- Debug/Status Signals
        processing   : out std_logic;  -- High when network is processing
        net_ready    : out std_logic   -- High when ready for new input
    );
end NeuralNet_Complete;

architecture Behavioral of NeuralNet_Complete is

    -- ========================================================================
    -- Component Declarations
    -- ========================================================================
    
    component Top_NeuralNet_S1
        Port ( 
            clk                 : in  std_logic;
            rst                 : in  std_logic;
            i_in                : in  data_t;
            q_in                : in  data_t;
            input_valid         : in  std_logic;
            buf_env_out         : out data_array_t(0 to 5);
            buf_cos_out         : out data_array_t(0 to 5);
            buf_sin_out         : out data_array_t(0 to 5);
            theta_unwrapped_out : out data_t;
            stage_valid         : out std_logic
        );
    end component;

    component Conv_Layer_Serial
        Generic (
            N_FILTERS   : integer := 16;
            KERNEL_SIZE : integer := 4;
            M           : integer := 5
        );
        Port ( 
            clk        : in  std_logic;
            rst        : in  std_logic;
            start      : in  std_logic;
            buf_env    : in  data_array_t(0 to M);
            buf_cos    : in  data_array_t(0 to M);
            buf_sin    : in  data_array_t(0 to M);
            x_flat_out : out data_array_t(0 to N_FILTERS-1);
            done       : out std_logic
        );
    end component;

    component BackEnd_Wrapper
        Port ( 
            clk        : in  std_logic;
            rst        : in  std_logic;
            start      : in  std_logic;
            x_flat_in  : in  data_array_t(0 to 15);
            theta_in   : in  data_t;
            i_out      : out data_t;
            q_out      : out data_t;
            done       : out std_logic
        );
    end component;

    -- ========================================================================
    -- Internal Signals
    -- ========================================================================
    
    -- Stage 1 Outputs
    signal buf_env : data_array_t(0 to M);
    signal buf_cos : data_array_t(0 to M);
    signal buf_sin : data_array_t(0 to M);
    signal theta_current : data_t;
    signal s1_valid : std_logic;
    
    -- Stage 2 Outputs
    signal x_flat : data_array_t(0 to N_FILTERS-1);
    signal s2_done : std_logic;
    
    -- Stage 3 Outputs
    signal s3_done : std_logic;
    
    -- Control Signals
    signal conv_start : std_logic;
    signal backend_start : std_logic;
    
    -- Theta Register (captured when starting Conv)
    signal theta_captured : data_t;
    
    -- Sample Counter (for warmup)
    signal sample_count : integer range 0 to 15 := 0;
    constant WARMUP_SAMPLES : integer := M;
    signal warmup_done : std_logic := '0';
    
    -- Main FSM
    type state_t is (
        WARMUP,         -- Filling buffers initially
        READY,          -- Ready to process new sample
        START_CONV,     -- Trigger conv layer
        WAIT_CONV,      -- Wait for conv to finish
        START_BACKEND,  -- Trigger backend
        WAIT_BACKEND,   -- Wait for backend to finish
        OUTPUT_VALID_ST -- Output is valid
    );
    signal state : state_t := WARMUP;
    
    -- Internal signals for status outputs (to avoid reading from outputs)
    signal ready_internal : std_logic := '0';
    signal processing_internal : std_logic := '0';

begin

    -- ========================================================================
    -- Stage 1: Input Processing & Buffer Management
    -- ========================================================================
    STAGE1 : Top_NeuralNet_S1
    port map (
        clk                 => clk,
        rst                 => rst,
        i_in                => i_in,
        q_in                => q_in,
        input_valid         => input_valid,
        buf_env_out         => buf_env,
        buf_cos_out         => buf_cos,
        buf_sin_out         => buf_sin,
        theta_unwrapped_out => theta_current,
        stage_valid         => s1_valid
    );

    -- ========================================================================
    -- Stage 2: Convolutional Layer
    -- ========================================================================
    STAGE2 : Conv_Layer_Serial
    generic map (
        N_FILTERS   => N_FILTERS,
        KERNEL_SIZE => KERNEL_SIZE,
        M           => M
    )
    port map (
        clk        => clk,
        rst        => rst,
        start      => conv_start,
        buf_env    => buf_env,
        buf_cos    => buf_cos,
        buf_sin    => buf_sin,
        x_flat_out => x_flat,
        done       => s2_done
    );

    -- ========================================================================
    -- Stage 3: Backend (MLP + Output Logic)
    -- ========================================================================
    STAGE3 : BackEnd_Wrapper
    port map (
        clk       => clk,
        rst       => rst,
        start     => backend_start,
        x_flat_in => x_flat,
        theta_in  => theta_captured,  -- Use captured theta
        i_out     => i_out,
        q_out     => q_out,
        done      => s3_done
    );

    -- ========================================================================
    -- Main Control FSM
    -- ========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= WARMUP;
                sample_count <= 0;
                warmup_done <= '0';
                conv_start <= '0';
                backend_start <= '0';
                output_valid <= '0';
                theta_captured <= (others => '0');
                processing_internal <= '0';
                ready_internal <= '0';
                
            else
                -- Default: De-assert one-cycle signals
                conv_start <= '0';
                backend_start <= '0';
                output_valid <= '0';
                
                case state is
                    
                    -- ================================================
                    -- WARMUP: Fill buffers with M+1 samples
                    -- ================================================
                    when WARMUP =>
                        ready_internal <= '0';
                        processing_internal <= '0';
                        
                        if s1_valid = '1' then
                            sample_count <= sample_count + 1;
                            
                            if sample_count >= WARMUP_SAMPLES then
                                warmup_done <= '1';
                                state <= READY;
                            end if;
                        end if;
                    
                    -- ================================================
                    -- READY: Wait for new valid sample
                    -- ================================================
                    when READY =>
                        ready_internal <= '1';
                        processing_internal <= '0';
                        
                        if s1_valid = '1' then
                            -- Capture theta at this moment
                            theta_captured <= theta_current;
                            state <= START_CONV;
                        end if;
                    
                    -- ================================================
                    -- START_CONV: Trigger convolutional layer
                    -- ================================================
                    when START_CONV =>
                        ready_internal <= '0';
                        processing_internal <= '1';
                        conv_start <= '1';
                        state <= WAIT_CONV;
                    
                    -- ================================================
                    -- WAIT_CONV: Wait for conv to complete
                    -- ================================================
                    when WAIT_CONV =>
                        processing_internal <= '1';
                        
                        if s2_done = '1' then
                            state <= START_BACKEND;
                        end if;
                    
                    -- ================================================
                    -- START_BACKEND: Trigger backend (MLP + output)
                    -- ================================================
                    when START_BACKEND =>
                        processing_internal <= '1';
                        backend_start <= '1';
                        state <= WAIT_BACKEND;
                    
                    -- ================================================
                    -- WAIT_BACKEND: Wait for backend to complete
                    -- ================================================
                    when WAIT_BACKEND =>
                        processing_internal <= '1';
                        
                        if s3_done = '1' then
                            state <= OUTPUT_VALID_ST;
                        end if;
                    
                    -- ================================================
                    -- OUTPUT_VALID_ST: Signal output is valid
                    -- ================================================
                    when OUTPUT_VALID_ST =>
                        processing_internal <= '0';
                        output_valid <= '1';
                        
                        -- Return to ready state for next sample
                        state <= READY;
                        
                end case;
            end if;
        end if;
    end process;
    
    -- Connect internal signals to outputs
    processing <= processing_internal;
    net_ready <= ready_internal;

end Behavioral;