library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.pkg_neural_types.ALL;
use work.pkg_model_constants.ALL; 

entity MLP_Chain_Validation_tb is
end MLP_Chain_Validation_tb;

architecture Behavioral of MLP_Chain_Validation_tb is

    component MLP_Chain_Serial
        Port ( 
            clk        : in  std_logic;
            rst        : in  std_logic;
            start      : in  std_logic;
            input_vec  : in  data_array_t(0 to 15);
            
            -- Pesos
            w_L1       : in  data_array_t;
            b_L1       : in  data_array_t;
            w_L2       : in  data_array_t;
            b_L2       : in  data_array_t;
            w_L3       : in  data_array_t;
            b_L3       : in  data_array_t;
            
            mlp_out    : out data_t;
            done       : out std_logic
        );
    end component;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal start : std_logic := '0';
    
    signal input_vec : data_array_t(0 to 15) := (others => (others => '0'));
    signal real_out, imag_out : data_t;
    signal real_done, imag_done : std_logic;

    constant clk_period : time := 10 ns;
    file file_VECTORS : text open read_mode is "vectors_s3_mlp.txt";

begin

    -- [CORREÇÃO] Usando mapeamento nomeado (=>) para evitar erro de ordem
    DUT_REAL : MLP_Chain_Serial Port Map (
        clk       => clk,
        rst       => rst,
        start     => start,
        input_vec => input_vec,
        
        w_L1      => W_REAL_FC0_W, 
        b_L1      => W_REAL_FC0_B, 
        
        w_L2      => W_REAL_FC2_W, 
        b_L2      => W_REAL_FC2_B,
        
        w_L3      => W_REAL_FC4_W, 
        b_L3      => W_REAL_FC4_B,
        
        mlp_out   => real_out,
        done      => real_done
    );

    DUT_IMAG : MLP_Chain_Serial Port Map (
        clk       => clk,
        rst       => rst,
        start     => start,
        input_vec => input_vec,
        
        w_L1      => W_IMAG_FC0_W, 
        b_L1      => W_IMAG_FC0_B, 
        
        w_L2      => W_IMAG_FC2_W, 
        b_L2      => W_IMAG_FC2_B,
        
        w_L3      => W_IMAG_FC4_W, 
        b_L3      => W_IMAG_FC4_B,
        
        mlp_out   => imag_out,
        done      => imag_done
    );

    clk_process :process begin
        clk <= '0'; wait for clk_period/2; clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process
        variable v_ILINE : line;
        variable v_VAL : integer;
        variable v_REAL_EXP, v_IMAG_EXP : integer;
        variable sample_cnt : integer := 0;
    begin
        rst <= '1'; wait for 100 ns; rst <= '0'; wait for clk_period*10;

        while not endfile(file_VECTORS) loop
            sample_cnt := sample_cnt + 1;
            readline(file_VECTORS, v_ILINE);
            
            -- 1. Read Inputs (x_flat)
            for i in 0 to 15 loop
                read(v_ILINE, v_VAL);
                input_vec(i) <= to_signed(v_VAL, 32);
            end loop;
            
            -- 2. Read Expected
            read(v_ILINE, v_REAL_EXP);
            read(v_ILINE, v_IMAG_EXP);
            
            -- 3. Trigger
            wait until falling_edge(clk);
            start <= '1'; wait for clk_period; start <= '0';
            
            -- 4. Wait
            wait until real_done = '1' and imag_done = '1' for 3000 * clk_period;
            
            if real_done = '1' then
                 if (abs(to_integer(real_out) - v_REAL_EXP) < 500) and 
                    (abs(to_integer(imag_out) - v_IMAG_EXP) < 500) then
                     report "S3 Sample " & integer'image(sample_cnt) & " PASS";
                 else
                     report "S3 Sample " & integer'image(sample_cnt) & " FAIL. Real Exp:" & integer'image(v_REAL_EXP) & 
                            " Got:" & integer'image(to_integer(real_out)) severity error;
                 end if;
            else
                 report "Timeout S3" severity failure;
            end if;
            
            wait for clk_period * 50;
        end loop;
        report "TEST S3 FINISHED";
        wait;
    end process;

end Behavioral;