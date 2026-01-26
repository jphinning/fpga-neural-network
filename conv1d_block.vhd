library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL; -- Mantido apenas para data_array_t nas portas

entity Conv1D_Block is
    Generic (
        KERNEL_SIZE : integer := 4; 
        BUFFER_SIZE : integer := 6  
    );
    Port ( 
        clk        : in  std_logic;
        rst        : in  std_logic;
        start      : in  std_logic; 
        
        -- Mantemos data_array_t para compatibilidade com o Top Level
        buffer_in  : in  data_array_t(0 to BUFFER_SIZE-1);
        weights_in : in  data_array_t(0 to KERNEL_SIZE-1);
        
        -- [MODIFICADO] Tipo explícito na porta escalar para garantir 32 bits
        bias_in    : in  signed(31 downto 0);
        
        conv_out   : out data_array_t(0 to (BUFFER_SIZE - KERNEL_SIZE));
        done       : out std_logic
    );
end Conv1D_Block;

architecture Behavioral of Conv1D_Block is

    constant OUT_SIZE : integer := BUFFER_SIZE - KERNEL_SIZE + 1;

    -- [MODIFICADO] Sinais internos NATIVOS (sem data_t)
    signal acc : signed(31 downto 0);
    
    signal w_idx : integer range 0 to OUT_SIZE;    
    signal k_idx : integer range 0 to KERNEL_SIZE; 
    
    signal out_ram : data_array_t(0 to OUT_SIZE-1);
    
    type state_t is (IDLE, LOAD_BIAS, MAC_LOOP, SAVE_PIXEL, FINISHED);
    signal state : state_t := IDLE;

begin

    process(clk)
        -- [MODIFICADO] Variáveis NATIVAS de 64 e 32 bits
        variable v_prod : signed(63 downto 0);
        variable v_trunc : signed(31 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                done <= '0';
                w_idx <= 0;
                k_idx <= 0;
                acc <= (others => '0');
            else
                case state is
                    when IDLE =>
                        done <= '0';
                        if start = '1' then
                            w_idx <= 0;
                            state <= LOAD_BIAS;
                        end if;

                    when LOAD_BIAS =>
                        acc <= bias_in;
                        k_idx <= 0;
                        state <= MAC_LOOP;

                    when MAC_LOOP =>
                        if k_idx < KERNEL_SIZE then
                            -- Multiplicação Explícita:
                            -- O VHDL sabe que signed(32) * signed(32) = signed(64)
                            v_prod := buffer_in(w_idx + k_idx) * weights_in(k_idx);
                            
                            -- [CORREÇÃO FINAL] Slice Manual (Ignorando função do pacote)
                            -- Isso força o simulador a pegar os bits 47 a 16 da variável v_prod
                            -- que declaramos explicitamente como 64 bits acima.
                            v_trunc := v_prod(47 downto 16);
                            
                            acc <= acc + v_trunc;
                            k_idx <= k_idx + 1;
                        else
                            state <= SAVE_PIXEL;
                        end if;

                    when SAVE_PIXEL =>
                        out_ram(w_idx) <= acc;
                        if w_idx < OUT_SIZE - 1 then
                            w_idx <= w_idx + 1;
                            state <= LOAD_BIAS;
                        else
                            state <= FINISHED;
                        end if;

                    when FINISHED =>
                        conv_out <= out_ram;
                        done <= '1';
                        state <= IDLE;
                        
                end case;
            end if;
        end if;
    end process;

end Behavioral;