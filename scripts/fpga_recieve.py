import serial
import time

PORT = (
    "/dev/serial/by-id/"
    "usb-SIPEED_USB_Debugger_2025030317-if01-port0"
)

BAUD = 460_800
ADC_REFERENCE = 3.3

#valid high byte must have 0xA in its upper nibble.
HIGH_BYTE_MASK = 0xF0
HIGH_BYTE_TAG = 0xA0

high_byte = None

total_samples = 0
samples_this_interval = 0
discarded_bytes = 0

minimum = 4095
maximum = 0
latest = 0

report_start = time.monotonic()

with serial.Serial(
    port=PORT,
    baudrate=BAUD,
    bytesize=serial.EIGHTBITS,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_ONE,
    timeout=0.1
) as uart:

    uart.reset_input_buffer()

    print("ADC receiver started")
    print("Port:", PORT)
    print("Baud:", BAUD)
    print("Waiting for 0xAxxx ADC words...")
    print("Press Ctrl+C to stop")

    try:
        while True:
            # Read several available bytes at once.
            chunk = uart.read(4096)

            for byte in chunk:
                if high_byte is None:
                    # Search for the high byte tag.
                    if (byte & HIGH_BYTE_MASK) == HIGH_BYTE_TAG:
                        high_byte = byte
                    else:
                        discarded_bytes += 1

                else:
                    low_byte = byte

                    sample_12 = (
                        ((high_byte & 0x0F) << 8)
                        | low_byte
                    )

                    high_byte = None

                    latest = sample_12
                    total_samples += 1
                    samples_this_interval += 1

                    if sample_12 < minimum:
                        minimum = sample_12

                    if sample_12 > maximum:
                        maximum = sample_12

            now = time.monotonic()
            elapsed = now - report_start

            # Report once per second, printing every sample will mess with sampling
            if elapsed >= 1.0:
                sample_rate = samples_this_interval / elapsed
                voltage = latest * ADC_REFERENCE / 4095
                centered = latest - 2048

                print(
                    "rate={:7.1f} samples/s  "
                    "adc={:4d}  "
                    "voltage={:.4f} V  "
                    "centered={:+5d}  "
                    "min={:4d}  "
                    "max={:4d}  "
                    "discarded={}".format(
                        sample_rate,
                        latest,
                        voltage,
                        centered,
                        minimum,
                        maximum,
                        discarded_bytes
                    )
                )

                samples_this_interval = 0
                minimum = 4095
                maximum = 0
                report_start = now

    except KeyboardInterrupt:
        print("\nReceiver stopped")
        print("Total samples:", total_samples)
        print("Discarded bytes:", discarded_bytes)