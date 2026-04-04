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

    -- Flags de saturação propagadas pelos 3 ciclos restantes do pipeline
    -- sat_*_s1 é registrado no fim do Estágio 1 (clk N)
    -- sat_*_s2 chega no fim do Estágio 2 (clk N+1)
    -- sat_*_s3 chega no fim do Estágio 3 (clk N+2) e é usado no Estágio 4 (clk N+3)
    signal sat_pos_s1, sat_pos_s2, sat_pos_s3 : std_logic := '0';
    signal sat_neg_s1, sat_neg_s2, sat_neg_s3 : std_logic := '0';

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
                sat_pos_s1 <= '0'; sat_pos_s2 <= '0'; sat_pos_s3 <= '0';
                sat_neg_s1 <= '0'; sat_neg_s2 <= '0'; sat_neg_s3 <= '0';
            else
                -- ESTÁGIO 1: Endereçamento com Proteção de Range
                if x_in >= OFFSET_VAL then
                    -- Fora do range positivo: sinaliza saturação, index não importa
                    index <= 1023;
                    addr_norm_d1 <= (others => '0');
                    sat_pos_s1 <= '1';
                    sat_neg_s1 <= '0';

                elsif x_in < -OFFSET_VAL then
                    -- Fora do range negativo: sinaliza saturação
                    index <= 0;
                    addr_norm_d1 <= (others => '0');
                    sat_pos_s1 <= '0';
                    sat_neg_s1 <= '1';

                else
                    -- Operação Normal
                    address_norm := x_in + OFFSET_VAL;
                    idx_calc := to_integer(unsigned(address_norm(17 downto 8)));
                    if idx_calc < 0 then index <= 0;
                    elsif idx_calc > 1023 then index <= 1023;
                    else index <= idx_calc;
                    end if;
                    addr_norm_d1 <= unsigned(address_norm);
                    sat_pos_s1 <= '0';
                    sat_neg_s1 <= '0';
                end if;

                -- ESTÁGIO 2: Leitura da ROM + propagação do flag
                y0    <= LUT_TANH_Y(index);
                slope <= LUT_TANH_SLOPES(index);
                delta_x <= signed(addr_norm_d1 and x"000000FF");
                sat_pos_s2 <= sat_pos_s1;
                sat_neg_s2 <= sat_neg_s1;

                -- ESTÁGIO 3: Multiplicação + propagação do flag
                prod_long <= delta_x * slope;
                y0_d1     <= y0;
                sat_pos_s3 <= sat_pos_s2;
                sat_neg_s3 <= sat_neg_s2;

                -- ESTÁGIO 4: Saída — usa flag propagado para bypassar LUT
                delta_y <= prod_long(47 downto 16);
                if sat_pos_s3 = '1' then
                    y_out <= to_signed(65535, DATA_WIDTH);   -- +1.0 em Q16.16
                elsif sat_neg_s3 = '1' then
                    y_out <= to_signed(-65535, DATA_WIDTH);  -- -1.0 em Q16.16
                else
                    y_out <= y0_d1 + delta_y;
                end if;
                
            end if;
        end if;
    end process;

end Behavioral;