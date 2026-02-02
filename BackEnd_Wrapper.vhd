library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;
use work.pkg_model_constants.ALL;

entity BackEnd_Wrapper is
    Port ( 
        clk        : in  std_logic;
        rst        : in  std_logic;
        start      : in  std_logic;
        
        -- Entradas do Back-End
        x_flat_in  : in  data_array_t(0 to 15);
        theta_in   : in  data_t;
        
        -- Saídas Finais
        i_out      : out data_t;
        q_out      : out data_t;
        done       : out std_logic
    );
end BackEnd_Wrapper;

architecture Behavioral of BackEnd_Wrapper is

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

    component LUT_Trig
        Port ( clk, rst : in std_logic; x_in : in data_t; mode_sin : in std_logic; y_out : out data_t );
    end component;
    
    component Complex_Mult_Output
        Port ( clk, rst, en : in std_logic; real_in, imag_in, cos_in, sin_in : in data_t; i_out, q_out : out data_t );
    end component;

    signal real_mlp_out, imag_mlp_out : data_t;
    signal real_done, imag_done : std_logic;
    signal cos_theta, sin_theta : data_t;
    
    -- Controle
    type state_t is (IDLE, RUN_MLP, WAIT_MLP, CALC_OUT, DONE_STATE);
    signal state : state_t := IDLE;
    signal mult_en : std_logic := '0';

begin

    -- MLP REAL
    MLP_R : MLP_Chain_Serial
    Port Map (
        clk => clk, rst => rst, start => start, input_vec => x_flat_in,
        w_L1 => W_REAL_FC0_W, b_L1 => W_REAL_FC0_B, 
        w_L2 => W_REAL_FC2_W, b_L2 => W_REAL_FC2_B,
        w_L3 => W_REAL_FC4_W, b_L3 => W_REAL_FC4_B,
        mlp_out => real_mlp_out, done => real_done
    );

    -- MLP IMAG
    MLP_I : MLP_Chain_Serial
    Port Map (
        clk => clk, rst => rst, start => start, input_vec => x_flat_in,
        w_L1 => W_IMAG_FC0_W, b_L1 => W_IMAG_FC0_B,
        w_L2 => W_IMAG_FC2_W, b_L2 => W_IMAG_FC2_B,
        w_L3 => W_IMAG_FC4_W, b_L3 => W_IMAG_FC4_B,
        mlp_out => imag_mlp_out, done => imag_done
    );

    -- LUTS Fase
    LUT_C : entity work.LUT_Trig port map(clk, rst, theta_in, '0', cos_theta);
    LUT_S : entity work.LUT_Trig port map(clk, rst, theta_in, '1', sin_theta);

    -- Multiplicador Final
    OUT_MULT : entity work.Complex_Mult_Output
    port map (
        clk => clk, rst => rst, en => mult_en,
        real_in => real_mlp_out, imag_in => imag_mlp_out,
        cos_in => cos_theta, sin_in => sin_theta,
        i_out => i_out, q_out => q_out
    );

    -- FSM de Controle
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                mult_en <= '0';
                done <= '0';
            else
                case state is
                    when IDLE =>
                        done <= '0';
                        if start = '1' then state <= RUN_MLP; end if;
                        
                    when RUN_MLP =>
                        state <= WAIT_MLP; -- Start já foi propagado para as MLPs
                        
                    when WAIT_MLP =>
                        if real_done = '1' and imag_done = '1' then
                            state <= CALC_OUT;
                        end if;
                        
                    when CALC_OUT =>
                        mult_en <= '1'; -- Captura resultado
                        state <= DONE_STATE;
                        
                    when DONE_STATE =>
                        mult_en <= '0';
                        done <= '1';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;