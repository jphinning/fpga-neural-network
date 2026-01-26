library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL; -- Importante para os tipos data_t e data_array_t

entity Shift_Register_tb is
end Shift_Register_tb;

architecture Behavioral of Shift_Register_tb is

    -- 1. Component Declaration
    component Shift_Register
        Generic ( DEPTH : integer );
        Port ( 
            clk      : in  STD_LOGIC;
            rst      : in  STD_LOGIC;
            enable   : in  STD_LOGIC;
            data_in  : in  data_t;
            data_out : out data_array_t(0 to DEPTH)
        );
    end component;

    -- 2. Signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal enable : std_logic := '0';
    signal data_in : data_t := (others => '0');

    -- Para o teste, vamos usar M=4 (Depth 4 -> Buffer de tamanho 5)
    constant TEST_DEPTH : integer := 4;
    signal data_out : data_array_t(0 to TEST_DEPTH);

    constant clk_period : time := 10 ns;

begin

    -- 3. Instantiate the Unit Under Test (UUT)
    uut: Shift_Register 
    Generic Map ( DEPTH => TEST_DEPTH )
    Port Map (
        clk => clk,
        rst => rst,
        enable => enable,
        data_in => data_in,
        data_out => data_out
    );

    -- 4. Clock Generation
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- 5. Stimulus Process
    stim_proc: process
    begin
        -- === TESTE 1: RESET ===
        report "Iniciando Teste: Reset";
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        wait for 10 ns; -- Espera uma borda de clock

        -- Verifica se tudo está zerado
        assert to_integer(data_out(0)) = 0 report "Falha no Reset" severity error;

        -- === TESTE 2: SHIFT (Encher o buffer) ===
        report "Iniciando Teste: Shift Enable";
        enable <= '1';
        
        -- Ciclo 1: Entra 10
        data_in <= to_signed(10, 32); 
        wait for clk_period;
        -- Esperado no buffer: [10, 0, 0, 0, 0]
        
        -- Ciclo 2: Entra 20
        data_in <= to_signed(20, 32);
        wait for clk_period;
        -- Esperado no buffer: [20, 10, 0, 0, 0] (O 10 foi empurrado para direita)
        
        -- Ciclo 3: Entra 30
        data_in <= to_signed(30, 32);
        wait for clk_period;
        -- Esperado no buffer: [30, 20, 10, 0, 0]
        
        -- Ciclo 4: Entra 40
        data_in <= to_signed(40, 32);
        wait for clk_period;
        -- Esperado: [40, 30, 20, 10, 0]

        -- Ciclo 5: Entra 50
        data_in <= to_signed(50, 32);
        wait for clk_period;
        -- Esperado: [50, 40, 30, 20, 10] (Buffer Cheio)

        -- Verificação Automática
        assert to_integer(data_out(0)) = 50 report "Erro pos 0" severity error;
        assert to_integer(data_out(1)) = 40 report "Erro pos 1" severity error;
        assert to_integer(data_out(TEST_DEPTH)) = 10 report "Erro pos final" severity error;

        -- === TESTE 3: HOLD (Enable = 0) ===
        report "Iniciando Teste: Hold (Enable=0)";
        enable <= '0';
        data_in <= to_signed(999, 32); -- Valor lixo, não deve entrar
        
        wait for clk_period * 3; -- Espera 3 clocks
        
        -- O buffer deve permanecer INALTERADO: [50, 40, 30, 20, 10]
        assert to_integer(data_out(0)) = 50 report "Erro Hold: Dado mudou!" severity error;
        
        -- === TESTE 4: RESUME ===
        report "Iniciando Teste: Resume Shift";
        enable <= '1';
        data_in <= to_signed(60, 32);
        wait for clk_period;
        -- Esperado: [60, 50, 40, 30, 20] (O 10 saiu do buffer)
        
        assert to_integer(data_out(0)) = 60 report "Erro Resume" severity error;
        assert to_integer(data_out(1)) = 50 report "Erro Deslocamento Resume" severity error;

        report "--- FIM DO TESTE: SUCESSO ---";
        wait;
    end process;

end Behavioral;