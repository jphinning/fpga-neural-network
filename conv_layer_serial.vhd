library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;
use work.pkg_model_constants.ALL;

entity Conv_Layer_Serial is
    Generic (
        N_FILTERS   : integer := 16;
        KERNEL_SIZE : integer := 4;
        M           : integer := 5  -- Memory Depth
    );
    Port ( 
        clk        : in  std_logic;
        rst        : in  std_logic;
        start      : in  std_logic;
        
        -- Buffers de Entrada
        buf_env    : in  data_array_t(0 to M);
        buf_cos    : in  data_array_t(0 to M);
        buf_sin    : in  data_array_t(0 to M);
        
        -- Saída
        x_flat_out : out data_array_t(0 to N_FILTERS-1);
        done       : out std_logic
    );
end Conv_Layer_Serial;

architecture Behavioral of Conv_Layer_Serial is

    constant CONV_BUFFER_SIZE : integer := M + 1;
    constant CONV_OUT_W       : integer := (M + 1) - KERNEL_SIZE + 1; 

    component Conv1D_Block
        Generic ( KERNEL_SIZE, BUFFER_SIZE : integer );
        Port ( 
            clk, rst, start : in std_logic; 
            buffer_in, weights_in : in data_array_t; 
            bias_in : in data_t; 
            conv_out : out data_array_t; 
            done : out std_logic
        );
    end component;

    component Pooling_ReLU_Block
        Generic ( INPUT_SIZE : integer );
        Port ( 
            clk, rst : in std_logic; 
            data_in_env, data_in_cos, data_in_sin : in data_array_t; 
            pool_reciprocal : in data_t; 
            data_out : out data_t 
        );
    end component;

    -- Sinais de Controle
    signal filter_idx : integer range 0 to N_FILTERS;
    signal sub_start  : std_logic := '0';
    signal sub_done   : std_logic; 
    
    -- [NOVO] Contador de espera para o Pooling
    signal pool_wait_cnt : integer range 0 to 5 := 0;
    
    -- Sinais de Dados
    signal w_env_curr, w_cos_curr, w_sin_curr : data_array_t(0 to KERNEL_SIZE-1);
    signal b_curr : data_t;
    
    signal res_env, res_cos, res_sin : data_array_t(0 to CONV_OUT_W-1);
    signal pool_res : data_t;
    
    signal ram_flat : data_array_t(0 to N_FILTERS-1);
    
    -- [NOVO] Estado WAIT_POOLING adicionado
    type state_t is (IDLE, LOAD_WEIGHTS, RUN_CONV, WAIT_POOLING, SAVE_RESULT, CHECK_LOOP, FINISHED);
    signal state : state_t := IDLE;

    -- Constante de Recíproco (Ajuste conforme necessário no pacote ou aqui)
    constant POOL_RECIP_VAL : data_t := to_signed(7282, 32); 

begin

    C_ENV : Conv1D_Block Generic Map(KERNEL_SIZE, CONV_BUFFER_SIZE)
    Port Map(clk, rst, sub_start, buf_env, w_env_curr, b_curr, res_env, open);

    C_COS : Conv1D_Block Generic Map(KERNEL_SIZE, CONV_BUFFER_SIZE)
    Port Map(clk, rst, sub_start, buf_cos, w_cos_curr, b_curr, res_cos, open);

    C_SIN : Conv1D_Block Generic Map(KERNEL_SIZE, CONV_BUFFER_SIZE)
    Port Map(clk, rst, sub_start, buf_sin, w_sin_curr, b_curr, res_sin, sub_done);

    POOL : Pooling_ReLU_Block Generic Map(CONV_OUT_W)
    Port Map(clk, rst, res_env, res_cos, res_sin, POOL_RECIP_VAL, pool_res);

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                filter_idx <= 0;
                done <= '0';
                sub_start <= '0';
                pool_wait_cnt <= 0;
            else
                case state is
                    when IDLE =>
                        done <= '0';
                        if start = '1' then
                            filter_idx <= 0;
                            state <= LOAD_WEIGHTS;
                        end if;

                    when LOAD_WEIGHTS =>
                        -- Configura Pesos
                        w_env_curr <= W_CONV1_WEIGHTS((filter_idx*KERNEL_SIZE) to (filter_idx*KERNEL_SIZE) + KERNEL_SIZE - 1);
                        w_cos_curr <= W_CONV1_WEIGHTS((filter_idx*KERNEL_SIZE) to (filter_idx*KERNEL_SIZE) + KERNEL_SIZE - 1);
                        w_sin_curr <= W_CONV1_WEIGHTS((filter_idx*KERNEL_SIZE) to (filter_idx*KERNEL_SIZE) + KERNEL_SIZE - 1);
                        b_curr <= W_CONV1_BIAS(filter_idx);
                        
                        sub_start <= '1';
                        state <= RUN_CONV;

                    when RUN_CONV =>
                        sub_start <= '0';
                        if sub_done = '1' then
                            -- Convolução terminou. Agora precisamos dar tempo ao Pooling.
                            pool_wait_cnt <= 0;
                            state <= WAIT_POOLING; -- [MUDANÇA AQUI]
                        end if;
                        
                    when WAIT_POOLING =>
                        -- O Pooling_ReLU_Block tem latência de 2 ciclos.
                        -- Damos 3 ciclos de margem para garantir estabilidade.
                        if pool_wait_cnt < 3 then
                            pool_wait_cnt <= pool_wait_cnt + 1;
                        else
                            state <= SAVE_RESULT;
                        end if;
                        
                    when SAVE_RESULT =>
                        -- Agora pool_res deve conter o valor válido (ex: 32664)
                        ram_flat(filter_idx) <= pool_res;
                        state <= CHECK_LOOP;

                    when CHECK_LOOP =>
                        if filter_idx < N_FILTERS - 1 then
                            filter_idx <= filter_idx + 1;
                            state <= LOAD_WEIGHTS;
                        else
                            state <= FINISHED;
                        end if;

                    when FINISHED =>
                        x_flat_out <= ram_flat;
                        done <= '1';
                        state <= IDLE;
                        
                end case;
            end if;
        end if;
    end process;

end Behavioral;