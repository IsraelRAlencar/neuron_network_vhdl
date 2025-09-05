library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

use work.types.all;

-- ==========================================================
--      ** CORREÇÃO 1: Adicionadas portas clk e rst **
-- ==========================================================
-- Para um design de topo sintetizável, clk e rst devem ser entradas.
entity network_tb is
    port (
        clk : in std_logic;
        rst : in std_logic
    );
end entity network_tb;

architecture synthesizable_test of network_tb is
    
    signal start_s : std_logic;
    signal done_s  : std_logic;
    signal input_s : sfixed_bus_array(1 downto 0);

    constant INPUT_SIZE_C        : integer := 2;

    constant NEURONS_PER_LAYER_C : integer_array(0 to 1) := (2, 1); 
    
    constant WEIGHTS_C : sfixed_bus_array(0 to 8) := (
        to_sfixed_a(1.0), to_sfixed_a(1.0), to_sfixed_a(-1.5), 
        to_sfixed_a(1.0), to_sfixed_a(1.0), to_sfixed_a(-0.5),
        to_sfixed_a(-2.0), to_sfixed_a(1.0), to_sfixed_a(-0.5)
    );
    
    signal output_s : sfixed_bus_array(0 downto 0);
    type T_TB_STATE is (TB_RESET, TB_START_CASE, TB_WAIT_NETWORK, TB_DONE);
    signal tb_state    : T_TB_STATE := TB_RESET;
    signal test_case   : integer range 0 to 3 := 0;

begin

    -- Instanciação da Rede Neural (DUT - Device Under Test)
    network_inst : entity work.network
        generic map(
            input_size        => INPUT_SIZE_C,
            neurons_per_layer => NEURONS_PER_LAYER_C,
            weights           => WEIGHTS_C
        )
        port map(
            clk      => clk,
            rst      => rst,
            start_i  => start_s,
            input_i  => input_s,
            output_o => output_s,
            done_o   => done_s
        );

    stimuli_fsm_proc : process(clk, rst)
    begin
        if rst = '1' then
            tb_state <= TB_RESET;
            test_case <= 0;
            start_s <= '0';
        elsif rising_edge(clk) then
            case tb_state is
                when TB_RESET =>
                    tb_state <= TB_START_CASE;

                when TB_START_CASE =>
                    case test_case is
                        when 0 => input_s <= (to_sfixed_a(0), to_sfixed_a(0));
                        when 1 => input_s <= (to_sfixed_a(0), to_sfixed_a(1));
                        when 2 => input_s <= (to_sfixed_a(1), to_sfixed_a(0));
                        when 3 => input_s <= (to_sfixed_a(1), to_sfixed_a(1));
                        when others => input_s <= (others => (others => '0'));
                    end case;
                    
                    start_s <= '1';
                    tb_state <= TB_WAIT_NETWORK;

                when TB_WAIT_NETWORK =>
                    start_s <= '0';
                    
                    if done_s = '1' then
                        if test_case = 3 then
                            tb_state <= TB_DONE;
                        else
                            test_case <= test_case + 1;
                            tb_state <= TB_START_CASE;
                        end if;
                    end if;
                    
                when TB_DONE =>
                    tb_state <= TB_DONE;
            end case;
        end if;
    end process stimuli_fsm_proc;
    
end architecture synthesizable_test;