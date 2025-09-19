library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

use work.types.all;

entity network_top is
    port (
        clk      : in std_logic;
        rst      : in std_logic;
        start_i  : in std_logic;
        input_i  : in sfixed_bus_array(2 - 1 downto 0);
        output_o : out sfixed_bus_array(1 - 1 downto 0);
        done_o   : out std_logic
    );
end entity network_top;

architecture wrapper of network_top is

    constant INPUT_SIZE_C        : integer := 2;
    constant NEURONS_PER_LAYER_C : integer_array(0 to 1) := (2, 1);
    
    constant WEIGHTS_C : sfixed_bus_array(0 to 8) := (
        to_sfixed_a(1.0), to_sfixed_a(1.0), to_sfixed_a(-1.5), 
        to_sfixed_a(1.0), to_sfixed_a(1.0), to_sfixed_a(-0.5),
        to_sfixed_a(-2.0), to_sfixed_a(1.0), to_sfixed_a(-0.5)
    );

begin

    dut_inst : entity work.network
        generic map (
            input_size        => INPUT_SIZE_C,
            neurons_per_layer => NEURONS_PER_LAYER_C,
            weights           => WEIGHTS_C
        )
        port map (
            clk      => clk,
            rst      => rst,
            start_i  => start_i,
            input_i  => input_i,
            output_o => output_o,
            done_o   => done_o
        );

end architecture wrapper;