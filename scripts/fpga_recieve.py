import sys
import time

import serial
from serial import SerialException


PORT = (
    "/dev/serial/by-id/"
    "usb-SIPEED_USB_Debugger_2025030317-if01-port0"
)

BAUD = 230_400
EXPECTED_SAMPLE_RATE = 8_000
ADC_REFERENCE = 3.3

# Every valid word has the format:
#
#   15            12 11                         0
#   +---------------+----------------------------+
#   | tag = 0xA     | 12-bit ADC sample          |
#   +---------------+----------------------------+
#
# UART sends the high byte first, followed by the low byte.
HIGH_BYTE_MASK = 0xF0
HIGH_BYTE_TAG = 0xA0


def main():
    high_byte = None

    total_samples = 0
    interval_samples = 0
    discarded_bytes = 0
    interval_discarded = 0

    minimum = 4095
    maximum = 0
    latest = 0

    program_start = time.monotonic()
    report_start = program_start

    try:
        with serial.Serial(
            port=PORT,
            baudrate=BAUD,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.1,
        ) as uart:
            # Discard bytes left over from an earlier run.
            uart.reset_input_buffer()

            print("ADC receiver started")
            print("Port:", PORT)
            print("UART baud:", BAUD)
            print("Expected rate:", EXPECTED_SAMPLE_RATE, "samples/s")
            print("Waiting for 0xAxxx ADC words...")
            print("Press Ctrl+C to stop")

            while True:
                # Read everything currently available. If the buffer is
                # empty, read one byte with the configured timeout.
                bytes_available = uart.in_waiting
                chunk = uart.read(bytes_available if bytes_available else 1)

                for byte in chunk:
                    if high_byte is None:
                        # Search for the tagged high byte.
                        if (byte & HIGH_BYTE_MASK) == HIGH_BYTE_TAG:
                            high_byte = byte
                        else:
                            discarded_bytes += 1
                            interval_discarded += 1
                    else:
                        # The byte after a tagged high byte is the low byte.
                        low_byte = byte

                        sample_12 = (
                            ((high_byte & 0x0F) << 8)
                            | low_byte
                        )

                        high_byte = None

                        latest = sample_12
                        total_samples += 1
                        interval_samples += 1

                        if sample_12 < minimum:
                            minimum = sample_12

                        if sample_12 > maximum:
                            maximum = sample_12

                now = time.monotonic()
                interval_elapsed = now - report_start

                # Printing every sample would substantially slow the program.
                if interval_elapsed >= 1.0:
                    if interval_samples > 0:
                        interval_rate = (
                            interval_samples / interval_elapsed
                        )

                        total_elapsed = now - program_start
                        average_rate = (
                            total_samples / total_elapsed
                        )

                        rate_error = (
                            interval_rate - EXPECTED_SAMPLE_RATE
                        )

                        voltage = (
                            latest * ADC_REFERENCE / 4095.0
                        )

                        centered = latest - 2048

                        print(
                            "rate={:7.1f}  "
                            "avg={:7.1f}  "
                            "error={:+7.1f}  "
                            "adc={:4d}  "
                            "voltage={:.4f} V  "
                            "centered={:+5d}  "
                            "min={:4d}  "
                            "max={:4d}  "
                            "discarded={} (+{})".format(
                                interval_rate,
                                average_rate,
                                rate_error,
                                latest,
                                voltage,
                                centered,
                                minimum,
                                maximum,
                                discarded_bytes,
                                interval_discarded,
                            )
                        )
                    else:
                        print(
                            "No valid ADC samples received "
                            "during the last second"
                        )

                    interval_samples = 0
                    interval_discarded = 0
                    minimum = 4095
                    maximum = 0
                    report_start = now

    except KeyboardInterrupt:
        print("\nReceiver stopped")
        print("Total valid samples:", total_samples)
        print("Total discarded bytes:", discarded_bytes)

    except SerialException as error:
        print("Serial-port error:", error)
        print()
        print("Check that:")
        print("  1. The Tang Nano is connected.")
        print("  2. No other program has the UART port open.")
        print("  3. The FPGA was programmed successfully.")
        print("  4. The FPGA UART is configured for 460800 baud.")
        sys.exit(1)


if __name__ == "__main__":
    main()