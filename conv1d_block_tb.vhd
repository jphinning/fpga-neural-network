library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Conv1D_Block_tb is
end Conv1D_Block_tb;

architecture Behavioral of Conv1D_Block_tb is

    component Conv1D_Block
        Generic (
            KERNEL_SIZE : integer;
            BUFFER_SIZE : integer
        );
        Port ( 
            clk        : in  std_logic;
            rst        : in  std_logic;
            start      : in  std_logic;
            buffer_in  : in  data_array_t;
            weights_in : in  data_array_t;
            bias_in    : in  data_t;
            conv_out   : out data_array_t;
            done       : out std_logic
        );
    end component;

    constant K_SIZE   : integer := 3;
    constant BUF_SIZE : integer := 5; 
    constant OUT_SIZE : integer := 3;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal start : std_logic := '0';
    
    signal buffer_in : data_array_t(0 to BUF_SIZE-1) := (others => (others => '0'));
    signal weights_in : data_array_t(0 to K_SIZE-1) := (others => (others => '0'));
    signal bias_in : data_t := (others => '0');
    
    signal conv_out : data_array_t(0 to OUT_SIZE-1);
    signal done : std_logic;

    constant clk_period : time := 10 ns;
    constant VAL_1  : data_t := to_signed(65536, 32);  -- 1.0

begin

    uut: Conv1D_Block 
    Generic Map (
        KERNEL_SIZE => K_SIZE,
        BUFFER_SIZE => BUF_SIZE
    )
    Port Map (
        clk => clk, rst => rst, start => start,
        buffer_in => buffer_in, weights_in => weights_in, bias_in => bias_in,
        conv_out => conv_out, done => done
    );

    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    stim_proc: process
        variable timeout_cnt : integer;
    begin
        -- Reset Seguro
        rst <= '1';
        start <= '0';
        wait for 100 ns;
        
        -- Sincroniza reset release com falling edge
        wait until falling_edge(clk);
        rst <= '0';
        wait for clk_period*2;

        report "--- TESTE 1: Convolução Identidade ---";
        -- Configurar dados (borda de descida para estabilidade)
        wait until falling_edge(clk);
        buffer_in(0) <= to_signed(655360, 32);   -- 10.0
        buffer_in(1) <= to_signed(1310720, 32);  -- 20.0
        buffer_in(2) <= to_signed(1966080, 32);  -- 30.0
        buffer_in(3) <= to_signed(2621440, 32);  -- 40.0
        buffer_in(4) <= to_signed(3276800, 32);  -- 50.0
        
        weights_in(0) <= VAL_1;
        
        -- Disparo Seguro (Falling Edge)
        wait until falling_edge(clk);
        start <= '1';
        wait for clk_period; -- Segura por 1 ciclo inteiro
        start <= '0';

        -- Esperar conclusão
        timeout_cnt := 0;
        loop
            wait until rising_edge(clk);
            if done = '1' then
                report "SUCESSO: Done detectado.";
                exit;
            end if;
            timeout_cnt := timeout_cnt + 1;
            if timeout_cnt > 200 then
                report "FALHA: Timeout! Start enviado mas Done nao subiu." severity failure;
            end if;
        end loop;
        
        wait for clk_period; 
        report "--- FIM DO TESTE CONV1D ---";
        wait;
    end process;

end Behavioral;