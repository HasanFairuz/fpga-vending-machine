# System Architecture

## Target and interfaces

The repository contains a VHDL implementation intended for the Terasic DE2-115 board, Cyclone IV E EP4CE115F29C7. `src/components/top.vhd` is the board-level entity. It connects the switch and pushbutton interface through `debounce`, outputs monetary values using BCD and seven-segment decoding, drives red/green LED sequences, and instantiates the LCD support hierarchy.

## Data and control paths

```text
SW coin inputs -> priority_enc -> accumulator ------+
                                                      +-> match_change -> vend_unit -> dispense request
Product select -> product register / price RAM ------+                  |
                                                                        v
Mode, passcode, Enter -> vend_periph --------------------------> dispense_fsm -> LEDR / LEDG
                                      |                                |
                                      +-> convert2bcd / SegDecoder -> HEX outputs
                                      +-> product / price ----------> LCD controller -> LCD pins
CLOCK_50 -> debounce / PreScale / LCD clDivide
```

This diagram is a conceptual summary of the source-level hierarchy, not a simulation waveform or verified hardware netlist.

## Module mapping

| Module | Responsibility |
|---|---|
| `priority_enc` | Decode coin input by priority |
| `accumulator` | Track cumulative payment |
| `match_change` | Determine when price is met and change is due |
| `vend_unit` | Product register, pricing RAM, transaction sequencing |
| `dispense_fsm` | Mode-specific LED patterns and completion pulses |
| `vend_periph` | Mode control, clock scaling, display integration |
| `add3` / `convert2bcd` | Binary-to-BCD conversion network |
| `SegDecoder` | Seven-segment encoding |
| `PreScale` | Slower digital clock generation |
| `top` | Board integration |
| `debounce` | Single-bit switch deglitching, instantiated at top level |
| `lcd_controller1` and helpers | LCD timing, character/data generation, and interface |

## Reuse and provenance

The LCD controller, its helper entities, and `debounce.vhd` are identified in the course project materials as provided components. They are separated under `src/lcd/` for attribution and easier inspection. Do not claim authorship of that supplied circuitry.
