library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_neural_types.ALL;

entity Complex_Mult_Output is
    Port ( 
        clk     : in  std_logic;
        rst     : in  std_logic; -- Added Reset
        en      : in  std_logic; -- Added Enable for Sample & Hold
        
        -- Inputs
        real_in : in  data_t;
        imag_in : in  data_t;
        cos_in  : in  data_t;
        sin_in  : in  data_t;
        
        -- Outputs
        i_out   : out data_t;
        q_out   : out data_t
    );
end Complex_Mult_Output;

architecture Behavioral of Complex_Mult_Output is
begin

    process(clk)
        variable ac, bd, ad, bc : signed(63 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                i_out <= (others => '0');
                q_out <= (others => '0');
            elsif en = '1' then
                -- Only calculate and update output when Enabled
                
                ac := real_in * cos_in;
                bd := imag_in * sin_in;
                ad := real_in * sin_in;
                bc := imag_in * cos_in;
                
                -- Q16.16 Slice (47 downto 16)
                i_out <= ac(47 downto 16) - bd(47 downto 16);
                q_out <= ad(47 downto 16) + bc(47 downto 16);
            end if;
            -- If en = '0', outputs hold their previous value
        end if;
    end process;

end Behavioral;