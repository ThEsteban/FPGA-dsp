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

### Fixed-Point FIR filter

- Implemented a 16-tap low-pass FIR in SystemVerilog using Q1.15 fixed-point coefficients
- Generated Hamming-windowed coefficients in Python/Scipy for an 8 kHz sample rate
- Verified impulse response, DC gain, passband/stopband behavior, and multi-tone filtering in simulation
- Matched RTL frequency response against a Python reference model
- Added signed rounding and saturation logic
- Refactored from 16 parallel multipliers to a time-multiplexed single-MAC architecture
- Reduced multiplier usage from 16 `MULT18X18` blocks to 1
- Achieved 212.72 MHz post-place-and-route Fmax against a 27 MHz target
- Began board-level integration on the Tang Nano 20K

Current FPGA build flow:

SystemVerilog RTL → Yosys → nextpnr → gowin_pack → openFPGALoader → Tang Nano 20K


## Next

- Finish board-level FIR validation
- Add self-checking RTL testbenches
- Stream real LDT0-028K / Pico 2 sensor samples into the FPGA
- Compare FPGA output against Python on recorded vibration data

### Future

- Add configurable FIR coefficients for different vibration bands
- Expand into a multi-band/filter-bank DSP pipeline
- Add feature extraction such as RMS, peak energy, and band power
- Interface directly with an external ADC or sensor acquisition module
- Optimize the MAC/datapath further with pipelining or coefficient symmetry
- Evaluate real hive vibration data and retune filters from measured spectra
- Integrate the DSP block into a larger WaggleNet sensing/telemetry system
