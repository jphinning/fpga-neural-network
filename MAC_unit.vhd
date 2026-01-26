library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.pkg_neural_types.ALL;

entity MAC_unit is
    Port (
        a_in : in data_t;
        b_in : in data_t;
        c_in : in data_t;

        p_out : out data_t; -- Resultado = (A * B) + C
    );
end MAC_unit;

architecture Behavioral of MAC_unit is

    signal product_long: data_long_t;
    signal product_trunc: data_t;
begin
    -- 1. Multiplicação
    -- Q16.16 * Q16.16 = Q32.32 (64 bits)
    product_long <= a_in * b_in;

    -- 2. Truncamento / Escala (Equivalente ao bit shift >> 16 no Python)
    product_trunc <= truncate_result(product_long);

    -- 3. Acumulação
    p_out <= product_trunc + c_in;
end Behavioral;