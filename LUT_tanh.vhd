library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;    -- Seus tipos (data_t, etc.)
use work.pkg_model_constants.ALL; -- Onde estão LUT_TANH_Y, LUT_TANH_SLOPES

entity LUT_Tanh is
    Port ( 
        clk    : in  std_logic;
        rst    : in  std_logic;
        x_in   : in  data_t; -- Entrada em Ponto Fixo (Q16.16)
        y_out  : out data_t  -- Saída Tanh(x)
    );
end LUT_Tanh;

architecture Behavioral of LUT_Tanh is

    -- Inicialização (= 0) ajuda a evitar metavalues no início da simulação
    signal index : integer range 0 to 1023 := 0;
    
    -- CONFIGURAÇÃO PARA RANGE -8.0 a +8.0
    constant OFFSET_VAL : signed(31 downto 0) := to_signed(524288, 32);

    -- Pipeline Sinais (Inicializados)
    signal y0, slope : data_t := (others => '0');
    
    -- Usamos addr_norm_d1 para garantir a matemática correta do delta
    signal addr_norm_d1 : signed(31 downto 0) := (others => '0'); 
    
    signal delta_x   : data_t := (others => '0');
    
    -- [CORREÇÃO] Tipo explícito de 64 bits para evitar erro de cache do simulador
    signal prod_long : signed(63 downto 0) := (others => '0');
    
    signal delta_y   : data_t := (others => '0');

begin

    process(clk)
        variable address_norm : signed(31 downto 0);
        variable idx_calc : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                y_out <= (others => '0');
                index <= 0;
                
                -- Reset explícito dos sinais internos
                y0 <= (others => '0');
                slope <= (others => '0');
                addr_norm_d1 <= (others => '0');
                delta_x <= (others => '0');
                prod_long <= (others => '0');
                delta_y <= (others => '0');
            else
                -- --- ESTÁGIO 1: Endereçamento Otimizado ---
                
                -- 1. Offset
                -- Se x_in for 'U' (metavalor), a soma resulta em 'U', gerando warning no to_integer.
                -- Na prática, o reset limpa isso após alguns ciclos.
                address_norm := x_in + OFFSET_VAL;
                
                -- 2. Slice / Shift
                -- [CORREÇÃO CRÍTICA]: Cast para UNSIGNED antes de to_integer
                -- Isso impede que o bit 19 seja interpretado como sinal negativo
                idx_calc := to_integer(unsigned(address_norm(19 downto 10)));
                
                -- 3. Clamp
                if idx_calc < 0 then 
                    index <= 0;
                elsif idx_calc > 1023 then 
                    index <= 1023;
                else 
                    index <= idx_calc;
                end if;
                
                -- Guarda o endereço POSITIVO
                addr_norm_d1 <= address_norm;

                -- --- ESTÁGIO 2: Leitura da ROM ---
                y0    <= LUT_TANH_Y(index);
                slope <= LUT_TANH_SLOPES(index);
                
                -- --- ESTÁGIO 3: Cálculo ---
                delta_x <= addr_norm_d1 and x"000003FF"; 
                
                -- Multiplicação (Garante 64 bits)
                prod_long <= delta_x * slope;
                
                -- --- ESTÁGIO 4: Saída ---
                -- [CORREÇÃO] Slice manual (47 downto 16) em vez de função do pacote
                delta_y <= prod_long(47 downto 16);
                y_out <= y0 + delta_y;
                
            end if;
        end if;
    end process;

end Behavioral;