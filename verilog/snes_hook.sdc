# Set up units
set_time_format -unit ns -decimal_places 3

# Constrain the input clock to 40 MHz
create_clock -name {clk} -period 25.000 -waveform { 0.000 12.500 } [get_ports {clk}]
create_clock -name {USB_CLK} -period 33.333 -waveform { 0.000 16.666 } [get_ports {USB_CLK}]


set_clock_groups -exclusive -group clk -group USB_CLK