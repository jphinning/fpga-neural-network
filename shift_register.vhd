library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Shift_Register is
    Generic (
        DEPTH : integer := 4 -- Tamanho da memória (M). O buffer terá M+1 posições.
    );
    Port ( 
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        enable   : in  STD_LOGIC; -- Sinal de controle (só desloca quando uma nova amostra válida chega)
        
        -- Entrada: A nova amostra x(n)
        data_in  : in  data_t;
        
        -- Saída: O vetor completo [x(n), x(n-1), ..., x(n-M)]
        -- Isso permite que a Convolução acesse TODOS os taps simultaneamente
        data_out : out data_array_t(0 to DEPTH)
    );
end Shift_Register;

architecture Behavioral of Shift_Register is
    -- Sinal interno para armazenar os valores (os registradores físicos)
    signal regs : data_array_t(0 to DEPTH) := (others => (others => '0'));
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset síncrono: Zera tudo
                regs <= (others => (others => '0'));
            elsif enable = '1' then
                -- MECÂNICA DE DESLOCAMENTO (SHIFT)
                -- 1. Insere a nova amostra na cabeça (índice 0)
                regs(0) <= data_in;
                
                -- 2. Move os antigos para a direita
                -- Loop gera o hardware: regs(1) <= regs(0), regs(2) <= regs(1), etc.
                for i in 1 to DEPTH loop
                    regs(i) <= regs(i-1);
                end loop;
            end if;
        end if;
    end process;

    -- Conecta os registradores internos à porta de saída
    data_out <= regs;

end Behavioral;