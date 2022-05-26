# Simple game on AVR

## Description

This project is a simple game on the ATtiny24A microcontroller similar to the [simon game](<https://en.wikipedia.org/wiki/Simon_(game)>). A CR2025 lithium battery can be used for power. The board consumes about 6 uA in sleep mode and about 12mA at the moment the buzzer beeps and the LED lights up. The reset button must be pressed to wake the controller from sleep mode. The project schematic is shown [here](./schematic/attiny24a_memory-led-game.pdf). The wiring diagram for the NCP1402 chip was taken from the [datasheet](https://pdf1.alldatasheet.com/datasheet-pdf/view/174963/ONSEMI/NCP1402.html). It is appropriate to put tantalum capacitors C1 and C2.

## General info

- Assembler: avrasm2 2.2.7
- Clock frequency: Internal 8MHz with CKDIV8 fuse
- Fuses: lfuse: 0x42, hfuse: 0xDF, efuse: 0xFF, lock:0xFF
