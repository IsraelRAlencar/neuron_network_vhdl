library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

use work.types.all;

-- Applies the specified acctivation function to the input the activation function specified as the instantiated architecture

entity act_func is
    port(
        clk : in std_logic;
        input_i : in sfixed_bus;
        output_o : out sfixed_bus := (others => '0')
    );
end entity act_func;

-- McCulloch−Pitts "all−or−none" activation function (threshold).
architecture threshold of act_func is
begin
    output_o <= to_sfixed_a(1) when input_i >= 0 else to_sfixed_a(0);
end architecture threshold;

-- A simple ReLU (f(x) = max(0, x))
architecture relu of act_func is
begin
    output_o <= input_i when input_i >= 0 else to_sfixed_a(0);
end architecture relu;