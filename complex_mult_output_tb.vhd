library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL; -- Importante para usar data_t

entity Complex_Mult_Output_tb is
end Complex_Mult_Output_tb;

architecture Behavioral of Complex_Mult_Output_tb is

    -- Componente Sob Teste (Unit Under Test)
    component Complex_Mult_Output
    Port ( 
        clk     : in  std_logic;
        real_in : in  data_t;
        imag_in : in  data_t;
        cos_in  : in  data_t;
        sin_in  : in  data_t;
        i_out   : out data_t;
        q_out   : out data_t
    );
    end component;
    
    -- Sinais
    signal clk : std_logic := '0';
    signal real_in : data_t := (others => '0');
    signal imag_in : data_t := (others => '0');
    signal cos_in  : data_t := (others => '0');
    signal sin_in  : data_t := (others => '0');

    signal i_out : data_t;
    signal q_out : data_t;

    constant clk_period : time := 10 ns;
    
    -- Constantes Auxiliares Q16.16
    -- 1.0 = 65536
    constant VAL_ONE  : data_t := to_signed(65536, 32);
    constant VAL_ZERO : data_t := to_signed(0, 32);
    constant VAL_HALF : data_t := to_signed(32768, 32); -- 0.5
    constant VAL_NEG_ONE : data_t := to_signed(-65536, 32);

begin

    uut: Complex_Mult_Output PORT MAP (
        clk => clk,
        real_in => real_in,
        imag_in => imag_in,
        cos_in => cos_in,
        sin_in => sin_in,
        i_out => i_out,
        q_out => q_out
    );

    -- Clock
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Estímulos
    stim_proc: process
    begin
        -- Reset / Setup
        wait for 100 ns;    
        wait for clk_period*10;

        report "--- INICIANDO TESTE COMPLEX MULT ---";

        -- CASO 1: Identidade (Rotação por 0 graus)
        -- Entrada: 1 + j0
        -- Rotação: Cos=1, Sin=0
        -- Esperado: 1 + j0
        real_in <= VAL_ONE;
        imag_in <= VAL_ZERO;
        cos_in  <= VAL_ONE;
        sin_in  <= VAL_ZERO;
        wait for clk_period * 2; -- Espera latência (1 ciclo) + margem
        
        assert i_out = VAL_ONE report "Falha Caso 1: I_out incorreto" severity error;
        assert q_out = VAL_ZERO report "Falha Caso 1: Q_out incorreto" severity error;
        
        -- CASO 2: Rotação de 90 graus
        -- Entrada: 1 + j0
        -- Rotação: Cos=0, Sin=1
        -- Esperado: (1*0 - 0*1) + j(1*1 + 0*0) = 0 + j1
        real_in <= VAL_ONE;
        imag_in <= VAL_ZERO;
        cos_in  <= VAL_ZERO;
        sin_in  <= VAL_ONE;
        wait for clk_period * 2;
        
        assert i_out = VAL_ZERO report "Falha Caso 2: I_out incorreto" severity error;
        assert q_out = VAL_ONE  report "Falha Caso 2: Q_out incorreto" severity error;

        -- CASO 3: Rotação de 90 graus com entrada complexa
        -- Entrada: 0 + j1
        -- Rotação: Cos=0, Sin=1
        -- Esperado: (0*0 - 1*1) + j(0*1 + 1*0) = -1 + j0
        real_in <= VAL_ZERO;
        imag_in <= VAL_ONE;
        cos_in  <= VAL_ZERO;
        sin_in  <= VAL_ONE;
        wait for clk_period * 2;
        
        assert i_out = VAL_NEG_ONE report "Falha Caso 3: I_out incorreto" severity error;
        assert q_out = VAL_ZERO report "Falha Caso 3: Q_out incorreto" severity error;

        -- CASO 4: Escalonamento (Multiplicação Fracionária)
        -- Entrada: 2.0 + j0 (131072)
        -- Rotação: Cos=0.5, Sin=0
        -- Esperado: 1.0 + j0
        real_in <= to_signed(131072, 32);
        imag_in <= VAL_ZERO;
        cos_in  <= VAL_HALF;
        sin_in  <= VAL_ZERO;
        wait for clk_period * 2;
        
        -- Verifica se está próximo de 1.0 (permitindo erro de +/- 1 bit)
        if (to_integer(i_out) >= 65535) and (to_integer(i_out) <= 65537) then
             report "Caso 4 Sucesso: Escalonamento OK";
        else
             report "Falha Caso 4: Escalonamento incorreto. I_out=" & integer'image(to_integer(i_out)) severity error;
        end if;

        report "--- TESTE FINALIZADO ---";
        wait;
    end process;

end Behavioral;