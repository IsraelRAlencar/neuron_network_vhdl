library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

use work.types.all;

entity network is
    generic(
        network_weights : network_array
    );
    port(
        clk : in std_logic;
        rst : in std_logic;
        start_i : in std_logic;
        input_i : in sfixed_bus_array(network_weights(network_weights'low)(0)'length - 2 downto 0);
        output_o : out sfixed_bus_array(network_weights(network_weights'high)'length - 1 downto 0);
        done_o : out std_logic
    );
end entity network;

architecture generic_arch of network is
    constant num_layers : integer := network_weights'length;
    constant input_size : integer := input_i'length;
    constant output_size : integer := output_o'length;

    -- type layer_outputs_array is array (0 to num_layers) of sfixed_bus_array(0 to NUM_LAYERS);
    type layer_outputs_array is array (0 to num_layers) of sfixed_bus_array(0 to 100); -- 100 é um placeholder, sera limitada pelo numero de camadas.
    type layer_done_array is array (integer range <>) of std_logic_vector(integer range <>);

    signal layer_outputs : layer_outputs_array;
    -- signal layer_done : layer_done_array(0 to num_layers - 1)(0 to num_layers);
    signal layer_done : layer_done_array(0 to num_layers - 1)(0 to 100);  -- 100 é um placeholder, sera limitada pelo numero de camadas.
    signal layer_start : std_logic_vector(0 to num_layers - 1);
    
begin
    
    layer_outputs(0)(input_size - 1 downto 0) <= input_i;
    layer_start(0) <= start_i;
    
    gen_layers : for L in 0 to num_layers - 1 generate
        constant neurons_in_layer : integer := network_weights(L)'length;
        constant inputs_per_neuron : integer := network_weights(L)(0)'length - 1;
    begin
        gen_neurons : for N in 0 to neurons_in_layer - 1 generate
            neuron_inst : entity work.neuron
                generic map(
                    inputs => inputs_per_neuron
                )
                port map(
                    clk => clk,
                    rst => rst,
                    start_i => layer_start(L),
                    input_i => layer_outputs(L)(inputs_per_neuron - 1 downto 0),
                    weight_i => network_weights(L)(N),
                    output_o => layer_outputs(L + 1)(N),
                    done_o => layer_done(L)(N)
                );
        end generate gen_neurons;

        process(layer_done)
            variable all_done : std_logic;
        begin
            all_done := '1';
            for i in 0 to neurons_in_layer - 1 loop
                all_done := all_done and layer_done(L)(i);
            end loop;

            if L < num_layers - 1 then
                layer_start(L + 1) <= all_done;
            else
                done_o <= all_done;
            end if;
        end process;
    end generate gen_layers;

    output_o <= layer_outputs(num_layers)(output_size - 1 downto 0);

end architecture generic_arch;