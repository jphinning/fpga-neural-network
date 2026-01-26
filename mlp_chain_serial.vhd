library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity MLP_Chain_Serial is
    Port ( 
        clk        : in  std_logic;
        rst        : in  std_logic;
        start      : in  std_logic;
        
        -- Input: Result from Convolution (x_flat)
        input_vec  : in  data_array_t(0 to 15);
        
        -- Pesos e Biases (Entradas para permitir reuso Real/Imag)
        -- Layer 1 (16x25)
        w_L1       : in  data_array_t(0 to (16*25)-1);
        b_L1       : in  data_array_t(0 to 24);
        -- Layer 2 (25x25)
        w_L2       : in  data_array_t(0 to (25*25)-1);
        b_L2       : in  data_array_t(0 to 24);
        -- Layer 3 (25x1)
        w_L3       : in  data_array_t(0 to (25*1)-1);
        b_L3       : in  data_array_t(0 to 0);
        
        -- Output: Final scalar result
        mlp_out    : out data_t;
        done       : out std_logic
    );
end MLP_Chain_Serial;

architecture Behavioral of MLP_Chain_Serial is

    component Dense_Layer
        Generic (
            NUM_INPUTS  : integer;
            NUM_OUTPUTS : integer;
            USE_TANH    : boolean
        );
        Port ( 
            clk        : in  std_logic;
            rst        : in  std_logic;
            start      : in  std_logic;
            input_vec  : in  data_array_t;
            weights    : in  data_array_t;
            biases     : in  data_array_t;
            output_vec : out data_array_t;
            done       : out std_logic
        );
    end component;

    -- Sinais entre camadas
    signal l1_out_vec : data_array_t(0 to 24);
    signal l1_done    : std_logic;
    
    signal l2_out_vec : data_array_t(0 to 24);
    signal l2_done    : std_logic;
    
    signal l3_out_vec : data_array_t(0 to 0);
    signal l3_done    : std_logic;

begin

    -- Layer 1: 16 -> 25 (Tanh)
    L1 : Dense_Layer
    Generic Map ( NUM_INPUTS => 16, NUM_OUTPUTS => 25, USE_TANH => true )
    Port Map (
        clk => clk, rst => rst, start => start,
        input_vec => input_vec,
        weights => w_L1, biases => b_L1,
        output_vec => l1_out_vec, done => l1_done
    );

    -- Layer 2: 25 -> 25 (Tanh)
    L2 : Dense_Layer
    Generic Map ( NUM_INPUTS => 25, NUM_OUTPUTS => 25, USE_TANH => true )
    Port Map (
        clk => clk, rst => rst, start => l1_done,
        input_vec => l1_out_vec,
        weights => w_L2, biases => b_L2,
        output_vec => l2_out_vec, done => l2_done
    );

    -- Layer 3: 25 -> 1 (Linear)
    L3 : Dense_Layer
    Generic Map ( NUM_INPUTS => 25, NUM_OUTPUTS => 1, USE_TANH => false )
    Port Map (
        clk => clk, rst => rst, start => l2_done,
        input_vec => l2_out_vec,
        weights => w_L3, biases => b_L3,
        output_vec => l3_out_vec, done => l3_done
    );

    mlp_out <= l3_out_vec(0);
    done    <= l3_done;

end Behavioral;