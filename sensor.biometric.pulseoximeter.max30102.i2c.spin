{
    --------------------------------------------
    Filename: sensor.biometric.pulseoximeter.max30102.i2c.spin
    Author: Jesse Burt
    Description: Drive for MAX30102 pulse-oximeter/heart-rate sensor
    Copyright (c) 2020
    Started Apr 02, 2020
    Updated Apr 04, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR          = core#SLAVE_ADDR
    SLAVE_RD          = core#SLAVE_ADDR|1

    DEF_SCL           = 28
    DEF_SDA           = 29
    DEF_HZ            = 400_000
    I2C_MAX_FREQ      = core#I2C_MAX_FREQ

' Operating modes
    HR                  = %010
    SPO2                = %011
    MULTI_LED           = %111

VAR

    long _ir_sample, _red_sample

OBJ

    i2c : "com.i2c"                                             'PASM I2C Driver
    core: "core.con.max30102.spin"                           'File containing your device's register set
    time: "time"                                                'Basic timing functions

PUB Null
''This is not a top-level object

PUB Start: okay                                                 'Default to "standard" Propeller I2C pins and 400kHz

    okay := Startx (DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): okay

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx (SCL_PIN, SDA_PIN, I2C_HZ)    'I2C Object Started?
                time.MSleep (1)
                if i2c.present (SLAVE_WR)                       'Response from device?
                    if DeviceID >> 8 == core#PARTID_RESP
                        return okay

    return FALSE                                                'If we got here, something went wrong

PUB Stop
' Put any other housekeeping code here required/recommended by your device before shutting down
    i2c.terminate

PUB DeviceID
' Get device part number/ID
'   Returns: $15xx (xx = revision ID; can be $00..$FF)
    readReg(core#REVID, 2, @result)

PUB FIFORead(ptr_data) | tmp[2]

    readReg(core#FIFODATA, 6, @tmp)
    _ir_sample := tmp.byte[0] << 16 | tmp.byte[1] << 8 | tmp.byte[2]
    _red_sample := tmp.byte[3] << 16 | tmp.byte[4] << 8 | tmp.byte[5]
    long[ptr_data][0] := _ir_sample
    long[ptr_data][1] := _red_sample

PUB FIFOUnreadSamples | rd_ptr, wr_ptr

    readReg(core#FIFOWRITEPTR, 1, @wr_ptr)
    readReg(core#FIFOREADPTR, 1, @rd_ptr)

    return (||( 16 + wr_ptr - rd_ptr ) // 16)

PUB Interrupt

    readReg(core#INTSTATUS1, 2, @result)

PUB IRLEDCurrent(uA) | tmp

    writeReg(core#LED2PA, 1, @uA)

PUB LastIR

    return _ir_sample

PUB LastRed

    return _red_sample

PUB RedLEDCurrent(uA) | tmp

    writeReg(core#LED1PA, 1, @uA)

PUB OpMode(mode) | tmp

    tmp := $00
    readReg(core#MODECONFIG, 1, @tmp)
    case mode
        HR, SPO2, MULTI_LED:
        OTHER:
            return tmp & core#BITS_MODE

    tmp &= core#MASK_MODE
    tmp := (tmp | mode) & core#MODECONFIG_MASK
    writeReg(core#MODECONFIG, 1, @tmp)

PUB Temperature | int, fract, tmp
' Read die temperature
'   Returns: Temperature in centi-degrees Celsius (signed)
    int := fract := 0
    tmp := %1
    writeReg(core#DIETEMPCONFIG, 1, @tmp)                       ' Trigger a measurement

    readReg(core#DIETEMP_INT, 1, @int)                          ' LSB = 1C (signed 8b)
    readReg(core#DIETEMP_FRACT, 1, @fract)                      ' LSB = +0.0625C (always additive)

    ~int
    int *= 1_0000                                               ' Scale up to
    fract *= 0_0625                                             '   preserve precision

    return (int + fract) / 100                                  ' Scale back down to centidegrees

PRI readReg(reg, nr_bytes, buff_addr) | cmd_packet, tmp
'' Read num_bytes from the slave device into the address stored in buff_addr
    case reg                                                    'Basic register validation
        $00..$0A, $0C, $0D, $11, $12, $1F..$21, $FE, $FF:
            cmd_packet.byte[0] := SLAVE_WR
            cmd_packet.byte[1] := reg
            i2c.start
            i2c.wr_block (@cmd_packet, 2)
            i2c.start
            i2c.write (SLAVE_RD)
            i2c.rd_block (buff_addr, nr_bytes, TRUE)
            i2c.stop
        OTHER:
            return

PRI writeReg(reg, nr_bytes, buff_addr) | cmd_packet, tmp
'' Write num_bytes to the slave device from the address stored in buff_addr
    case reg                                                    'Basic register validation
        $02..$0D, $11, $12, $21:
            cmd_packet.byte[0] := SLAVE_WR
            cmd_packet.byte[1] := reg
            i2c.start
            i2c.wr_block (@cmd_packet, 2)
            repeat tmp from 0 to nr_bytes-1
                i2c.write (byte[buff_addr][tmp])
            i2c.stop
        OTHER:
            return


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
