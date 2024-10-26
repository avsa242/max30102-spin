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
* 1 extra core/cog for the PASM I2C engine (none if the bytecode-based engine is used)
* `sensor.temp.common.spinh` (provided by the spin-standard-library)

P2/SPIN2:
* p2-spin-standard-library
* `sensor.temp.common.spin2h` (provided by the p2-spin-standard-library)


## Compiler Compatibility

| Processor | Language | Compiler               | Backend      | Status                |
|-----------|----------|------------------------|--------------|-----------------------|
| P1        | SPIN1    | FlexSpin (6.9.4)       | Bytecode     | OK                    |
| P1        | SPIN1    | FlexSpin (6.9.4)       | Native/PASM  | OK                    |
| P2        | SPIN2    | FlexSpin (6.9.4)       | NuCode       | Untested              |
| P2        | SPIN2    | FlexSpin (6.9.4)       | Native/PASM2 | OK                    |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Limitations

* Doesn't calculate HR or SpO2

