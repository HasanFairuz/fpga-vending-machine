# Hardware and Limitations

## Hardware target

- Board: Terasic DE2-115
- FPGA: Cyclone IV E EP4CE115F29C7
- Nominal clock input: `CLOCK_50` (50 MHz)
- Inputs: SW17:0 and KEY3:0
- Outputs: LEDR17:0, LEDG8:0, HEX0–HEX7 and LCD-related signals

The source-level top entity describes logical ports and switch mappings. This package does **not** include verified FPGA pin assignments, a Quartus project file, a bitstream, synthesis/timing outputs, or a recorded board-level validation.

## Design limitations and caveats

- The vending machine is a digital hardware demonstrator; coin entries are simulated with switches, and dispensing is represented by an LED light sequence rather than a physical product actuator.
- Monetary values are represented in integer cents; the seven-segment displays have no decimal points.
- Free mode compares a fixed four-bit code (`1111`). This is not production authentication.
- The source retains academic simplifications in mode sequencing, initialization, memory and reset design; verification on the intended simulator/hardware remains necessary.
- A slower prescaled clock is used for human-visible output; simulation often needs a smaller prescaler than physical hardware.
- The supplied LCD and debounce source files are course-provided dependencies, not claimed as wholly original student code.
- Physical FPGA operation requires a Quartus project and a DE2-115 pin-mapping file. Neither is supplied.

## Excluded materials

Original assignment PDFs, unmarked project checklist, obsolete `.vhd.bak`, temporary simulation artifacts and private identifiers were excluded from the public repository.
