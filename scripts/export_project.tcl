# =========================================================================
# Export Vivado Project to Tcl Script
# Use this when you've modified project settings, IP blocks, or hierarchies in GUI
# Run inside Vivado Tcl Console: source scripts/export_project.tcl
# =========================================================================

set root_dir [file normalize [file dirname [info script]]/..]
set export_file "${root_dir}/scripts/create_project.tcl"

write_project_tcl -no_copy_sources -force $export_file
puts "INFO: Exported project Tcl to $export_file"
