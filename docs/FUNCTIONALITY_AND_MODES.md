# Functionality and Modes

The course project defined four modes; the supplied VHDL includes logic and testbenches targeting these behaviors. The following describes intended behavior and source-level implementation, not an independently completed verification campaign.

## Mode 00: Vend

Select one of the product indices, pulse Product Valid, and register coin entries with Accept. The accumulator tracks cents and match/change logic compares the running total with the selected product's price. Upon sufficient payment, the design generates change information and triggers an LED dispensing pattern.

## Mode 01: Program

Select a product and build the new price with coin inputs; confirm to write the value into the price RAM. A hard reset restores defaults. Default prices by index 0–3 are 0, 47, 130 and 75 cents.

## Mode 10: Free

The design compares the passcode input with `1111`. It includes positive/negative feedback via the LED array and a route to dispensing without a payment requirement after a valid entry. This is a demonstrative four-bit comparison, not a secure authentication mechanism.

## Mode 11: Cancel

The intent is to abort an in-progress transaction, represent the accumulated balance as refundable change, and return to the default vend state. The specification does not permit cancellation once dispensing is in progress.

## User interface

Physical input mapping is documented in README.md and `top.vhd`. Money amounts are represented as integer cents on the seven-segment displays, without a decimal point. Product number and price are routed to the LCD subsystem.

## Resets

- Soft reset: return to vend and clear the active transaction without resetting programmed product prices.
- Hard reset: restore product RAM defaults in addition to transaction reset.

## Evidence boundary

The existence of modules and testbenches supports describing these behaviors as implemented/test-targeted. It does not prove that all scenarios pass in ModelSim or on the target FPGA; retain that distinction in portfolio descriptions until verified.
