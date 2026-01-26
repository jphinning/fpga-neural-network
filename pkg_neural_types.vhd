library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package pkg_neural_types is

    -- ==========================================
    -- 1. CONFIGURAÇÃO DE PONTO FIXO
    -- ==========================================
    -- Q16.16 Format (32 bits total)
    -- Range: -32768.0 a +32767.99998
    -- Precisão: 0.0000152
    constant DATA_WIDTH: integer := 32;
    constant FRAC_BITS: integer := 16;

    subtype data_t is signed(DATA_WIDTH - 1  downto 0);

    -- Tipo para resultados intermediários de multiplicação (dobro da largura)
    subtype data_long_t is signed((DATA_WIDTH*2)-1 downto 0);

    -- Array de dados (útil para buffers, entradas de MLP, etc.)
    type data_array_t is array (integer range <>) of data_t;

    function truncate_result(val : data_long_t) return data_t;

end package pkg_neural_types;


package body pkg_neural_types is

    function truncate_result(val : data_long_t) return data_t is
        -- Q16.16 * Q16.16 = Q32.32 (64 bits)
        -- We want to extract the middle 32 bits (bits 47 down to 16)
        -- to return to Q16.16 format.
        
        -- Explicit upper and lower bounds to avoid confusion
        constant UPPER_BIT : integer := DATA_WIDTH + FRAC_BITS - 1; -- 32 + 16 - 1 = 47
        constant LOWER_BIT : integer := FRAC_BITS;                  -- 16
    begin
        -- This slice (47 downto 16) requires val to be at least 48 bits wide.
        -- data_long_t is 64 bits, so this is safe.
        return val(UPPER_BIT downto LOWER_BIT);
    end function;
    
end pkg_neural_types;
