library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Complex_Mult_Output is
    Port ( 
        clk     : in  std_logic;
        -- Entradas (32 bits Q16.16)
        real_in : in  data_t;
        imag_in : in  data_t;
        cos_in  : in  data_t;
        sin_in  : in  data_t;
        
        -- Saídas (32 bits Q16.16)
        i_out   : out data_t;
        q_out   : out data_t
    );
end Complex_Mult_Output;

architecture Behavioral of Complex_Mult_Output is
begin

    process(clk)
        -- [FORÇADO] Variáveis explicitamente de 64 bits para evitar ambiguidade de pacote
        variable ac, bd, ad, bc : signed(63 downto 0);
    begin
        if rising_edge(clk) then
            -- Multiplicação (32 bits * 32 bits -> 64 bits)
            ac := real_in * cos_in;
            bd := imag_in * sin_in;
            ad := real_in * sin_in;
            bc := imag_in * cos_in;
            
            -- Slice Manual (47 downto 16)
            -- Isso garante que pegamos os bits centrais do número de 64 bits
            -- Q16.16 * Q16.16 = Q32.32. Descartamos os 16 bits inferiores.
            i_out <= ac(47 downto 16) - bd(47 downto 16);
            q_out <= ad(47 downto 16) + bc(47 downto 16);
        end if;
    end process;

end Behavioral;