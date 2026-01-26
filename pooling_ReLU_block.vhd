library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Pooling_ReLU_Block is
    Generic (
        INPUT_SIZE : integer := 3 -- Tamanho de CADA vetor (W_out)
    );
    Port ( 
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        -- Entrada: Agora recebemos explicitamente as 3 linhas da convolução
        data_in_env     : in  data_array_t(0 to INPUT_SIZE-1);
        data_in_cos     : in  data_array_t(0 to INPUT_SIZE-1);
        data_in_sin     : in  data_array_t(0 to INPUT_SIZE-1);
        
        -- Constante: 1 / (3 * W_out) em ponto fixo
        pool_reciprocal : in  data_t;
        
        -- Saída: Um único valor escalar (x_flat[f])
        data_out        : out data_t
    );
end Pooling_ReLU_Block;

architecture Behavioral of Pooling_ReLU_Block is

    -- Sinais internos
    signal sum_after_relu : data_t := (others => '0');
    
    -- [CORREÇÃO] Tipo explícito de 64 bits para evitar erro de cache do simulador
    signal mult_long      : signed(63 downto 0) := (others => '0');
    
    signal final_result   : data_t := (others => '0');

begin

    process(clk)
        variable v_val : data_t;
        variable v_sum : data_t;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sum_after_relu <= (others => '0');
                final_result   <= (others => '0');
                mult_long      <= (others => '0');
            else
                -- ESTÁGIO 1: ReLU e Acumulação Total
                v_sum := (others => '0');
                
                -- Loop percorre as colunas (W_out)
                for i in 0 to INPUT_SIZE-1 loop
                    
                    -- --- Linha 1: Envelope ---
                    v_val := data_in_env(i);
                    -- Proteção simples: se for metavalor ('U', 'X'), trata como 0 para evitar warning
                    if is_x(std_logic_vector(v_val)) then v_val := (others => '0'); end if;
                    
                    if v_val < 0 then v_val := (others => '0'); end if; -- ReLU
                    v_sum := v_sum + v_val;

                    -- --- Linha 2: Cosseno ---
                    v_val := data_in_cos(i);
                    if is_x(std_logic_vector(v_val)) then v_val := (others => '0'); end if;
                    
                    if v_val < 0 then v_val := (others => '0'); end if; -- ReLU
                    v_sum := v_sum + v_val;

                    -- --- Linha 3: Seno ---
                    v_val := data_in_sin(i);
                    if is_x(std_logic_vector(v_val)) then v_val := (others => '0'); end if;
                    
                    if v_val < 0 then v_val := (others => '0'); end if; -- ReLU
                    v_sum := v_sum + v_val;
                    
                end loop;
                
                -- Registra a soma total dos 3 vetores para o próximo estágio
                sum_after_relu <= v_sum;
                
                -- ESTÁGIO 2: Média Global (Soma Total * 1/(3*W))
                -- O 'sum_after_relu' usado aqui é do ciclo ANTERIOR (Pipeline)
                -- Multiplicação explícita gerando 64 bits
                mult_long <= sum_after_relu * pool_reciprocal;
                
                -- Truncamento e Saída
                -- [CORREÇÃO] Slice manual (47 downto 16) em vez de função do pacote
                final_result <= mult_long(47 downto 16);
                
            end if;
        end if;
    end process;

    data_out <= final_result;

end Behavioral;