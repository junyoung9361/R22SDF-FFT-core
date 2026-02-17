# R22SDF-FFT-core

R2^2 SDF FFT/IFFT engine with fixed-point MATLAB modeling, Verilog RTL implementation, and FPGA validation flow.

## Overview

This project implements a streaming **R2^2 SDF FFT/IFFT core** and verifies it across:

1. MATLAB fixed-point model (golden/reference generation)
2. Verilog RTL simulation (AXI-Stream interface)
3. FPGA-oriented integration (AXI4-Lite control + AXI DMA software test)

## Key Features

- FFT/IFFT mode support
- Configurable point size: **2 to 1024**
- Complex fixed-point datapath: **32-bit total (16-bit real + 16-bit imag)**
- AXI4-Stream input/output data path
- AXI4-Lite control register interface
- Bit-reversal output reordering stage

## Repository Structure

- `HW/`: Verilog RTL
- `HW/top/fft_core.v`: main FFT core
- `HW/top/fft_top.v`: AXI-Lite + AXI-Stream integrated top
- `HW/stage/`: stage-level arithmetic and pipeline blocks
- `HW/bit_reverse/`: bit-reversal modules
- `testbench/`: simulation testbenches and twiddle ROM hex files
- `matlab/`: floating/fixed-point modeling, vector generation, error analysis
- `SW/`: AXI DMA + control software for FPGA-side validation
- `python/`: helper scripts/data conversion files

## Design Flow

1. Generate input/golden vectors from MATLAB model (`matlab/fft_fixed.m`, `matlab/fft_float.m`)
2. Run RTL simulation using `testbench/tb_fft_core.sv`
3. Integrate with AXI-based top (`HW/top/fft_top.v`)
4. Validate on FPGA using DMA/control software (`SW/main.c`)

## Quick Start

### 1) MATLAB model

- Run:
  - `matlab/fft_fixed.m`
  - `matlab/mse.m`
- Output vectors are written under `matlab/` and `matlab/test_vector/`.

### 2) RTL simulation

- Main TB: `testbench/tb_fft_core.sv`
- Ensure ROM/vector hex files are in simulator search path:
  - `testbench/twiddle_ROM_*.hex`
  - `matlab/test_vector/.../*.hex`

### 3) FPGA validation

- Top module: `HW/top/fft_top.v`
- Control/Data path:
  - AXI4-Lite for config (point size, inverse mode)
  - AXI4-Stream + DMA for sample transfer
- Software examples:
  - `SW/main.c`
  - `SW/test.c`

## Notes

- This repository contains research/course project style code and test vectors.
- File names and some scripts preserve original naming used during development.

## License
This project was developed as part of the **System Semiconductor Design** coursework at **Kwangwoon University**.

