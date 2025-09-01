library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

use work.types.all;

entity network_tb is
end entity;

architecture n_xor_generic of network_tb is
    constant half_period : time := 10 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal start_i : std_logic := '0';
    signal done_o : std_logic;

    constant weight_n1 : sfixed_bus_array(2 downto 0) := (to_sfixed_a(-1.5), to_sfixed_a(1.0), to_sfixed_a(1.0)); -- bias, w1, w2 [cite: 69, 70]
    constant weight_n2 : sfixed_bus_array(2 downto 0) := (to_sfixed_a(-0.5), to_sfixed_a(1.0), to_sfixed_a(1.0)); -- bias, w1, w2 [cite: 71, 72]

    -- Neurônio da segunda camada (saída)
    constant weight_n3 : sfixed_bus_array(2 downto 0) := (to_sfixed_a(-0.5), to_sfixed_a(-2.0), to_sfixed_a(1.0)); -- bias, w1, w2 [cite: 73, 74]

    constant layer_1_weights : layer_array(0 to 1) := (0 => weight_n1, 1 => weight_n2);
    constant layer_2_weights : layer_array(0 to 0) := (0 => weight_n3);

    constant xor_network_weights : network_array(0 to 1) := (0 => layer_1_weights, 1 => layer_2_weights);

    constant input_neuron_weights : integer := xor_network_weights(xor_network_weights'low)(0)'length;
    constant num_inputs : integer := input_neuron_weights - 1;
    constant num_outputs : integer := xor_network_weights(xor_network_weights'high)'length - 1;

    signal input_i : sfixed_bus_array(num_inputs downto 0);
    signal output_o : sfixed_bus_array(num_outputs downto 0);

    signal input_r : real_array(num_inputs - 1 downto 0);
    signal output_r : real_array(num_outputs - 1 downto 0);

begin

    network_inst : entity work.network
        generic map(
            network_weights => xor_network_weights
        )
        port map(
            clk => clk,
            rst => rst,
            start_i => start_i,
            input_i => input_i,
            output_o => output_o,
            done_o => done_o
        );
    
    clk <= not clk after half_period;

    start_stimuli : process is
    begin
        start_i <= '0', '1' after 15 ns, '0' after 30 ns;
        wait until done_o = '1';

        loop
            start_i <= '1', '0' after half_period * 2;
            wait until done_o = '1';
        end loop;
    end process start_stimuli;

    input_stimuli : process is
    begin
        -- Teste 1: 0 XOR 0 = 0
        input_i <= (to_sfixed_a(0), to_sfixed_a(0));
        wait until done_o = '1';

        -- Teste 2: 0 XOR 1 = 1
        input_i <= (to_sfixed_a(0), to_sfixed_a(1));
        wait until done_o = '1';

        -- Teste 3: 1 XOR 0 = 1
        input_i <= (to_sfixed_a(1), to_sfixed_a(0));
        wait until done_o = '1';

        -- Teste 4: 1 XOR 1 = 0
        input_i <= (to_sfixed_a(1), to_sfixed_a(1));
        wait until done_o = '1';

        -- Pausa a simulação
        wait;
    end process input_stimuli;

    input_r <= to_real(input_i);
    output_r <= to_real(output_o);
    
end architecture n_xor_generic;