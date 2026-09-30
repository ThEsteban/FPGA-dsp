from machine import ADC, Pin, SPI
import gc
import time


SAMPLE_RATE_HZ = 8_000
SAMPLE_PERIOD_US = 1_000_000 // SAMPLE_RATE_HZ  # 125 us

# Pico 2 SPI0 pins
SPI_SCK_PIN = 18       # Physical pin 24
SPI_MOSI_PIN = 19      # Physical pin 25
SPI_MISO_PIN = 16      # Not physically connected
SPI_CS_PIN = 17        # Physical pin 22

# Pico 2 ADC0
ADC_PIN = 26           # Physical pin 31

# Upper four bits of every transmitted word.
FRAME_TAG = 0xA000


# Hardware initialization


adc = ADC(Pin(ADC_PIN))

cs_n = Pin(SPI_CS_PIN, Pin.OUT, value=1)

spi = SPI(
    0,
    baudrate=1_000_000,
    polarity=0,
    phase=0,
    bits=8,
    firstbit=SPI.MSB,
    sck=Pin(SPI_SCK_PIN),
    mosi=Pin(SPI_MOSI_PIN),
    miso=Pin(SPI_MISO_PIN)
)

# Reuse the same buffer for every sample.
tx_buffer = bytearray(2)

sample_count = 0
overrun_count = 0

gc.collect()
gc.disable()

print("Continuous ADC streaming started")
print("ADC0: GP26")
print("Rate: {} samples/second".format(SAMPLE_RATE_HZ))
print("Press Ctrl+C to stop")

next_sample_time = time.ticks_us()

try:
    while True:
        # -------------------------------------------------
        # Wait for the next 125 us sampling deadline
        # -------------------------------------------------

        while time.ticks_diff(next_sample_time, time.ticks_us()) > 0:
            pass

        # Schedule the following sample relative to this deadline.
        next_sample_time = time.ticks_add(
            next_sample_time,
            SAMPLE_PERIOD_US
        )

        sample_12 = adc.read_u16() >> 4

        # Packet format: 0xA000 | 12-bit sample
        transmitted_word = FRAME_TAG | sample_12

        tx_buffer[0] = (transmitted_word >> 8) & 0xFF
        tx_buffer[1] = transmitted_word & 0xFF

        cs_n.value(0)
        spi.write(tx_buffer)
        cs_n.value(1)

        sample_count += 1

        # Detect missed sampling deadlines

        if time.ticks_diff(time.ticks_us(), next_sample_time) >= 0:
            overrun_count += 1

            # Restart timing from the current time rather than trying
            # to send several late samples back-to-back.
            next_sample_time = time.ticks_add(
                time.ticks_us(),
                SAMPLE_PERIOD_US
            )

except KeyboardInterrupt:
    print("\nStreaming stopped")

finally:
    cs_n.value(1)
    spi.deinit()
    gc.enable()

    print("Samples sent:", sample_count)
    print("Timing overruns:", overrun_count)