# Set up units
set_time_format -unit ns -decimal_places 3

# Constrain the input clock to 40 MHz
create_clock -name {clk} -period 25.000 -waveform { 0.000 12.500 } [get_ports {clk}]

