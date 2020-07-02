# max30102-spin
---------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the MAXIM MAX30102 Pulse Oximeter and Heart Rate sensor

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz
* Set ADC resolution
* Read various status flags: FIFO overrun, FIFO full, number of FIFO unread samples, interrupt status
* Enable interrupts: FIFO threshold, new data ready, ambient light cancellation overflow, die temperature data ready
* Set red and IR LED currents individually (0..51000uA)
* Set optional sample averaging
* Set sample rate
* Set full-scale range
* Read die temperature

## Requirements

P1/SPIN1:
* spin-standard-library
* 1 extra core/cog for the PASM I2C driver

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81)
* P2/SPIN2: FastSpin (tested with 4.2.3-beta)
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build
* Doesn't calculate HR or SpO2

## TODO

- [ ] Combine Interrupt1() and Interrupt2()
- [x] Port to SPIN2/P2
- [ ] Add methods to calculate HR and SpO2

