library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

use work.types.all;

entity network_tb2 is
    port (
        clk : in std_logic;
        rst : in std_logic
    );
end entity network_tb2;

architecture synthesizable_test of network_tb2 is
    
    signal start_s : std_logic;
    signal done_s  : std_logic;
    signal input_s : sfixed_bus_array(1 downto 0);

    constant INPUT_SIZE_C        : integer := 2;
    constant NEURONS_PER_LAYER_C : integer_array(0 to 2) := (5, 3, 1); 
    
    -- ==========================================================
    --      ** Pesos Ilustrativos Preenchidos **
    -- ==========================================================
    -- Total de 37 pesos: (2*5+5) + (5*3+3) + (3*1+1) -> (15 + 18 + 4) -> com erro
    -- Total de 37 pesos: (2+1)*5 + (5+1)*3 + (3+1)*1 -> 15 + 18 + 4 = 37
    constant WEIGHTS_C : sfixed_bus_array(0 to 36) := (
        -- Camada 0: 5 neurônios, 2 entradas cada (+1 bias) = 15 pesos
        -- Neurônio 0.0
        to_sfixed_a(1.0), to_sfixed_a(-0.5), to_sfixed_a(0.2),
        -- Neurônio 0.1
        to_sfixed_a(0.8), to_sfixed_a(1.2), to_sfixed_a(-0.1),
        -- Neurônio 0.2
        to_sfixed_a(-1.1), to_sfixed_a(0.1), to_sfixed_a(0.6),
        -- Neurônio 0.3
        to_sfixed_a(0.3), to_sfixed_a(1.5), to_sfixed_a(0.0),
        -- Neurônio 0.4
        to_sfixed_a(-0.7), to_sfixed_a(-0.8), to_sfixed_a(0.9),

        -- Camada 1: 3 neurônios, 5 entradas cada (+1 bias) = 18 pesos
        -- Neurônio 1.0
        to_sfixed_a(0.2), to_sfixed_a(0.3), to_sfixed_a(0.4), to_sfixed_a(0.5), to_sfixed_a(0.6), to_sfixed_a(-0.5),
        -- Neurônio 1.1
        to_sfixed_a(-1.0), to_sfixed_a(1.0), to_sfixed_a(-1.0), to_sfixed_a(1.0), to_sfixed_a(-1.0), to_sfixed_a(0.8),
        -- Neurônio 1.2
        to_sfixed_a(0.1), to_sfixed_a(-0.2), to_sfixed_a(0.3), to_sfixed_a(-0.4), to_sfixed_a(0.5), to_sfixed_a(0.1),

        -- Camada 2: 1 neurônio, 3 entradas cada (+1 bias) = 4 pesos
        -- Neurônio 2.0
        to_sfixed_a(1.5), to_sfixed_a(-1.2), to_sfixed_a(0.7), to_sfixed_a(-1.0)
    );
    
    signal output_s : sfixed_bus_array(0 downto 0);

    type T_TB_STATE is (TB_RESET, TB_START_CASE, TB_WAIT_NETWORK, TB_DONE);
    signal tb_state    : T_TB_STATE := TB_RESET;
    signal test_case   : integer range 0 to 3 := 0;

begin

    -- Instanciação da Rede Neural (DUT)
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
            input_i  => (to_sfixed_a(0), to_sfixed_a(0)),
            output_o => output_s,
            done_o   => done_s
        );

    -- Máquina de estados que gera os estímulos
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
                        -- when 1 => input_s <= (to_sfixed_a(0), to_sfixed_a(1));
                        -- when 2 => input_s <= (to_sfixed_a(1), to_sfixed_a(0));
                        -- when 3 => input_s <= (to_sfixed_a(1), to_sfixed_a(1));
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