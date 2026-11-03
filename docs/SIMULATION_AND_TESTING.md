# Simulation and Testing

## Status

The repository contains eight VHDL testbenches, including an `add3` unit test and seven primary subsystem tests. No ModelSim/Questa runs or physical-board demonstrations were independently performed while preparing this repository; test outcomes are **unverified**.

## ModelSim/Questa prerequisites

- Launch ModelSim/Questa with VHDL-2008 support (`vcom -2008`).
- Change the working directory inside ModelSim to the root of the extracted repository, for example using `cd {X:/Software Files/GitHub/fpga-vending-machine}` on Windows.
- Scripts compile directly from canonical `src/` paths; **no `.mpf` project files are needed**.

## Running a test

From the **ModelSim transcript**, not PowerShell:

```tcl
do src/DO/priority_encoder_setup.do
do src/DO/priority_encoder_run.do
```

The setup script creates/maps the `work` library and recompiles that module's source dependency chain with `vcom -2008`. The matching run script loads `work.<testbench_entity>` and runs for a bounded 2 ms simulation interval (the testbench clocks may otherwise continue indefinitely). When switching between modules, run the new setup script first.

## Test order

| Test group | Setup | Run | Focus |
|---|---|---|---|
| Priority encoder | `priority_encoder_setup.do` | `priority_encoder_run.do` | Coin encoding and priority |
| Add-3 | `add3_setup.do` | `add3_run.do` | BCD correction primitive |
| Accumulator | `accumulator_setup.do` | `accumulator_run.do` | Coin accumulation |
| Binary-to-BCD | `convert2bcd_setup.do` | `convert2bcd_run.do` | Numeric conversion |
| Price/change | `match_change_setup.do` | `match_change_run.do` | Price threshold and change |
| Vending unit | `vend_unit_setup.do` | `vend_unit_run.do` | Price RAM, transitions, transactions |
| Dispense FSM | `dispense_fsm_setup.do` | `dispense_fsm_run.do` | LED sequence and completion |
| Vending peripheral | `vend_periph_setup.do` | `vend_periph_run.do` | Integrated mode and display signals |

Example for integrated testing:

```tcl
do src/DO/vend_periph_setup.do
do src/DO/vend_periph_run.do
```

The `src/DO/setup.do` implementation defines the explicit source compilation order; wrapper scripts pass the test group name. Existing original project-style `.do` files expected `.mpf` projects and per-folder duplicate VHDL files, so the public copies were adapted to the normalized repository tree.

## Interpreting results

1. Ensure the compiler transcript reports **zero errors** for all source files and testbench units.
2. Run each testbench and confirm its completion report appears within the 2 ms interval; inspect all `assert` and `report` messages. Some testbenches use descriptive completion messages even when assertions may have failed earlier.
3. Inspect waveforms where necessary; original `wave.do` presets were not supplied. Add signals and save your own waveform view in ModelSim.
4. Preserve screenshots or transcripts for any result claimed in the README or portfolio.
5. For hardware validation, separately synthesize the `top` entity in Quartus for the DE2-115's EP4CE115F29C7, assign FPGA pins, examine timing/resource reports, then program and exercise all modes on the board.

## Known verification gaps

No generated pin assignment (.qsf/.csv), timing report, Quartus project, ModelSim `.mpf`, waveform preset, or captured pass/fail transcript was provided. The scripts in this repository have been adapted structurally, but not executed here because ModelSim/Questa is not installed in this environment.
