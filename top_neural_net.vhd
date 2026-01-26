library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;
use work.pkg_model_constants.ALL; -- Necessário para os pesos das MLPs e Conv

entity Top_NeuralNet_S3 is
    Port ( 
        clk          : in  std_logic;
        rst          : in  std_logic;
        
        i_in         : in  data_t;
        q_in         : in  data_t;
        input_valid  : in  std_logic; 
        
        -- Saídas de Verificação S3
        real_mlp_out : out data_t;
        imag_mlp_out : out data_t;
        
        -- Indica que as MLPs terminaram
        stage_valid  : out std_logic 
    );
end Top_NeuralNet_S3;

architecture Behavioral of Top_NeuralNet_S3 is

    -- Componentes
    -- [REMOVIDO] component Top_NeuralNet_S2 (Não estamos usando, repetimos a estrutura abaixo)
    
    component Input_Processing_Block
        Port ( clk, rst : in std_logic; i_in, q_in : in data_t; input_valid : in std_logic; 
               envelope_out, theta_unwrapped_out, theta_norm_out : out data_t; buffers_enable : out std_logic );
    end component;
    
    component LUT_Trig
        Port ( clk, rst : in std_logic; x_in : in data_t; mode_sin : in std_logic; y_out : out data_t );
    end component;
    
    component Shift_Register
        Generic ( DEPTH : integer );
        Port ( clk, rst, enable : in std_logic; data_in : in data_t; data_out : out data_array_t(0 to DEPTH) );
    end component;
    
    component Conv_Layer_Serial
        Generic ( N_FILTERS, KERNEL_SIZE, M : integer );
        Port ( clk, rst, start : in std_logic; buf_env, buf_cos, buf_sin : in data_array_t; x_flat_out : out data_array_t; done : out std_logic );
    end component;

    component MLP_Chain_Serial
        Port ( 
            clk, rst, start : in std_logic;
            input_vec : in data_array_t;
            w_L1, w_L2, w_L3 : in data_array_t; 
            b_L1, b_L2, b_L3 : in data_array_t;
            mlp_out : out data_t;
            done : out std_logic
        );
    end component;

    -- Constantes e Sinais
    constant M : integer := 5; 
    constant N_FILTERS : integer := 16;
    constant KERNEL_SIZE : integer := 4;
    constant LUT_LATENCY : integer := 4;
    constant CORDIC_LATENCY : integer := 40;

    signal envelope_s, theta_unwrapped, theta_norm : data_t;
    signal buffers_enable_raw, buffers_write_en : std_logic;
    signal cos_dp, sin_dp : data_t;
    signal enable_delay : std_logic_vector(0 to LUT_LATENCY-1);
    signal env_delay : data_array_t(0 to LUT_LATENCY-1);
    signal envelope_aligned : data_t;
    signal buf_env, buf_cos, buf_sin : data_array_t(0 to M);
    
    signal conv_start, conv_done : std_logic;
    signal x_flat : data_array_t(0 to 15);
    
    -- Sinais MLP
    signal mlp_start : std_logic;
    signal real_done, imag_done : std_logic;
    
    -- FSM de Controle Global
    type fsm_t is (IDLE, START_CONV, WAIT_CONV, START_MLP, WAIT_MLP, DONE_STATE);
    signal state : fsm_t := IDLE;

begin

    -- 1. INPUT PROCESSING
    INPUT_BLOCK : Input_Processing_Block
    port map (clk, rst, i_in, q_in, input_valid, envelope_s, theta_unwrapped, theta_norm, buffers_enable_raw);

    LUT_COS : LUT_Trig port map(clk, rst, theta_norm, '0', cos_dp);
    LUT_SIN : LUT_Trig port map(clk, rst, theta_norm, '1', sin_dp);
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then enable_delay <= (others => '0'); env_delay <= (others => (others => '0'));
            else
                enable_delay(1 to LUT_LATENCY-1) <= enable_delay(0 to LUT_LATENCY-2);
                enable_delay(0) <= buffers_enable_raw;
                env_delay(1 to LUT_LATENCY-1) <= env_delay(0 to LUT_LATENCY-2);
                env_delay(0) <= envelope_s;
            end if;
        end if;
    end process;
    buffers_write_en <= enable_delay(LUT_LATENCY-1);
    envelope_aligned <= env_delay(LUT_LATENCY-1);

    -- 2. BUFFERS
    BUF_E : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, envelope_aligned, buf_env);
    BUF_C : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, cos_dp,           buf_cos);
    BUF_S : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, sin_dp,           buf_sin);

    -- 3. CONV LAYER
    CONV_LAYER : Conv_Layer_Serial Generic Map (N_FILTERS, KERNEL_SIZE, M)
    Port Map (clk, rst, conv_start, buf_env, buf_cos, buf_sin, x_flat, conv_done);

    -- 4. MLP CHAINS
    -- Real Path
    MLP_REAL : MLP_Chain_Serial
    Port Map (
        clk => clk, rst => rst, start => mlp_start,
        input_vec => x_flat,
        w_L1 => W_REAL_FC0_W, b_L1 => W_REAL_FC0_B, 
        w_L2 => W_REAL_FC2_W, b_L2 => W_REAL_FC2_B,
        w_L3 => W_REAL_FC4_W, b_L3 => W_REAL_FC4_B,
        mlp_out => real_mlp_out,
        done => real_done
    );

    -- Imag Path
    MLP_IMAG : MLP_Chain_Serial
    Port Map (
        clk => clk, rst => rst, start => mlp_start,
        input_vec => x_flat,
        w_L1 => W_IMAG_FC0_W, b_L1 => W_IMAG_FC0_B,
        w_L2 => W_IMAG_FC2_W, b_L2 => W_IMAG_FC2_B,
        w_L3 => W_IMAG_FC4_W, b_L3 => W_IMAG_FC4_B,
        mlp_out => imag_mlp_out,
        done => imag_done
    );

    -- 5. FSM GLOBAL
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                conv_start <= '0';
                mlp_start <= '0';
                stage_valid <= '0';
            else
                case state is
                    when IDLE =>
                        stage_valid <= '0';
                        if buffers_write_en = '1' then state <= START_CONV; end if;
                    
                    when START_CONV => conv_start <= '1'; state <= WAIT_CONV;
                    when WAIT_CONV => conv_start <= '0'; if conv_done = '1' then state <= START_MLP; end if;
                    
                    when START_MLP => mlp_start <= '1'; state <= WAIT_MLP;
                    
                    when WAIT_MLP => 
                        mlp_start <= '0';
                        if real_done = '1' and imag_done = '1' then
                            state <= DONE_STATE;
                        end if;
                        
                    when DONE_STATE =>
                        stage_valid <= '1';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;