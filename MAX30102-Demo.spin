{
    --------------------------------------------
    Filename: MAX30102-Demo.spin
    Author: Jesse Burt
    Description: Demo of the MAX30102 driver
    Copyright (c) 2020
    Started Apr 02, 2020
    Updated Apr 04, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

    SCL_PIN     = 28
    SDA_PIN     = 29
    I2C_HZ      = 400_000

    SER_RX      = 31
    SER_TX      = 30
    SER_BAUD    = 115_200
    LED         = cfg#LED1

OBJ

    cfg         : "core.con.boardcfg.parraldev"
    ser         : "com.serial.terminal.ansi"
    io          : "io"
    time        : "time"
    max30102    : "sensor.biometric.pulseoximeter.max30102.i2c"

VAR

    byte _ser_cog

PUB Main | tmp[2], samples

    Setup
    ser.position(0, 2)
    ser.hex(max30102.DeviceID, 8)
    max30102.OpMode(max30102#SPO2)
    max30102.IRLEDCurrent($24)
    max30102.RedLEDCurrent($24)

    repeat
        max30102.FIFORead(@tmp)

        ser.position(0, 5)
        ser.hex(max30102.LastIR, 8)
        ser.char(" ")
        ser.hex(max30102.LastRed, 8)

   FlashLED(LED, 100)

PUB Setup

    repeat until _ser_cog := ser.StartRXTX (SER_RX, SER_TX, 0, SER_BAUD)
    time.MSleep(30)
    ser.Clear
    ser.Str(string("Serial terminal started", ser#CR, ser#LF))
    if max30102.Startx(SCL_PIN, SDA_PIN, I2C_HZ)
        ser.Str(string("MAX30102 driver started", ser#CR, ser#LF))
    else
        ser.Str(string("MAX30102 driver failed to start - halting", ser#CR, ser#LF))
        max30102.Stop
        time.MSleep(5)
        ser.Stop
        FlashLED(LED, 500)

#include "lib.utility.spin"

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
