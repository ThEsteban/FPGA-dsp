# GOWIN Hard-DSP Debugging on Tang Nano 20K

## Overview

While validating a 16-tap fixed-point FIR filter on a Sipeed Tang Nano 20K, the design behaved correctly in RTL simulation but produced incorrect arithmetic on the physical FPGA.

The FIR itself had already been verified against a Python reference model using impulse, DC, passband, and stopband tests. The debugging effort therefore focused on isolating the difference between simulated RTL behavior and the synthesized hardware implementation.

The issue was ultimately isolated to the GOWIN hard-DSP implementation path used by the open-source toolchain.

Rebuilding the same design with DSP inference disabled produced correct results on the FPGA.

---

## Hardware and Toolchain

### FPGA

- Sipeed Tang Nano 20K
- Gowin GW2AR-18 FPGA
- 27 MHz onboard clock

### Open-Source Toolchain

- Yosys
- nextpnr-himbaechel
- Project Apicula / `gowin_pack`
- openFPGALoader
- Icarus Verilog
- GTKWave

The intended device configuration is:

```text
Yosys family:       gw2a
nextpnr device:     GW2AR-LV18QN88C8/I7
nextpnr family:     GW2A-18C
gowin_pack device:  GW2A-18C
```

---

# FIR Architecture

The filter is a 16-tap low-pass FIR intended for vibration/acoustic sensor data sampled at 8 kHz.

## Data Formats

```text
Input samples:   signed 12-bit
Coefficients:    signed 16-bit Q1.15
Accumulator:     signed 32-bit
Output:          signed 16-bit
```

The coefficients are:

```text
[102, 146, -102, -893, -1133, 1224, 6296, 10744,
 10744, 6296, 1224, -1133, -893, -102, 146, 102]
```

Their sum is:

```text
32768
```

Since the coefficients use Q1.15 representation:

```text
32768 / 2^15 = 1.0
```

Therefore, a constant input of 1000 should settle to:

```text
sample_out = 1000
```

## MAC Architecture

The implementation uses a single time-multiplexed multiply-accumulate datapath.

Each accepted input sample starts a 16-cycle MAC operation:

```text
tap 0
tap 1
tap 2
...
tap 15
```

One coefficient/sample product is accumulated per 27 MHz FPGA clock.

At an 8 kHz sample rate:

```text
27,000,000 / 8,000 = 3,375 clocks/sample
```

Only 16 clocks are required to process each sample, so there is substantial timing headroom.

---

# Pre-Hardware Verification

Before FPGA deployment, the FIR was validated in simulation.

The following tests passed:

- Impulse-response test
- Constant/DC-input test
- 250 Hz passband sine-wave test
- 2 kHz stopband sine-wave test
- Comparison against a Python reference implementation

The RTL simulation matched the expected fixed-point behavior.

This established that the coefficient set, delay-line ordering, MAC sequencing, rounding, and saturation logic were correct at the RTL level.

---

# Initial Hardware Symptom

After synthesizing and programming the Tang Nano 20K, the FIR did not produce the expected DC output.

A constant input of 1000 should have settled to approximately:

```text
1000
```

Instead, early debug versions suggested values around:

```text
480–500
```

This observation was interesting because the coefficient sum through tap 7 is exactly:

```text
102
+ 146
- 102
- 893
- 1133
+ 1224
+ 6296
+ 10744
= 16384
```

Therefore:

```text
1000 × 16384 / 32768 = 500
```

This initially suggested that only roughly half of the FIR accumulation might be contributing.

However, later debug revisions produced no positive output at all.

Because these measurements came from different RTL/debug revisions, they were not treated as one continuous failure mode.

---

# Hardware Isolation Strategy

The design was debugged incrementally by exposing internal conditions through the Tang Nano LEDs.

The goal was to determine exactly where the simulated and physical implementations diverged.

The hardware path was checked in stages:

