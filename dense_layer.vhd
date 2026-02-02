library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Dense_Layer is
    Generic (
        NUM_INPUTS  : integer := 16; 
        NUM_OUTPUTS : integer := 16;
        USE_TANH    : boolean := true
    );
    Port ( 
        clk        : in  std_logic;
        rst        : in  std_logic;
        start      : in  std_logic;
        
        -- Mantemos tipos do pacote nas portas
        input_vec  : in  data_array_t(0 to NUM_INPUTS-1);
        weights    : in  data_array_t(0 to (NUM_INPUTS * NUM_OUTPUTS)-1);
        biases     : in  data_array_t(0 to NUM_OUTPUTS-1);
        
        output_vec : out data_array_t(0 to NUM_OUTPUTS-1);
        done       : out std_logic
    );
end Dense_Layer;

architecture Behavioral of Dense_Layer is

    component LUT_Tanh
        Port ( clk, rst : in std_logic; x_in : in data_t; y_out : out data_t );
    end component;

    -- Sinais internos NATIVOS
    signal acc : signed(31 downto 0);
    signal neuron_idx : integer range 0 to NUM_OUTPUTS;
    signal input_idx  : integer range 0 to NUM_INPUTS;
    
    -- Sinais para LUT
    signal lut_in, lut_out : signed(31 downto 0);
    
    -- Memória de Saída
    signal ram_out : data_array_t(0 to NUM_OUTPUTS-1);
    
    type state_t is (IDLE, LOAD_BIAS, MAC_LOOP, WAIT_LUT, NEXT_NEURON, FINISHED);
    signal state : state_t := IDLE;
    
    -- Contador de latência para a LUT
    signal lut_wait_cnt : integer range 0 to 5 := 0;

begin

    -- Instância ÚNICA da LUT (Serializada)
    LUT_Inst : LUT_Tanh
    port map (
        clk   => clk,
        rst   => rst,
        x_in  => lut_in,
        y_out => lut_out
    );

    process(clk)
        -- Variáveis NATIVAS de 64 bits
        variable v_prod : signed(63 downto 0);
        variable v_trunc : signed(31 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                done <= '0';
                neuron_idx <= 0;
                input_idx <= 0;
                acc <= (others => '0');
                lut_in <= (others => '0');
            else
                case state is
                    when IDLE =>
                        done <= '0';
                        if start = '1' then
                            neuron_idx <= 0;
                            state <= LOAD_BIAS;
                        end if;

                    when LOAD_BIAS =>
                        -- Carrega o Bias do neurônio atual
                        acc <= biases(neuron_idx);
                        input_idx <= 0;
                        state <= MAC_LOOP;

                    when MAC_LOOP =>
                        if input_idx < NUM_INPUTS then
                            -- Multiplicação Explícita
                            v_prod := input_vec(input_idx) * weights(neuron_idx * NUM_INPUTS + input_idx);
                            
                            -- [MODIFICADO] Rounding (Round-to-Nearest)
                            -- Se o bit 15 (0.5) for '1', somamos 1 ao resultado truncado.
                            -- Isso converte Floor para Round.
                            if v_prod(15) = '1' then
                                v_trunc := v_prod(47 downto 16) + 1;
                            else
                                v_trunc := v_prod(47 downto 16);
                            end if;
                            
                            acc <= acc + v_trunc;
                            input_idx <= input_idx + 1;
                        else
                            -- Fim da soma. 
                            if USE_TANH then
                                lut_in <= acc; -- Envia acumulador para a LUT
                                lut_wait_cnt <= 0;
                                state <= WAIT_LUT;
                            else
                                -- Sem Tanh (Camada Linear), salva direto
                                ram_out(neuron_idx) <= acc;
                                state <= NEXT_NEURON;
                            end if;
                        end if;

                    when WAIT_LUT =>
                        -- A LUT tem pipeline interno. Vamos esperar 4 ciclos para garantir.
                        if lut_wait_cnt < 4 then
                            lut_wait_cnt <= lut_wait_cnt + 1;
                        else
                            ram_out(neuron_idx) <= lut_out; -- Captura saída da LUT
                            state <= NEXT_NEURON;
                        end if;

                    when NEXT_NEURON =>
                        if neuron_idx < NUM_OUTPUTS - 1 then
                            neuron_idx <= neuron_idx + 1;
                            state <= LOAD_BIAS;
                        else
                            state <= FINISHED;
                        end if;

                    when FINISHED =>
                        output_vec <= ram_out;
                        done <= '1';
                        state <= IDLE;
                        
                end case;
            end if;
        end if;
    end process;

end Behavioral;