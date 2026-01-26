library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;
-- Importante: Precisamos do pacote de constantes para que a entidade compile/ligue
use work.pkg_model_constants.ALL; 

entity Conv_Layer_Serial_tb is
end Conv_Layer_Serial_tb;

architecture Behavioral of Conv_Layer_Serial_tb is

    component Conv_Layer_Serial
        Generic (
            N_FILTERS   : integer;
            KERNEL_SIZE : integer;
            M           : integer
        );
        Port ( 
            clk        : in  std_logic;
            rst        : in  std_logic;
            start      : in  std_logic;
            
            buf_env    : in  data_array_t;
            buf_cos    : in  data_array_t;
            buf_sin    : in  data_array_t;
            
            x_flat_out : out data_array_t;
            done       : out std_logic
        );
    end component;

    -- Configuração Igual ao Top Level
    constant N_FILTERS : integer := 16;
    constant K_SIZE    : integer := 4;
    constant M         : integer := 5;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal start : std_logic := '0';
    
    -- Buffers de Entrada
    signal buf_env : data_array_t(0 to M) := (others => (others => '0'));
    signal buf_cos : data_array_t(0 to M) := (others => (others => '0'));
    signal buf_sin : data_array_t(0 to M) := (others => (others => '0'));
    
    signal x_flat_out : data_array_t(0 to N_FILTERS-1);
    signal done : std_logic;

    constant clk_period : time := 10 ns;
    constant VAL_1 : data_t := to_signed(65536, 32);

begin

    uut: Conv_Layer_Serial
    Generic Map (
        N_FILTERS   => N_FILTERS,
        KERNEL_SIZE => K_SIZE,
        M           => M
    )
    Port Map (
        clk => clk,
        rst => rst,
        start => start,
        buf_env => buf_env,
        buf_cos => buf_cos,
        buf_sin => buf_sin,
        x_flat_out => x_flat_out,
        done => done
    );

    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    stim_proc: process
        variable start_time : time;
        variable end_time : time;
        variable duration : time;
        variable cycles : integer;
    begin
        -- Reset
        rst <= '1';
        wait for 100 ns;
        wait until falling_edge(clk);
        rst <= '0';
        wait for clk_period*5;

        report "--- STARTING CONV LAYER SERIAL TEST ---";

        -- Setup Buffers (Preenche tudo com 1.0 para gerar atividade)
        -- Como os pesos vêm do pacote (gerado pelo Python), não sabemos o resultado exato
        -- sem olhar o pacote, mas podemos verificar se ele calcula ALGO diferente de zero.
        buf_env <= (others => VAL_1);
        buf_cos <= (others => VAL_1);
        buf_sin <= (others => VAL_1);

        -- Disparo
        wait until falling_edge(clk);
        start <= '1';
        start_time := now; -- Marca tempo inicial
        wait for clk_period;
        start <= '0';

        -- Esperar Done
        -- O timeout aqui deve ser generoso: 16 filtros x ~20 ciclos = ~320 ciclos
        wait until done = '1' for clk_period * 1000;
        
        if done = '0' then
            report "FALHA: Timeout! O sinal Done nunca subiu." severity failure;
        else
            end_time := now;
            duration := end_time - start_time;
            cycles := duration / clk_period;
            
            report "SUCESSO: Done recebido!";
            report "Latência Total: " & integer'image(cycles) & " ciclos de clock.";
            
            -- Verificação de Sanidade: Resultado não pode ser indefinido
            if is_x(std_logic_vector(x_flat_out(0))) then
                 report "ALERTA: A saída contem 'X' ou 'U'. Verifique a inicialização." severity warning;
            else
                 -- Imprime o valor do primeiro filtro para inspeção visual
                 report "Valor do Filtro 0: " & integer'image(to_integer(x_flat_out(0)));
                 report "Valor do Filtro 15: " & integer'image(to_integer(x_flat_out(15)));
            end if;
        end if;

        wait;
    end process;

end Behavioral;