```text
Bitstream
   ↓
Clock
   ↓
Sample timing
   ↓
FIR control
   ↓
Delay line
   ↓
Tap counter
   ↓
Multiplier
   ↓
Accumulator
   ↓
Rounding / saturation
   ↓
sample_out
```

---

# 1. FPGA Programming and GPIO

The first tests verified that the correct FPGA design was actually executing.

Confirmed:

- Correct bitstream reaches the FPGA
- Constant LED assignments work
- LED pin constraints are correct
- LEDs are active-low
- FPGA programming through `openFPGALoader` works

This ruled out incorrect bitstreams, incorrect LED pins, and basic programming failures.

---

# 2. Clock and Sample Timing

The 27 MHz FPGA clock was verified indirectly through working counters and timing logic.

The design generates an 8 kHz sample event using:

```text
27 MHz / 3375 = 8 kHz
```

A sticky LED flag was used to confirm that `sample_valid` occurs on hardware.

Confirmed:

```text
sample_valid = PASS
```

---

# 3. FIR State-Machine Completion

The FIR contains a `busy` state while processing the 16 taps.

Hardware instrumentation confirmed that:

- The FIR accepts a new sample
- The FIR becomes busy
- The MAC operation completes
- `output_valid` occurs

Confirmed:

```text
FIR control FSM = PASS
output_valid     = PASS
```

This ruled out a stalled or incomplete state machine.

---

# 4. Tap Counter

The internal tap index was instrumented to determine whether the design really progressed through the complete FIR.

A debug flag checked for:

```systemverilog
busy && (tap_index == 4'd15)
```

The flag was observed on hardware.

Confirmed:

```text
tap_index reaches 15 = PASS
```

Therefore, the FIR was not stopping after tap 7 or otherwise terminating early.

---

# 5. Delay-Line Verification

The next hypothesis was that later samples in the delay line were not being populated correctly.

The FIR delay line contains 16 samples:

```text
samples[0]
samples[1]
...
samples[15]
```

For a constant input of 1000, debug outputs were added for:

```text
samples[0]  == 1000
samples[7]  == 1000
samples[15] == 1000
```

All three conditions were eventually observed on the physical FPGA.

Confirmed:

```text
samples[0]  = 1000
samples[7]  = 1000
samples[15] = 1000
```

Therefore:

```text
Delay-line propagation = PASS
```

This ruled out the delay line as the primary cause.

---

# Debugging Mistakes Found During Instrumentation

Several bugs were discovered in temporary debug code while isolating the real issue.

These were corrected before making final conclusions.

## Incorrect Debug Timing

MAC debug signals were initially checked only while `output_valid` was high.

This was incorrect because the tap-15 MAC condition occurs one clock before the top level observes the registered `output_valid`.

For example:

```text
tap-15 cycle:
debug_mac_positive = valid
output_valid        = 0

following cycle:
debug_mac_positive = 0
output_valid        = 1
```

Therefore, the tap-15 flags had to be latched independently of `output_valid`.

---

# 6. MAC Arithmetic Investigation

After ruling out the control path and delay line, the investigation moved to the arithmetic datapath.

The multiplication was rewritten with explicit signed widths to eliminate ambiguity from SystemVerilog expression-sizing rules.

The relevant structure became:

```systemverilog
logic signed [31:0] current_product;
logic signed [15:0] current_coeff;
logic signed [31:0] mac_sum;

current_coeff   = coeff(tap_index);
current_product = 32'sd1000 * current_coeff;
mac_sum         = accumulator + current_product;
```

The forced constant `1000` was used temporarily so that the delay-line read was completely removed from the arithmetic test.

This reduced the datapath under test to:

```text
tap_index
   ↓
coefficient
   ↓
signed multiply by 1000
   ↓
accumulator
```

---

# Expected Cycle-by-Cycle MAC Values

For forced input 1000, the expected product and accumulator values are:

