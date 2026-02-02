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

    signal index : integer range 0 to 1023 := 0;
    constant OFFSET_VAL : signed(31 downto 0) := to_signed(262144, 32);

    -- Sinais de Estágio 1
    signal addr_norm_d1 : signed(31 downto 0) := (others => '0');
    
    -- Sinais de Estágio 2
    signal y0, slope : data_t := (others => '0');
    signal delta_x   : data_t := (others => '0');
    
    -- Sinais de Estágio 3 (Pipeline para sincronia)
    signal y0_d1     : data_t := (others => '0'); -- Delay para y0
    signal prod_long : signed(63 downto 0) := (others => '0');
    
    -- Sinais de Estágio 4
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
                addr_norm_d1 <= (others => '0');
                y0 <= (others => '0');
                slope <= (others => '0');
                delta_x <= (others => '0');
                y0_d1 <= (others => '0');
                prod_long <= (others => '0');
            else
                -- === ESTÁGIO 1: Cálculo de Endereço ===
                address_norm := x_in + OFFSET_VAL;
                
                -- Slice e Cast Unsigned
                idx_calc := to_integer(unsigned(address_norm(18 downto 9)));

                if idx_calc < 0 then index <= 0;
                elsif idx_calc > 1023 then index <= 1023;
                else index <= idx_calc;
                end if;
                
                addr_norm_d1 <= address_norm;

                -- === ESTÁGIO 2: Leitura ROM e Delta X ===
                -- As saídas (y0, slope, delta_x) estarão disponíveis no próximo clock
                if mode_sin = '1' then
                    y0 <= LUT_SIN_Y(index);
                    slope <= LUT_SIN_SLOPES(index);
                else
                    y0 <= LUT_COS_Y(index);
                    slope <= LUT_COS_SLOPES(index);
                end if;

                delta_x <= addr_norm_d1 and x"000001FF"; 

                -- === ESTÁGIO 3: Multiplicação e Delay de Alinhamento ===
                -- A multiplicação usa os valores gerados no Estágio 2
                prod_long <= delta_x * slope;
                
                -- [CORREÇÃO CRÍTICA] Atrasar y0 para alinhar com o resultado da mult
                y0_d1 <= y0;

                -- === ESTÁGIO 4: Soma Final ===
                -- Agora somamos y0 (atrasado) com a correção calculada
                delta_y <= prod_long(47 downto 16);
                y_out <= y0_d1 + delta_y; -- Usar y0_d1 aqui!
                
            end if;
        end if;
    end process;

end Behavioral;