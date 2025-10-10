library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

use work.types.all;

entity network_tb is
end entity;

architecture tb of network_tb is
  signal clk     : std_logic := '0';
  signal rst     : std_logic := '0';
  signal start_s : std_logic := '0';
  signal done_s  : std_logic;
  signal input_s : sfixed_bus_array(1 downto 0);
  signal output_s: sfixed_bus_array(0 downto 0);
  signal y_bit          : std_logic;
  signal y_bit_sampled  : std_logic := '0';

  constant Tclk : time := 10 ns;

  -- Ajuste conforme sua ativação (tanh -> threshold 0.0; sigmoide 0..1 -> 0.5)
  function binarize(y : sfixed) return std_logic is
  begin
    if to_real(y) > 0.5 then
      return '1';
    else
      return '0';
    end if;
  end function;
begin
  -- Clock e reset
  clk <= not clk after Tclk/2;
  rst <= '1', '0' after 30 ns;

  -- DUT de topo (usa seus pesos/arquitetura do network_top)
  dut: entity work.network_top
    port map (
      clk     => clk,
      rst     => rst,
      start_i => start_s,
      input_i => input_s,
      output_o=> output_s,
      done_o  => done_s
    );

  stim: process
    -- Procedure local (pode ter waits e dirigir sinais normalmente)
    procedure apply_vec(a, b: real) is
    begin
      input_s(0) <= to_sfixed_a(a);
      input_s(1) <= to_sfixed_a(b);
      wait for Tclk;
      start_s <= '1';
      wait for Tclk;
      start_s <= '0';
      wait until rising_edge(clk) and done_s = '1';
      report "in=(" & real'image(a) & "," & real'image(b) & ") out=" &
             real'image(to_real(output_s(0)));
      wait for Tclk;
    end procedure;
    variable y : std_logic;
    
    if rising_edge(clk) then
      if rst = '1' then
        y_bit_sampled <= '0';
      elsif done_s = '1' then
        y_bit_sampled <= y_bit;
      end if;
    end if;

  begin
    -- Aguarda sair de reset
    wait for 50 ns;

    -- 00 -> esperado 0
    apply_vec(0.0, 0.0);
    y := binarize(output_s(0));
    assert y = '0' report "Falha para (0,0)" severity warning;

    -- 01 -> esperado 1
    apply_vec(0.0, 1.0);
    y := binarize(output_s(0));
    assert y = '1' report "Falha para (0,1)" severity warning;

    -- 10 -> esperado 1
    apply_vec(1.0, 0.0);
    y := binarize(output_s(0));
    assert y = '1' report "Falha para (1,0)" severity warning;

    -- 11 -> esperado 0
    apply_vec(1.0, 1.0);
    y := binarize(output_s(0));
    assert y = '0' report "Falha para (1,1)" severity warning;

    report "TB finalizado" severity note;
    wait;
  end process;
end architecture;
