# =========================================================================
# Vivado Behavioral Simulation Script
# Automates behavioral simulation execution and verification across platforms
# =========================================================================

set root_dir [file normalize [file dirname [info script]]/..]
set proj_path "${root_dir}/vivado_project/DCD_Project.xpr"

puts "INFO: Preparing Vivado project..."
if { [file exists ${proj_path}] } {
    if { [catch {open_project ${proj_path}} err] } {
        puts "WARNING: Could not open project (${err}). Recreating cleanly with create_project.tcl..."
        source "${root_dir}/scripts/create_project.tcl"
    }
} else {
    puts "INFO: Project file not found. Creating cleanly with create_project.tcl..."
    source "${root_dir}/scripts/create_project.tcl"
}

puts "INFO: Resetting existing simulation files..."
catch {reset_simulation -simset sim_1 -mode behavioral}

puts "INFO: Launching behavioral simulation..."
launch_simulation -simset sim_1 -mode behavioral

puts "INFO: Running simulation..."
run all

puts "INFO: Behavioral simulation completed successfully!"
catch {close_sim}
catch {close_project}
