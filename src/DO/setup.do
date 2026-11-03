# Portable ModelSim/Questa setup for this GitHub repository.
# Run from repository root: do src/DO/setup.do <module>
# Does not require .mpf project files or duplicated VHDL dependencies.
# Requires a ModelSim/Questa version supporting VHDL-2008.
if {$argc < 1} { error "Specify one of: priority_encoder, add3, accumulator, convert2bcd, match_change, vend_unit, dispense_fsm, vend_periph" }
set module [lindex $argv 0]
set compdir "src/components"
set tbdir "src/testbenches"
set compile_files {}
switch -- $module {
    priority_encoder { set compile_files [list "src/components/priority_enc.vhd" "src/testbenches/priority_enc_tb.vhd"] }
    add3 { set compile_files [list "src/components/add3.vhd" "src/testbenches/add3_tb.vhd"] }
    accumulator { set compile_files [list "src/components/priority_enc.vhd" "src/components/accumulator.vhd" "src/testbenches/accumulator_tb.vhd"] }
    convert2bcd { set compile_files [list "src/components/add3.vhd" "src/components/convert2bcd.vhd" "src/testbenches/convert2bcd_tb.vhd"] }
    match_change { set compile_files [list "src/components/match_change.vhd" "src/testbenches/match_change_tb.vhd"] }
    vend_unit { set compile_files [list "src/components/priority_enc.vhd" "src/components/accumulator.vhd" "src/components/match_change.vhd" "src/components/vend_unit.vhd" "src/testbenches/vend_unit_tb.vhd"] }
    dispense_fsm { set compile_files [list "src/components/dispense_fsm.vhd" "src/testbenches/dispense_fsm_tb.vhd"] }
    vend_periph { set compile_files [list "src/components/priority_enc.vhd" "src/components/accumulator.vhd" "src/components/match_change.vhd" "src/components/vend_unit.vhd" "src/components/dispense_fsm.vhd" "src/components/add3.vhd" "src/components/convert2bcd.vhd" "src/components/PreScale.vhd" "src/components/SegDecoder.vhd" "src/components/vend_periph.vhd" "src/testbenches/vend_periph_tb.vhd"] }
    default { error "Unknown simulation module: $module" }
}
if {![file isdirectory "src/components"]} { error "Run this script from the repository root (fpga-vending-machine)." }
if {![file isdirectory "work"]} { vlib work }
vmap work work
foreach source_file $compile_files {
    echo "Compiling $source_file"
    vcom -2008 $source_file
}
echo "Compile requested for $module. Check the transcript for errors."