| Tap | Coefficient | Product | MAC after tap |
|---:|---:|---:|---:|
| 0 | 102 | 102,000 | 102,000 |
| 1 | 146 | 146,000 | 248,000 |
| 2 | -102 | -102,000 | 146,000 |
| 3 | -893 | -893,000 | -747,000 |
| 4 | -1133 | -1,133,000 | -1,880,000 |
| 5 | 1224 | 1,224,000 | -656,000 |
| 6 | 6296 | 6,296,000 | 5,640,000 |
| 7 | 10744 | 10,744,000 | 16,384,000 |
| 8 | 10744 | 10,744,000 | 27,128,000 |
| 9 | 6296 | 6,296,000 | 33,424,000 |
| 10 | 1224 | 1,224,000 | 34,648,000 |
| 11 | -1133 | -1,133,000 | 33,515,000 |
| 12 | -893 | -893,000 | 32,622,000 |
| 13 | -102 | -102,000 | 32,520,000 |
| 14 | 146 | 146,000 | 32,666,000 |
| 15 | 102 | 102,000 | 32,768,000 |

The expected final value is therefore:

```text
mac_sum = 32,768,000
```

After Q1.15 scaling:

```text
32,768,000 >> 15 = 1000
```

---

# 7. RTL and Synthesis Checks

The current RTL was checked using both Icarus Verilog and Yosys.

The current design was inspected for:

- Multiple drivers
- Inferred latches
- Combinational loops
- Signedness issues
- Width truncation
- Missing taps
- Incorrect tap-15 timing
- Debug-flag timing

The investigation found:

```text
No multiple drivers in current MAC/debug path
No inferred latches
No combinational loops
Signed comparisons represented correctly
Signed accumulation represented correctly
All 16 taps included
Tap-15 sticky debug signals sampled correctly
```

One unrelated portability issue was found in `top.sv`.

The source contained:

```systemverilog
if (!&reset_counter)
```

Yosys accepted this form, but Icarus Verilog rejected it.

It was changed to:

```systemverilog
if (!(&reset_counter))
```

The top level also had an unused/undriven `led2` during one debugging revision.

Neither issue explained the arithmetic failure.

---

# 8. RTL Simulation Result

The current FIR RTL was simulated with the forced input of 1000.

RTL simulation produced:

```text
debug_mac_positive      = 1
debug_mac_near_expected = 1
sample_out              = 1000
```

The final MAC result was:

```text
32,768,000
```

This matched the mathematical reference exactly.

Therefore:

```text
RTL arithmetic = PASS
```

The accumulator sequencing, signed arithmetic, and output scaling were not the source of the hardware failure.

---

# 9. Reset Investigation

The top-level power-on reset originally used a declaration initializer:

```systemverilog
logic [7:0] reset_counter = 0;
```

There was concern that the initializer might not produce the expected FPGA power-up state.

However, this was ruled out as the primary cause because the physical FPGA had already demonstrated:

- `sample_valid`
- FIR activity
- progression through all 16 taps
- `output_valid`

Therefore, sequential control was clearly operating.

The failure was downstream of basic reset and control initialization.

---

# 10. Synthesized Multiplier Investigation

The project uses the open-source GOWIN flow rather than the vendor GOWIN IDE.

Inspection of the synthesized design showed that Yosys inferred GOWIN DSP primitives for the signed multiplication.

The multiplier was mapped into physical:

```text
MULT9X9
```

resources.

This was the first major clue connecting the simulation/hardware discrepancy to the physical DSP implementation.

The earlier successful tests primarily exercised:

```text
GPIO
LUTs
flip-flops
counters
control logic
delay-line registers
```

The FIR multiplication was the first major test that depended on the GOWIN hard multiplier path.

---

# 11. DSP Bypass Test

The same design was rebuilt while explicitly disabling DSP inference:

```text
synth_gowin -family gw2a -nodsp
```

With `-nodsp`, Yosys implemented the multiplication using general FPGA logic rather than GOWIN hard multiplier blocks.

