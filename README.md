# FPGA DSP Accelerator

FPGA-based signal-processing accelerator targeting the Sipeed Tang Nano 20K (Gowin GW2AR-18 FPGA).

The project implements and validates hardware-accelerated processing of acoustic and vibration sensor data for the WaggleNet bee-monitoring system.

## Hardware

- Sipeed Tang Nano 20K, v3923
- Gowin GW2AR-18 FPGA
- 27 MHz onboard clock

## Toolchain

Using the open-source OSS CAD Suite toolchain:

- **Yosys** — SystemVerilog synthesis
- **nextpnr-himbaechel** — FPGA place and route
- **Project Apicula / `gowin_pack`** — Gowin bitstream generation
- **openFPGALoader** — FPGA programming
- **Icarus Verilog + GTKWave** — RTL simulation and waveform inspection
- **Python / SciPy** — FIR coefficient generation and software reference verification

Project Apicula provides the open-source Gowin FPGA support used by the synthesis, place-and-route, and bitstream-generation flow.

Current FPGA build flow:

```text
SystemVerilog RTL
        ↓
      Yosys
        ↓
nextpnr-himbaechel
        ↓
   gowin_pack
        ↓
 openFPGALoader
        ↓
  Tang Nano 20K
```

## Progress

### Board Bring-Up

- Set up and verified the OSS CAD Suite toolchain
- Familiarized myself with the Tang Nano 20K architecture and board specifications
- Implemented a parameterized SystemVerilog counter/blinker
- Created a simulation testbench and verified behavior using GTKWave
- Synthesized the design with Yosys
- Placed and routed the design with nextpnr
- Generated a Gowin bitstream with `gowin_pack`
- Programmed the Tang Nano 20K with `openFPGALoader`
- Verified correct operation on physical hardware

### Fixed-Point FIR Filter

Implemented and validated a 16-tap low-pass FIR filter targeting vibration/acoustic sensor data sampled at 8 kHz.

#### Architecture

- 12-bit signed input samples
- 16-bit Q1.15 coefficients
- 32-bit signed accumulator
- 16-bit signed output
- 16-tap low-pass response
- Single time-multiplexed multiplier
- 16 MAC cycles per output sample
- 27 MHz FPGA clock
- 8 kHz sample rate
- 3,375 FPGA clock cycles available between input samples

The FIR coefficients are:

```text
[102, 146, -102, -893, -1133, 1224, 6296, 10744,
 10744, 6296, 1224, -1133, -893, -102, 146, 102]
```

The coefficient sum is 32768, corresponding to unity DC gain in Q1.15. A constant input of 1000 therefore produces a steady-state output of 1000.

#### Verification

Verified using:

- Impulse-response testing
- Constant/DC-input testing
- 250 Hz passband sine-wave testing
- 2 kHz stopband sine-wave testing
- Python reference-model comparison
- Physical FPGA validation of the 8 kHz sample timing
- Physical FPGA validation of all 16 MAC cycles
- Physical FPGA validation of delay-line propagation
- Physical FPGA validation of the final filtered output

Simulation results matched the Python reference implementation.

### Open-Source GOWIN DSP Toolchain Investigation

During physical hardware validation, the FIR produced incorrect arithmetic when Yosys inferred the GOWIN hard-DSP multiplier path.

The issue was isolated through hardware instrumentation. The following were independently verified on the FPGA:

- Correct bitstream programming
- Clock generation
- `sample_valid`
- FIR `busy` / completion behavior
- `output_valid`
- Progression through tap 15
- Delay-line propagation through the complete 16-sample history
- Correct RTL accumulator behavior in simulation

For a forced input of 1000, RTL simulation produces the expected final accumulation:

```text
Tap 0:      102,000
Tap 1:      248,000
Tap 2:      146,000
Tap 3:     -747,000
Tap 4:   -1,880,000
Tap 5:     -656,000
Tap 6:    5,640,000
Tap 7:   16,384,000
Tap 8:   27,128,000
Tap 9:   33,424,000
Tap 10:  34,648,000
Tap 11:  33,515,000
Tap 12:  32,622,000
Tap 13:  32,520,000
Tap 14:  32,666,000
Tap 15:  32,768,000
```

This corresponds to the expected filtered output:

```text
sample_out = 1000
```

Inspection of the synthesized design showed that Yosys mapped the signed multiplication onto GOWIN hard multiplier/DSP resources.

Rebuilding with DSP inference disabled:

```text
synth_gowin -family gw2a -nodsp
```

produced correct results on the physical FPGA using LUT-based multiplication.

Current status:

```text
RTL FIR / accumulator         PASS
Control logic                 PASS
Delay line                    PASS
LUT-based multiplication      PASS
GOWIN hard-DSP implementation FAIL
```

The remaining issue appears to lie in the open-source GOWIN DSP implementation path rather than the FIR algorithm itself. Possible sources include Yosys multiplier decomposition, nextpnr DSP packing, Apicula bitstream configuration, or toolchain/version-specific behavior.

The LUT-based implementation is currently used as the working configuration. This is acceptable for the present design because only one time-multiplexed multiplier is required and the target clock frequency is 27 MHz.

A detailed debugging write-up is available in:

```text
docs/gowin_dsp_debug.md
```

## Next


### Milestone 2 — Hardware Signal Path

- Check LUT utilization and timing at 27 MHz
- Stream raw and filtered samples to a host computer
- Add UART-based debug/output support
- Interface the Raspberry Pi Pico 2 ADC frontend with the FPGA
- Feed real piezoelectric accelerometer data into the FIR
- Compare raw and filtered sensor waveforms

## Future

- Add additional signal-processing stages
- Explore FFT/spectral feature extraction
- Extract features useful for bee acoustic and vibration analysis
- Integrate FPGA processing into the larger WaggleNet sensing pipeline

also, 

-Investigate OSS CAD Suite, Yosys, nextpnr, and Apicula releases for correct GOWIN DSP behavior
- Create a minimal signed-multiplier reproducer for the hard-DSP issue
- Evaluate manually instantiated GOWIN multiplier primitives
