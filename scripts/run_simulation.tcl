# =========================================================================
# Vivado Behavioral Simulation Script
# Automates behavioral simulation execution and verification
# =========================================================================

set root_dir [file normalize [file dirname [info script]]/..]
set proj_path "${root_dir}/vivado_project/DCD_Project.xpr"

puts "INFO: Opening Vivado project: ${proj_path}"
open_project ${proj_path}

puts "INFO: Resetting existing simulation files..."
catch {reset_simulation -simset sim_1 -mode behavioral}

puts "INFO: Launching behavioral simulation..."
launch_simulation -simset sim_1 -mode behavioral

puts "INFO: Running simulation..."
run all

puts "INFO: Behavioral simulation completed successfully!"
close_sim
close_project
