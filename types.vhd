library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

package types is
    -- std_logic_vector type extension

    constant width : integer := 8; -- Width of the bus
    
    -- Bus and bus array definitions
    subtype std_logic_bus is std_logic_vector(width - 1 downto 0);
    type std_logic_bus_array is array (integer range <>) of std_logic_bus;

    -- sfixed type extension

    constant int : integer := 16; --Size of the integer part
    constant frac : integer := 16; --Size of the fractionary part

    subtype sfixed_bus is sfixed(int - 1 downto - frac);
    type sfixed_bus_array is array (integer range <>) of sfixed_bus;

    -- Adding array types for layer array and network array.
    type layer_array is array (integer range <>) of sfixed_bus_array;
    type network_array is array (integer range <>) of layer_array;

    -- Real type extension
    
    type real_array is array (integer range <>) of real; -- Array of real

    -- Functions that convert to sfixed using previosly defined sized of integer and fractionary parts
    function to_sfixed_a(arg : real) return unresolved_sfixed;
    function to_sfixed_a(arg : integer) return unresolved_sfixed;
    function to_real(arg : sfixed_bus_array) return real_array;

end package types;

package body types is
    -- Automatically applies indexes on to_sfixed
    function to_sfixed_a(arg : real) return unresolved_sfixed is
        variable result : unresolved_sfixed(int - 1 downto - frac);
    begin
        result := to_sfixed(arg => arg, left_index => int - 1, right_index => - frac);
        return result;
    end function to_sfixed_a;

    -- Automatically applies indexes on to_sfixed
    function to_sfixed_a(arg : integer) return unresolved_sfixed is
        variable result : unresolved_sfixed(int - 1 downto - frac);
    begin
        result := to_sfixed(arg => arg, left_index => int - 1, right_index => - frac);
        return result;
    end function to_sfixed_a;

    function to_real(arg : sfixed_bus_array) return real_array is
        variable result : real_array(arg'range);
    begin
        for i in arg'range loop
            result(i) := to_real(arg => arg(i));
        end loop;

        return result;
    end function to_real;

end package body types;