The FPGA was reprogrammed with this bitstream.

The hardware debug LEDs then behaved correctly.

This produced the key isolation result:

```text
RTL FIR / accumulator      PASS
FIR control logic          PASS
Delay line                 PASS
LUT-based multiplier       PASS
GOWIN hard-DSP path        FAIL
```

The same logical FIR datapath functioned correctly when the inferred hard-DSP implementation was removed.

---

# Root Cause Isolation

The hardware failure was therefore not caused by:

- FIR coefficients
- Q1.15 scaling
- accumulator sequencing
- tap-counter sequencing
- missing taps
- delay-line propagation
- SystemVerilog signed arithmetic at the RTL level
- output rounding
- output saturation
- reset behavior
- LED polarity
- LED pin mapping
- incorrect FPGA programming
- sample timing
- `output_valid` timing

The failure was isolated to the GOWIN hard-DSP implementation path produced by the open-source flow.

---

# Current Working Configuration

The current workaround is:

```text
synth_gowin -family gw2a -nodsp
```

This forces multiplication into LUT fabric.

The real multiplier can then use:

```systemverilog
current_product =
    $signed(samples[tap_index]) *
    $signed(current_coeff);
```

rather than the temporary forced-1000 debug expression.

---

# Resource and Timing Tradeoff

Disabling DSP inference has several expected costs.

## Disadvantages

- Higher LUT usage
- Potentially higher dynamic power
- Lower possible maximum multiplier frequency
- Dedicated GOWIN multiplier resources remain unused

## Why It Is Acceptable Here

This FIR has modest performance requirements.

Only one time-multiplexed multiplier is needed.

The clock frequency is:

```text
27 MHz
```

Each filter result requires:

```text
16 clocks
```

Each new sample arrives every:

```text
3375 clocks
```

Therefore:

```text
16 << 3375
```

The datapath has substantial timing headroom.

The GW2AR-18 also contains enough LUT fabric that a single LUT-based signed multiplier is likely practical for this stage of the project.

Actual resource utilization should still be checked after restoring the real variable sample multiplication.

---

# Remaining Unknown

The exact low-level cause inside the hard-DSP flow has not yet been proven.

Possible causes include:

- Yosys signed multiplier decomposition
- incorrect composition of multiple `MULT9X9` primitives
- nextpnr GOWIN DSP packing
- Project Apicula bitstream configuration
- an OSS CAD Suite version-specific bug
- incorrect or inconsistent GW2A-18C device-family handling
- a toolchain interaction specific to the GW2AR-18 device

These remain hypotheses.

The debugging completed so far proves only that:

```text
DSP-enabled synthesized implementation fails on hardware
DSP-disabled LUT implementation works on hardware
```

It does not yet identify which individual tool or primitive configuration is responsible.

---

## Minimal Reproducer

A useful future step would be to create a minimal design containing only:

```text
signed input A
signed input B
      ↓
signed multiply
      ↓
registered result
      ↓
GPIO/UART observation
```

The same design could then be synthesized:

```text
with DSP inference
```

and:

```text
with -nodsp
```

If the LUT version works and the DSP version fails, that would create a much cleaner upstream bug report than the full FIR design.

---

# Final Result

The FIR design was successfully validated on physical hardware after disabling DSP inference.

The debugging process established:

```text
Simulation                  PASS
FIR algorithm               PASS
Fixed-point arithmetic      PASS
Control state machine       PASS
Delay line                  PASS
Tap sequencing              PASS
LUT-based multiplication    PASS
Hard-DSP implementation     FAIL
```

The current working solution uses LUT-based multiplication through:

```text
-nodsp
```

This preserves the intended 8 kHz sample rate and 16-cycle MAC architecture while avoiding the failing hard-DSP implementation path.

The remaining DSP issue is a toolchain/hardware-mapping investigation rather than an FIR-design correctness issue.