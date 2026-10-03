Debugging

1- send signal through uart to make sure there’s no rotation. PASS - uart good. 
 
2-send signal into spi receiver, with different  sclk speeds up to 1mhz , 230400 baud, changing the phase. PASS - spi receiver good 

REmaining likely causes
SCK ringing or threshold crossings creating extra edges.
Weak grounding could cause rising edge to be a wave crossing threshold several times. It happening on sck would explain the rotated words and missing words, module starting in wrong position or not perceiving 16 usable edges before CS ends. 
Test: 47 ohm resistor between sck and fpga input, FAILED: bit rotations 
common incorrect words: 0x0035:1071, 0x400D:444, 0x5003:150
total= 7788.7/s  correct= 6066.1/s  tagged= 6066.1/s  incorrect= 1722.6/s  missing= +211.3/s  correct
= 77.9%
Metastability from asynchronous SCK sampling.
Spi_rx currently synchronizes with two flip flops over two fpga clock cycles. If spi clk changes at same time as fpga clk then, unpredictable where input will go and cause edges to be misinterpreted. 
Test: no point in testing, it’d be very rare with a two clock synchonization. Not 1/ 7error rate. change my spi receiver architecture, my implementation sucked
Also the fact that the error shows a larger distribution around 2 shifts from xa801, this is an overall clock synchronization problem. Idk why I didn’t think of this earlier. 
Test: implemented toggle handshake syncing but this made it way worse. Bits are getting rotated a lot more. Percent correct is less than 15 percent on average. 
3. Oscilloscope ddn’t show any ringing, ran explicitly fpga clearing commands, put everything back to original state. Now it works fully. 

Last issue: changed the pins I was using, after looking closely at the schematic and seeing that pins 86 76 were directly wired to usb debugger bl616. Idk how I didn't see this before. After rewire and reflash with new constraints, fpga fully stopped sending anything through uart to the pc. after 



