## Target device constraints (e.g. Basys 3 or custom board)
## Uncomment and adjust pin mappings according to your target FPGA board:

# Clock signal
# set_property PACKAGE_PIN W5 [get_ports clk]							
# set_property IOSTANDARD LVCMOS33 [get_ports clk]
# create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

# Switches
# set_property PACKAGE_PIN V17 [get_ports {sw[0]}]					
# set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
# set_property PACKAGE_PIN V16 [get_ports {sw[1]}]					
# set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
# set_property PACKAGE_PIN W16 [get_ports {sw[2]}]					
# set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]
# set_property PACKAGE_PIN W17 [get_ports {sw[3]}]					
# set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]

# LEDs
# set_property PACKAGE_PIN U16 [get_ports {led[0]}]					
# set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
# set_property PACKAGE_PIN E19 [get_ports {led[1]}]					
# set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
# set_property PACKAGE_PIN U19 [get_ports {led[2]}]					
# set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
# set_property PACKAGE_PIN V19 [get_ports {led[3]}]					
# set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

# Reset Button
# set_property PACKAGE_PIN U18 [get_ports rst]						
# set_property IOSTANDARD LVCMOS33 [get_ports rst]
