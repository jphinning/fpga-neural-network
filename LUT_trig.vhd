library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;
use work.pkg_model_constants.ALL;

entity LUT_Trig is
    Port ( 
        clk    : in  std_logic;
        rst    : in  std_logic;
        x_in   : in  data_t; 
        
        mode_sin : in std_logic; 
        y_out  : out data_t
    );
end LUT_Trig;

architecture Behavioral of LUT_Trig is

    signal index : integer range 0 to 1023;
    
    -- Offset = 4.0. Em Q16.16: 4 * 65536 = 262144
    constant OFFSET_VAL : signed(31 downto 0) := to_signed(262144, 32);

    -- Sinais
    signal y0, slope : data_t;
    signal addr_norm_d1 : signed(31 downto 0); 
    
    signal delta_x : data_t;
    
    -- [CORREÇÃO] Tipo explícito de 64 bits para evitar erro de cache do simulador
    signal prod_long : signed(63 downto 0);
    signal delta_y : data_t;

begin

    process(clk)
        variable address_norm : signed(31 downto 0);
        variable idx_calc : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                y_out <= (others => '0');
                index <= 0;
                -- Resetar sinais internos ajuda a evitar 'U' propagando
                delta_x <= (others => '0');
                prod_long <= (others => '0');
                delta_y <= (others => '0');
                y0 <= (others => '0');
                slope <= (others => '0');
            else
                -- ESTÁGIO 1: Endereçamento
                address_norm := x_in + OFFSET_VAL;
                
                -- Slice 18 downto 9 (Divisão por 512)
                -- [CORREÇÃO CRÍTICA]: Cast para UNSIGNED antes de to_integer
                -- Isso impede que o bit 19 seja interpretado como sinal negativo
                idx_calc := to_integer(unsigned(address_norm(18 downto 9)));

                if idx_calc < 0 then index <= 0;
                elsif idx_calc > 1023 then index <= 1023;
                else index <= idx_calc;
                end if;
                
                addr_norm_d1 <= address_norm;

                -- ESTÁGIO 2: Leitura
                if mode_sin = '1' then
                    y0 <= LUT_SIN_Y(index);
                    slope <= LUT_SIN_SLOPES(index);
                else
                    y0 <= LUT_COS_Y(index);
                    slope <= LUT_COS_SLOPES(index);
                end if;

                -- ESTÁGIO 3: Cálculo
                delta_x <= addr_norm_d1 and x"000001FF"; 
                
                -- Multiplicação (Gera 64 bits)
                prod_long <= delta_x * slope;

                -- ESTÁGIO 4: Resultado
                -- [CORREÇÃO] Slice manual (47 downto 16) em vez de função do pacote
                delta_y <= prod_long(47 downto 16);
                y_out <= y0 + delta_y;
                
            end if;
        end if;
    end process;

end Behavioral;