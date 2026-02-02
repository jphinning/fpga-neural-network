library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;
use work.pkg_model_constants.ALL;

entity LUT_Tanh is
    Port ( 
        clk    : in  std_logic;
        rst    : in  std_logic;
        x_in   : in  data_t; 
        y_out  : out data_t
    );
end LUT_Tanh;

architecture Behavioral of LUT_Tanh is

    signal index : integer range 0 to 1023 := 0;
    
    -- CONFIGURAÇÃO PARA RANGE -2.0 a +2.0 (Span = 4.0)
    -- Offset para mover -2.0 para 0.0 é +2.0.
    -- Em Q16.16: 2.0 * 65536 = 131072.
    constant OFFSET_VAL : signed(DATA_WIDTH-1 downto 0) := to_signed(131072, DATA_WIDTH);

    signal y0, slope : data_t := (others => '0');
    
    -- Usamos unsigned para garantir logica de bits correta
    signal addr_norm_d1 : unsigned(DATA_WIDTH-1 downto 0) := (others => '0'); 
    
    signal delta_x   : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    
    -- Tipo explícito de 64 bits
    signal prod_long : signed(63 downto 0) := (others => '0');
    signal delta_y   : data_t := (others => '0');

    -- Pipeline para alinhar y0 com o resultado da multiplicação
    signal y0_d1 : data_t := (others => '0');

begin

    process(clk)
        variable address_norm : signed(DATA_WIDTH-1 downto 0);
        variable idx_calc : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                y_out <= (others => '0');
                index <= 0;
                y0 <= (others => '0'); y0_d1 <= (others => '0');
                slope <= (others => '0');
                addr_norm_d1 <= (others => '0');
                delta_x <= (others => '0');
                prod_long <= (others => '0');
                delta_y <= (others => '0');
            else
                -- ESTÁGIO 1: Endereçamento com Proteção de Range (Anti-Wrap)
                
                if x_in >= OFFSET_VAL then
                    -- Saturação Positiva (x >= 2.0)
                    index <= 1023;
                    addr_norm_d1 <= (others => '0'); -- Delta zero
                    
                elsif x_in < -OFFSET_VAL then
                    -- Saturação Negativa (x < -2.0)
                    index <= 0;
                    addr_norm_d1 <= (others => '0'); -- Delta zero
                    
                else
                    -- Operação Normal
                    address_norm := x_in + OFFSET_VAL;
                    
                    -- Slice / Shift (>> 8) para Step de 256
                    idx_calc := to_integer(unsigned(address_norm(17 downto 8)));
                    
                    if idx_calc < 0 then index <= 0;
                    elsif idx_calc > 1023 then index <= 1023;
                    else index <= idx_calc;
                    end if;
                    
                    -- Guarda como Unsigned para facilitar máscara
                    addr_norm_d1 <= unsigned(address_norm);
                end if;

                -- ESTÁGIO 2: Leitura da ROM
                y0    <= LUT_TANH_Y(index);
                slope <= LUT_TANH_SLOPES(index);
                
                -- ESTÁGIO 3: Cálculo
                -- Mascara 8 bits inferiores (0xFF)
                -- Converte de volta para signed para a multiplicação
                delta_x <= signed(addr_norm_d1 and x"000000FF");
                
                -- Multiplicação
                prod_long <= delta_x * slope;
                
                -- Delay para alinhar y0
                y0_d1 <= y0;
                
                -- ESTÁGIO 4: Saída
                delta_y <= prod_long(47 downto 16);
                y_out <= y0_d1 + delta_y;
                
            end if;
        end if;
    end process;

end Behavioral;