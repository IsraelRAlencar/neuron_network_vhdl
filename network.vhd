library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

    type T_NETWORK_STATE is (IDLE, START_LAYER, WAIT_LAYER, FINISH);
    signal network_state : T_NETWORK_STATE := IDLE;
    signal layer_counter : integer range 0 to num_layers - 1 := 0;

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
    network_fsm_proc : process(clk, rst)
        variable all_done : boolean;
    begin
        if rst = '1' then
            network_state <= IDLE;
            layer_counter <= 0;
            done_o <= '0';
        elsif rising_edge(clk) then
            case network_state is
                when IDLE =>
                    done_o <= '0';
                    if start_i = '1' then
                        layer_counter <= 0;
                        network_state <= START_LAYER;
                    end if;
                    
                when START_LAYER =>
                    for j in 0 to max_neurons_in_layer - 1 loop
                        if j < neurons_per_layer(layer_counter) then
                            neuron_start(layer_counter, j) <= '1';
                        end if;
                    end loop;
                    network_state <= WAIT_LAYER;
                    
                when WAIT_LAYER =>
                    for j in 0 to max_neurons_in_layer - 1 loop
                        if j < neurons_per_layer(layer_counter) then
                            neuron_start(layer_counter, j) <= '0';
                        end if;
                    end loop;

                    all_done := true;
                    for j in 0 to max_neurons_in_layer - 1 loop
                        if j < neurons_per_layer(layer_counter) then
                            if neuron_done(layer_counter, j) = '0' then
                                all_done := false;
                            end if;
                        end if;
                    end loop;

                    if all_done then
                        if layer_counter = num_layers - 1 then
                            network_state <= FINISH;
                        else
                            layer_counter <= layer_counter + 1;
                            network_state <= START_LAYER;
                        end if;
                    end if;
                    
                when FINISH =>
                    done_o <= '1';
                    if start_i = '0' then
                        network_state <= IDLE;
                    end if;
            end case;
        end if;
    end process network_fsm_proc;

    gen_layers : for i in 0 to num_layers - 1 generate
        constant num_neurons_in_this_layer : integer := neurons_per_layer(i);
        
        constant num_inputs_this_layer : integer := get_num_inputs(i);
        constant layer_offset : integer := get_layer_start_offset(i);

    begin

        gen_neurons : for j in 0 to num_neurons_in_this_layer - 1 generate
            constant weights_per_neuron : integer := num_inputs_this_layer + 1;
            constant start_weight_index : integer := layer_offset + (j * weights_per_neuron);
            constant end_weight_index : integer := start_weight_index + weights_per_neuron - 1;
        begin

            gen_input_wiring : if i = 0 generate
                neuron_inst : entity work.neuron
                    generic map (
                        inputs => num_inputs_this_layer
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
            else generate
                neuron_inst : entity work.neuron
                    generic map (
                        inputs => num_inputs_this_layer
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
            end generate gen_input_wiring;
            
        end generate gen_neurons;
        
    end generate gen_layers;

    output_o <= layer_outputs(num_layers - 1)(output_o'range);

end architecture generic_arch;