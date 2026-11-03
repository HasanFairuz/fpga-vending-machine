# FPGA Vending Machine — VHDL / DE2-115

An academic digital-logic project developed for **ENSC 252 — Fundamentals of Digital Logic and Design** at Simon Fraser University. The VHDL design targets the **Terasic DE2-115** development board (Cyclone IV E **EP4CE115F29C7**) and integrates a coin accumulator, programmable product-price storage, dispensing control, FPGA switches, LEDs, seven-segment displays, and LCD output.

> **Verification status:** This repository preserves the supplied implementation and its directed testbenches. The testbenches and simulation scripts have **not been executed in ModelSim/Questa or on physical FPGA hardware as part of preparing this repository**. Features described below are source-implemented/intended behavior, not independently verified test results.

## Hardware platform

<p align="center">
  <img src="media/Altera-Intel%20DE2-115%20FPGA%20development%20board.jpg" alt="Reference photograph of the Terasic DE2-115 FPGA development board" width="480" />
</p>

*Terasic DE2-115 development board (reference photograph of the target hardware; not evidence of this particular design running on the board).*

## Functional overview

The vending machine models **three purchasable products**, plus product index 0 as an idle/default entry, and four user-selectable modes:

| Mode | Code | Intended operation |
|---|---|---|
| Vend | `00` | Select a product, accept coin input, compare balance with price, and display change and a dispensing LED sequence |
| Program | `01` | Set a new product price using the same input switches and store it in price RAM |
| Free | `10` | Validate a four-bit passcode before activating free dispensing |
| Cancel | `11` | Cancel a transaction and return the accumulated balance as displayed change |

Soft reset returns control to the default vend state while preserving programmed prices; hard reset additionally restores the price RAM defaults, as defined in the source and project specification.

### Product prices

| Product index | Default price |
|---|---:|
| 0 | $0.00 |
| 1 | $0.47 |
| 2 | $1.30 |
| 3 | $0.75 |

Prices are stored as integer cents. Coin inputs represent **$1.00, $0.25, $0.10, and $0.05**, encoded by a priority encoder. The source defines the Free-mode comparison passcode as `1111` (a demonstration value, not a security feature).

## Hardware interface

| Control | Role |
|---|---|
| `SW(3 downto 0)` | Coin selection, from nickel (`SW0`) to dollar (`SW3`) |
| `SW(5 downto 4)` / `SW6` | Mode selection / Enter |
| `SW(8 downto 7)` / `SW9` | Product selection / Product Valid |
| `SW10` | Accept / input confirmation |
| `SW(14 downto 11)` | Free-mode passcode |
| `SW15` | Soft reset |
| `KEY3` | Active-low hard reset |
| `HEX2–HEX0` | Running coin total in cents |
| `HEX6–HEX4` | Change due in cents |
| `LEDG` and `LEDR` | Dispensing and mode-feedback sequences |
| LCD | Selected product and price |

The `top.vhd` design connects the component hierarchy to the board-facing ports. **Physical FPGA pin assignments and successful synthesis/programming are not included in this repository.**

## Repository layout

```text
fpga-vending-machine/
├── README.md
├── .gitignore
├── media/             # Board reference photograph and three design diagrams
├── docs/
│   ├── SYSTEM_ARCHITECTURE.md
│   ├── FUNCTIONALITY_AND_MODES.md
│   ├── SIMULATION_AND_TESTING.md
│   └── HARDWARE_AND_LIMITATIONS.md
└── src/
    ├── components/       # Main vending logic and top-level VHDL
    ├── DO/               # Portable ModelSim/Questa Tcl scripts
    ├── lcd/              # LCD support modules, debounce, character reference
    └── testbenches/      # Directed VHDL verification modules
```

The top-level entity is `top` in `src/components/top.vhd`. All source files are kept in **one canonical location**, without duplicating component dependencies in test directories.

## Architecture

- **`priority_enc` + `accumulator`:** decode one-hot coin selection and accumulate the running total.
- **`match_change`:** compare the total against the selected price and calculate change.
- **`vend_unit`:** integrate transaction logic, product registration, and price RAM updates.
- **`dispense_fsm`:** implement mode-dependent LED feedback.
- **`vend_periph`:** register mode and passcode inputs, connect transaction and display logic, and prescale the clock.
- **`convert2bcd` / `add3` / `SegDecoder`:** prepare numeric values for seven-segment output.
- **`top`:** connect FPGA inputs, debouncing, the peripherals, and the supplied LCD controller hierarchy.

See [System Architecture](docs/SYSTEM_ARCHITECTURE.md) and [Functionality and Modes](docs/FUNCTIONALITY_AND_MODES.md).

## Design diagrams and transaction example

The following diagrams summarize the documented VHDL module hierarchy and transaction control. They are **explanatory illustrations**, not ModelSim waveform captures or independent validation of FPGA operation.

### Module block diagram

![Module block diagram showing board inputs, vend_periph/vend_unit coordination, display path and LED feedback](media/1%20FPGA_Vending_Machine_Module_Block_Diagram.jpg)

*High-level signal flow between user inputs, the vending controller, price RAM, output displays, and dispensing-state feedback. Supporting LCD and debouncer logic is supplied for integration.*

### Transaction state diagram

![Transaction state diagram showing IDLE, ACTIVE, and DISPENSING with completion and reset transitions](media/2%20FPGA_Vending_Machine_Transaction_State_Diagram.jpg)

*Conceptual view of the primary transaction states. Additional logic handles Free-mode access, price programming, cancellation, and LED timing.*

### Sample transaction sequence

![Illustrative vend-mode transaction for a dollar and two quarters toward a one-dollar-thirty product, yielding twenty cents change](media/3%20FPGA_Vending_Machine_Sample_Transaction_Sequence.jpg)

*Illustrative Vend-mode example: Product 2 costs $1.30; a $1.00 coin and two $0.25 coins total $1.50, resulting in $0.20 change due. This diagram is a worked example, **not** a captured simulation run or hardware measurement.*

## Simulation

ModelSim/Questa scripts have been adapted from the course-style `.mpf` workflow to compile dependencies **directly from the repository structure**. From the repository root in the ModelSim transcript window:

```tcl
do src/DO/priority_encoder_setup.do
do src/DO/priority_encoder_run.do
```

Replace `priority_encoder` with `add3`, `accumulator`, `convert2bcd`, `match_change`, `vend_unit`, `dispense_fsm`, or `vend_periph` to run the corresponding testbench. **Use VHDL-2008**. The testbenches contain assertions, but results must be assessed in the ModelSim transcript; their presence is not proof that tests passed.

See [Simulation and Testing](docs/SIMULATION_AND_TESTING.md) for the compile order, commands, and validation criteria. The provided `.do` files are source-level setup/run helpers rather than the old `.mpf` project scripts; no waveform preset files were supplied.

## Attribution and scope

This is an academic project. The LCD controller and debouncer modules under `src/lcd/` include course-provided support circuitry; their inclusion documents the dependency hierarchy and does not imply independent authorship of those modules. Course assignment PDFs, submission checklists, private identifiers, and generated compilation outputs are intentionally excluded.

No repository license has been selected. Public availability alone does not grant reuse rights.

## Portfolio

**Hasan Fairuz** — Mechatronic Systems Engineering

[Engineering Portfolio](https://hasanfairuz.com/) · [GitHub Profile](https://github.com/HasanFairuz)
