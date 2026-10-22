# =========================================================================
# Vivado Project Creation Script
# Automates Vivado project setup for team collaboration via Git.
# Run with: vivado -mode batch -source scripts/create_project.tcl
# Or in Vivado GUI Tcl console: source scripts/create_project.tcl
# =========================================================================

set proj_name "DCD_Project"
set root_dir [file normalize [file dirname [info script]]/..]
set proj_dir "${root_dir}/vivado_project"

# Default target FPGA part (Artix-7 Basys 3: xc7a35tcpg236-1)
# Can be overridden by passing arg: vivado -mode batch -source scripts/create_project.tcl -tclargs <part_name>
set target_part "xc7a35tcpg236-1"
if { $argc > 0 } {
    set target_part [lindex $argv 0]
}

puts "INFO: Creating Vivado project: ${proj_name} in ${proj_dir}"
puts "INFO: Target Part: ${target_part}"

# Close any open project
catch {close_project}

# Create project
create_project -force ${proj_name} ${proj_dir} -part ${target_part}

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# Add RTL source files
set rtl_files [glob -nocomplain -directory "${root_dir}/src/rtl" *.v *.sv *.vhd]
if { [llength $rtl_files] > 0 } {
    add_files -fileset sources_1 $rtl_files
    puts "INFO: Added RTL files: $rtl_files"
}

# Add Simulation files
set sim_files [glob -nocomplain -directory "${root_dir}/src/tb" *.v *.sv *.vhd]
if { [llength $sim_files] > 0 } {
    add_files -fileset sim_1 $sim_files
    puts "INFO: Added Simulation files: $sim_files"
}

# Add Constraints
set constr_files [glob -nocomplain -directory "${root_dir}/src/constrs" *.xdc]
if { [llength $constr_files] > 0 } {
    add_files -fileset constrs_1 $constr_files
    puts "INFO: Added Constraint files: $constr_files"
}

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Set top module if it exists
if { [get_files -quiet -filter {NAME =~ "*top.v"}] != "" } {
    set_property top top [current_fileset]
    update_compile_order -fileset sources_1
}

if { [get_files -quiet -filter {NAME =~ "*top_tb.v"}] != "" } {
    set_property top top_tb [get_filesets sim_1]
    update_compile_order -fileset sim_1
    set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
}

puts "INFO: Vivado project ${proj_name} created successfully!"
