# uart_tb_sv
# UART Testbench in SystemVerilog

This repository contains a **SystemVerilog-based verification environment** for testing a UART module.  
It was created as part of my learning process to practice **object-oriented verification** concepts such as mailboxes, events, and class-based testbenches.

## Overview

The testbench follows a modular, class-based architecture:

| Component   | Role |
|-------------|------|
| **transaction** | Represents a single UART operation (read/write) with associated data and status fields. Supports randomization. |
| **generator**   | Creates randomized `transaction` objects and sends them to the driver. Controls the test flow using events. |
| **driver**      | Drives UART interface signals based on `transaction` data, handling both transmit and receive operations. |
| **monitor**     | Observes UART signals and captures transmitted/received data for comparison. |
| **scoreboard**  | Compares driver-sent data against monitor-captured data to check for mismatches. |
| **environment** | Connects and coordinates all components (generator, driver, monitor, scoreboard). |
| **tb**          | Top-level testbench module instantiating the DUT (`uart_top`) and running the environment. |

## Key Features
- **Randomized stimulus generation** using `rand` and `randc`.
- **Mailboxes** for transaction and data passing between components.
- **Events** for synchronization between generator, driver, and scoreboard.
- **Reusable transaction copy mechanism**.
- **Self-checking** via the scoreboard.
- **Support for both UART TX and RX paths**.

## How It Works
1. **Generator** produces randomized UART read/write transactions.
2. **Driver** sends data into the DUT or triggers receive operations.
3. **Monitor** listens on the UART interface and records actual data transfers.
4. **Scoreboard** compares expected vs. actual data and logs pass/fail results.
5. **Environment** manages the sequencing of the whole process.

## Running the Simulation
- Requires a SystemVerilog simulator (e.g., `iverilog`, `VCS`, `QuestaSim`).
- Compile all `.sv` files along with your `uart_top` and `uart_if` definitions.
- Run the simulation to generate console output and a `dump.vcd` waveform file.

## Notes
- This testbench is **educational** and not production-optimized.
- The code assumes the existence of `uart_top` and `uart_if` modules.
- Transaction count can be adjusted via:
  ```systemverilog
  env.gen.transaction_count = <N>;
