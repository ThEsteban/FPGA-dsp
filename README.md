## FPGA DSP Accelerator 

FPGA-based signal processing accelerator targeting the Sipeed Tang Nano 20K (Gowin GW2AR-18 FPGA). The goal of this project is to explore hardware-accelerated processing of acoustic/vibration sensor data for the WaggleNet bee-monitoring system.

## hardware 

- Sipeed Tang Nano 20K, v3923
- Gowin GW2AR-18 FPGA
- 27 MHz onboard clock

## toolchain

Using the open-source OSS CAD Suite toolchain: 

- **Yosys** — SystemVerilog synthesis
- **nextpnr-himbaechel** — FPGA place and route
- **Project Apicula / gowin_pack** — Gowin bitstream generation
- **openFPGALoader** — FPGA programming
- **Icarus Verilog + GTKWave** — RTL simulation and waveform inspection

Project Apicula provides the open-source Gowin FPGA support used by the synthesis, place-and-route, and bitstream generation flow.

## Progress

### Board Bring-Up

- Set up and verified the OSS CAD Suite toolchain
- Familiarized myself with the Tang Nano 20K architecture and board specifications
- Implemented a parameterized SystemVerilog counter/blinker
- Created a simulation testbench and verified behavior using GTKWave
- Synthesized the design with Yosys
- Placed and routed the design with nextpnr
- Generated a Gowin bitstream with gowin_pack
- Programmed the Tang Nano 20K with openFPGALoader
- Verified correct operation on physical hardware

Current FPGA build flow:

SystemVerilog RTL → Yosys → nextpnr → gowin_pack → openFPGALoader → Tang Nano 20K


## Next

### Milestone 1 — Fixed-Point FIR Filter

- Select fixed-point representations for samples and coefficients
- Design an initial 8-tap FIR filter architecture
- Implement a software reference model for verification
- Implement the FIR filter in SystemVerilog
- Develop a self-checking RTL testbench
- Synthesize the design and evaluate FPGA resource usage and timing

### Future

- Pipeline and optimize the DSP datapath
- Develop a hardware sample-input interface
- Process real acoustic/vibration sensor data
- Add additional signal-processing and feature-extraction stages