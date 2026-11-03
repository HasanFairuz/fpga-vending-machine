# Run from repository root after convert2bcd_setup.do.
# Bounded runtime: some testbenches run free-running clocks indefinitely.
# No pre-saved wave.do is required; add signals interactively in ModelSim.
vsim -t 1ps work.convert2bcd_tb
run 2 ms
