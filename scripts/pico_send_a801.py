from machine import Pin, SPI
import gc
import time


SAMPLE_RATE_HZ = 8_000
SAMPLE_PERIOD_US = 1_000_000 // SAMPLE_RATE_HZ

SPI_SCK_PIN = 18
SPI_MOSI_PIN = 19
SPI_MISO_PIN = 16
SPI_CS_PIN = 17

SPI_BAUD = 500_000
TEST_WORD = 0xA801


cs_n = Pin(SPI_CS_PIN, Pin.OUT, value=1)

spi = SPI(
    0,
    baudrate=SPI_BAUD,
    polarity=0,
    phase=0,
    bits=8,
    firstbit=SPI.MSB,
    sck=Pin(SPI_SCK_PIN),
    mosi=Pin(SPI_MOSI_PIN),
    miso=Pin(SPI_MISO_PIN),
)

tx_buffer = bytearray([
    (TEST_WORD >> 8) & 0xFF,
    TEST_WORD & 0xFF,
])

sample_count = 0
overrun_count = 0

gc.collect()
gc.disable()

start_time = time.ticks_us()
next_sample_time = start_time

print("Fixed SPI diagnostic sender started")
print("Word: 0x{:04X}".format(TEST_WORD))
print("SPI baud:", SPI_BAUD)
print("Target rate:", SAMPLE_RATE_HZ, "packets/s")
print("Press Ctrl+C to stop")

try:
    while True:
        while time.ticks_diff(
            next_sample_time,
            time.ticks_us(),
        ) > 0:
            pass

        next_sample_time = time.ticks_add(
            next_sample_time,
            SAMPLE_PERIOD_US,
        )

        cs_n.value(0)
        time.sleep_us(2)
        spi.write(tx_buffer)
        time.sleep_us(2)
        cs_n.value(1)

        sample_count += 1

        if time.ticks_diff(
            time.ticks_us(),
            next_sample_time,
        ) >= 0:
            overrun_count += 1
            next_sample_time = time.ticks_add(
                time.ticks_us(),
                SAMPLE_PERIOD_US,
            )

except KeyboardInterrupt:
    print("\nSender stopped")

finally:
    stop_time = time.ticks_us()
    elapsed_us = time.ticks_diff(stop_time, start_time)

    cs_n.value(1)
    spi.deinit()
    gc.enable()

    actual_rate = 0.0
    if elapsed_us > 0:
        actual_rate = sample_count * 1_000_000 / elapsed_us

    print("Elapsed seconds:", elapsed_us / 1_000_000)
    print("Packets sent:", sample_count)
    print("Actual packet rate:", actual_rate)
    print("Timing overruns:", overrun_count)
