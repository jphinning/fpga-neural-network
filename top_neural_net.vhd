library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;
-- Não precisamos do pkg_model_constants aqui, pois ele é usado dentro da Conv_Layer_Serial

entity Top_NeuralNet_S2 is
    Port ( 
        clk          : in  std_logic;
        rst          : in  std_logic;
        
        -- Entradas
        i_in         : in  data_t;
        q_in         : in  data_t;
        input_valid  : in  std_logic; 
        
        -- Saídas de Verificação (S2)
        -- Expomos o vetor completo de 16 filtros
        x_flat_out   : out data_array_t(0 to 15);
        
        -- Indica que a convolução terminou e x_flat_out é válido
        stage_valid  : out std_logic 
    );
end Top_NeuralNet_S2;

architecture Behavioral of Top_NeuralNet_S2 is

    -- Componentes
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

    -- Parâmetros
    constant M : integer := 5; 
    constant N_FILTERS : integer := 16;
    constant KERNEL_SIZE : integer := 4;
    constant LUT_LATENCY : integer := 4; -- Latência da LUT_Trig

    -- Sinais Internos
    signal envelope_s, theta_unwrapped, theta_norm : data_t;
    signal buffers_enable_raw : std_logic;
    signal cos_dp, sin_dp : data_t;
    
    -- Delay Lines (Alinhamento Envelope vs LUTs)
    signal enable_delay : std_logic_vector(0 to LUT_LATENCY-1);
    signal env_delay    : data_array_t(0 to LUT_LATENCY-1);
    
    signal buffers_write_en : std_logic;
    signal envelope_aligned : data_t;
    
    -- Buffers
    signal buf_env, buf_cos, buf_sin : data_array_t(0 to M);
    
    -- Sinais de Controle Conv
    signal conv_start : std_logic;

begin

    -- ========================================================================
    -- ESTÁGIO 1: PRÉ-PROCESSAMENTO E ALINHAMENTO
    -- ========================================================================
    
    INPUT_BLOCK : Input_Processing_Block
    port map (
        clk => clk, rst => rst, i_in => i_in, q_in => q_in, input_valid => input_valid,
        envelope_out => envelope_s, theta_unwrapped_out => theta_unwrapped, theta_norm_out => theta_norm,
        buffers_enable => buffers_enable_raw
    );

    -- Caminho Paralelo A: Fase -> LUTs (Demora LUT_LATENCY ciclos)
    LUT_COS : LUT_Trig port map(clk, rst, theta_norm, '0', cos_dp);
    LUT_SIN : LUT_Trig port map(clk, rst, theta_norm, '1', sin_dp);
    
    -- Caminho Paralelo B: Envelope -> Delay Line (Para esperar a LUT)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                enable_delay <= (others => '0');
                env_delay <= (others => (others => '0'));
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

    -- ========================================================================
    -- ESTÁGIO 2: BUFFERS
    -- ========================================================================
    BUF_E : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, envelope_aligned, buf_env);
    BUF_C : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, cos_dp,           buf_cos);
    BUF_S : Shift_Register Generic Map(M) Port Map(clk, rst, buffers_write_en, sin_dp,           buf_sin);

    -- ========================================================================
    -- ESTÁGIO 3: CONVOLUÇÃO
    -- ========================================================================
    
    -- O 'start' da convolução é o próprio pulso de escrita dos buffers.
    -- Assim que o dado entra no buffer, a convolução começa.
    conv_start <= buffers_write_en;

    CONV_LAYER : Conv_Layer_Serial 
    Generic Map (
        N_FILTERS   => N_FILTERS,
        KERNEL_SIZE => KERNEL_SIZE,
        M           => M
    )
    Port Map (
        clk        => clk,
        rst        => rst,
        start      => conv_start,
        buf_env    => buf_env,
        buf_cos    => buf_cos,
        buf_sin    => buf_sin,
        x_flat_out => x_flat_out,
        done       => stage_valid -- A saída stage_valid sobe quando a conv termina
    );

end Behavioral;