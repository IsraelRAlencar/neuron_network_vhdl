library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

use work.types.all;

entity network is
    generic(
        input_size : integer;
        neurons_per_layer : integer_array;
        weights : sfixed_bus_array
    );
    port(
        clk : in std_logic;
        rst : in std_logic;
        start_i : in std_logic;
        input_i : in sfixed_bus_array(input_size - 1 downto 0);
        output_o : out sfixed_bus_array(neurons_per_layer(neurons_per_layer'right) - 1 downto 0);
        done_o : out std_logic
    );
end entity network;

architecture generic_arch of network is

    constant num_layers : integer := neurons_per_layer'length;
    
    function max_value_in_array(arr : integer_array) return integer is
        variable max : integer := 0;
    begin
        for i in arr'range loop
            if arr(i) > max then
                max := arr(i);
            end if;
        end loop;
        return max;
    end function;

    constant max_neurons_in_layer : integer := max_value_in_array(neurons_per_layer);

    type T_LAYER_OUTPUTS is array (0 to num_layers - 1) of sfixed_bus_array(max_neurons_in_layer - 1 downto 0);
    signal layer_outputs : T_LAYER_OUTPUTS;

    type T_CONTROL_SIGNALS is array (0 to num_layers - 1, 0 to max_neurons_in_layer - 1) of std_logic;
    signal neuron_start : T_CONTROL_SIGNALS := (others => (others => '0'));
    signal neuron_done : T_CONTROL_SIGNALS;

    signal layer_all_done : std_logic_vector(0 to num_layers - 1) := (others => '0');

    pure function get_layer_start_offset(layer_idx : integer) return integer is
        variable offset : integer := 0;
        variable num_inputs : integer;
    begin
        for i in 0 to layer_idx - 1 loop
            if i = 0 then
                num_inputs := input_size;
            else
                num_inputs := neurons_per_layer(i - 1);
            end if;
            offset := offset + (neurons_per_layer(i) * (num_inputs + 1));
        end loop;
        return offset;
    end function get_layer_start_offset;

    function get_num_inputs(layer_idx : integer) return integer is
    begin
        if layer_idx = 0 then 
            return input_size; 
        else 
            return neurons_per_layer(layer_idx - 1);
        end if;
    end function get_num_inputs;

begin
		--alteracao
      gen_layer_done : for i in 0 to num_layers - 1 generate
		  layer_done_proc : process(all)
			 variable v_all_done : std_logic;
		  begin
			 v_all_done := '1';  
			 for j in 0 to neurons_per_layer(i) - 1 loop
				v_all_done := v_all_done and neuron_done(i, j);
			 end loop;
			 layer_all_done(i) <= v_all_done;
		  end process;
		end generate;

    gen_start_control : for i in 0 to num_layers - 1 generate
        gen_neuron_start : for j in 0 to max_neurons_in_layer - 1 generate
            gen_start_layer_0 : if i = 0 generate
                neuron_start(i, j) <= start_i;
            end generate gen_start_layer_0;

            gen_start_layer_n : if i > 0 generate
                neuron_start(i, j) <= layer_all_done(i - 1);
            end generate gen_start_layer_n;

        end generate gen_neuron_start;
    end generate gen_start_control;

    gen_layers : for i in 0 to num_layers - 1 generate
        constant is_last_layer : boolean := (i = num_layers - 1);
        constant num_neurons_in_this_layer : integer := neurons_per_layer(i);
        
        constant num_inputs_this_layer : integer := get_num_inputs(i);
        constant layer_offset : integer := get_layer_start_offset(i);

    begin

        gen_neurons : for j in 0 to num_neurons_in_this_layer - 1 generate
            constant weights_per_neuron : integer := num_inputs_this_layer + 1;
            constant start_weight_index : integer := layer_offset + (j * weights_per_neuron);
            constant end_weight_index : integer := start_weight_index + weights_per_neuron - 1;
        begin

            gen_input_wiring_0 : if i = 0 generate
                neuron_inst : entity work.neuron
                    generic map (
                        inputs => num_inputs_this_layer,
                        use_threshold => is_last_layer
                    )
                    port map (
                        clk => clk,
                        rst => rst,
                        start_i => neuron_start(i, j),
                        input_i => input_i,
                        weight_i => weights(start_weight_index to end_weight_index),
                        output_o => layer_outputs(i)(j),
                        done_o => neuron_done(i, j)
                    );
            end generate gen_input_wiring_0;
            
            gen_input_wiring_n : if i > 0 generate
                neuron_inst : entity work.neuron
                    generic map (
                        inputs => num_inputs_this_layer,
                        use_threshold => is_last_layer
                    )
                    port map (
                        clk => clk,
                        rst => rst,
                        start_i => neuron_start(i, j),
                        input_i => layer_outputs(i - 1)(num_inputs_this_layer - 1 downto 0),
                        weight_i => weights(start_weight_index to end_weight_index),
                        output_o => layer_outputs(i)(j),
                        done_o => neuron_done(i, j)
                    );
            end generate gen_input_wiring_n;
            
        end generate gen_neurons;
        
    end generate gen_layers;

    output_o <= layer_outputs(num_layers - 1)(output_o'range);
    done_o <= layer_all_done(num_layers - 1);

end architecture generic_arch;

