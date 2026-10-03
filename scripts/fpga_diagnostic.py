import time
from collections import Counter

import serial


PORT = (
    "/dev/serial/by-id/"
    "usb-SIPEED_USB_Debugger_2025030317-if01-port0"
)

BAUD = 230_400

EXPECTED_WORD = 0xA801
EXPECTED_RATE = 8_000

# Require two correct consecutive words before fixing the byte alignment.
SYNC_PATTERN = bytes([
    (EXPECTED_WORD >> 8) & 0xFF,
    EXPECTED_WORD & 0xFF,
    (EXPECTED_WORD >> 8) & 0xFF,
    EXPECTED_WORD & 0xFF,
])


def format_common_words(counter, maximum=8):
    if not counter:
        return "none"

    entries = []

    for word, count in counter.most_common(maximum):
        entries.append("0x{:04X}:{}".format(word, count))

    return ", ".join(entries)


def main():
    synchronized = False
    sync_window = bytearray()
    high_byte = None

    pre_sync_total_bytes = 0
    pre_sync_interval_bytes = 0
    pre_sync_preview = bytearray()

    interval_total = 0
    interval_correct = 0
    interval_tagged = 0
    interval_incorrect = 0
    interval_bad_words = Counter()

    lifetime_total = 0
    lifetime_correct = 0
    lifetime_tagged = 0
    lifetime_incorrect = 0
    lifetime_bad_words = Counter()

    report_start = time.monotonic()
    test_start = None

    with serial.Serial(
        port=PORT,
        baudrate=BAUD,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0.1,
    ) as uart:
        uart.reset_input_buffer()

        print("Raw FPGA diagnostic receiver")
        print("Port:", PORT)
        print("UART baud:", BAUD)
        print("Expected word: 0x{:04X}".format(EXPECTED_WORD))
        print("Expected rate:", EXPECTED_RATE, "words/s")
        print("Waiting for two consecutive 0xA801 words...")
        print("Press Ctrl+C to stop")

        try:
            while True:
                available = uart.in_waiting
                chunk = uart.read(available if available else 1)

                for byte in chunk:
                    if not synchronized:
                        pre_sync_total_bytes += 1
                        pre_sync_interval_bytes += 1

                        if len(pre_sync_preview) < 32:
                            pre_sync_preview.append(byte)

                        sync_window.append(byte)

                        if len(sync_window) > len(SYNC_PATTERN):
                            del sync_window[0]

                        if bytes(sync_window) == SYNC_PATTERN:
                            synchronized = True
                            high_byte = None
                            test_start = time.monotonic()
                            report_start = test_start

                            print()
                            print("Byte alignment acquired")
                            print()

                        continue

                    if high_byte is None:
                        high_byte = byte
                        continue

                    word = (high_byte << 8) | byte
                    high_byte = None

                    interval_total += 1
                    lifetime_total += 1

                    if word == EXPECTED_WORD:
                        interval_correct += 1
                        lifetime_correct += 1
                    else:
                        interval_incorrect += 1
                        lifetime_incorrect += 1

                        interval_bad_words[word] += 1
                        lifetime_bad_words[word] += 1

                    if (word & 0xF000) == 0xA000:
                        interval_tagged += 1
                        lifetime_tagged += 1

                now = time.monotonic()
                elapsed = now - report_start

                if not synchronized:
                    if elapsed >= 1.0:
                        preview = " ".join(
                            "{:02X}".format(byte)
                            for byte in pre_sync_preview
                        )

                        if pre_sync_interval_bytes == 0:
                            print("Still waiting: no UART bytes received")
                        else:
                            print(
                                "Still waiting: raw_bytes={} (+{})  "
                                "first_bytes={}".format(
                                    pre_sync_total_bytes,
                                    pre_sync_interval_bytes,
                                    preview,
                                )
                            )

                        pre_sync_interval_bytes = 0
                        pre_sync_preview.clear()
                        report_start = now

                    continue

                if elapsed >= 1.0:
                    total_rate = interval_total / elapsed
                    correct_rate = interval_correct / elapsed
                    tagged_rate = interval_tagged / elapsed
                    incorrect_rate = interval_incorrect / elapsed
                    missing_rate = EXPECTED_RATE - total_rate

                    if interval_total:
                        correct_percent = (
                            interval_correct * 100.0 / interval_total
                        )
                    else:
                        correct_percent = 0.0

                    print(
                        "total={:7.1f}/s  "
                        "correct={:7.1f}/s  "
                        "tagged={:7.1f}/s  "
                        "incorrect={:7.1f}/s  "
                        "missing={:+7.1f}/s  "
                        "correct={:5.1f}%".format(
                            total_rate,
                            correct_rate,
                            tagged_rate,
                            incorrect_rate,
                            missing_rate,
                            correct_percent,
                        )
                    )

                    print(
                        "common incorrect words:",
                        format_common_words(interval_bad_words),
                    )

                    interval_total = 0
                    interval_correct = 0
                    interval_tagged = 0
                    interval_incorrect = 0
                    interval_bad_words.clear()
                    report_start = now

        except KeyboardInterrupt:
            print()
            print("Diagnostic stopped")

            if synchronized and test_start is not None:
                total_elapsed = time.monotonic() - test_start

                if total_elapsed > 0:
                    average_total_rate = lifetime_total / total_elapsed
                    average_correct_rate = lifetime_correct / total_elapsed
                else:
                    average_total_rate = 0
                    average_correct_rate = 0

                print("Elapsed seconds:", total_elapsed)
                print("Total words:", lifetime_total)
                print("Correct 0xA801 words:", lifetime_correct)
                print("Valid-tag words:", lifetime_tagged)
                print("Incorrect words:", lifetime_incorrect)
                print("Average total rate:", average_total_rate)
                print("Average correct rate:", average_correct_rate)
                print(
                    "Most common incorrect words:",
                    format_common_words(lifetime_bad_words, maximum=20),
                )
            else:
                print("Byte alignment was never acquired")


if __name__ == "__main__":
    main()
