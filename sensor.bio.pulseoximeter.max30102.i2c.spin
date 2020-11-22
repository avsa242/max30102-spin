{
    --------------------------------------------
    Filename: sensor.bio.pulseoximeter.max30102.i2c.spin
    Author: Jesse Burt
    Description: Driver for the MAX30102 pulse-oximeter/heart-rate sensor
    Copyright (c) 2020
    Started Apr 02, 2020
    Updated Nov 22, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR            = core#SLAVE_ADDR
    SLAVE_RD            = core#SLAVE_ADDR|1

    DEF_SCL             = 28
    DEF_SDA             = 29
    DEF_HZ              = 100_000
    I2C_MAX_FREQ        = core#I2C_MAX_FREQ

' Operating modes
    HR                  = %010
    SPO2                = %011
    MULTI_LED           = %111

VAR

    long _ir_sample, _red_sample

OBJ

    i2c : "com.i2c"
    core: "core.con.max30102"
    time: "time"

PUB Null{}
'This is not a top-level object

PUB Start{}: okay
' Start using "standard" Propeller I2C pins, and 100kHz
    okay := startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): okay

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx(SCL_PIN, SDA_PIN, I2C_HZ)
                time.msleep(1)
                if i2c.present(SLAVE_WR)       ' check device bus presence
                    if deviceid{} >> 8 == core#PARTID_RESP
                        reset{}
                        powered(TRUE)
                        return okay

    return FALSE                                ' something above failed

PUB Stop{}
' Put any other housekeeping code here required/recommended by your device before shutting down
    i2c.terminate{}

PUB ADCRes(bits): curr_res
' Set sensor ADC resolution, in bits
'   Valid values: *15, 16, 17, 18
'   Any other value polls the chip and returns the current setting
    curr_res := $00
    readreg(core#SPO2CONFIG, 1, @curr_res)
    case bits
        15, 16, 17, 18:
            bits := lookdownz(bits: 15, 16, 17, 18) & core#BITS_LED_PW
        other:
            curr_res &= core#BITS_LED_PW
            return lookupz(curr_res: 15, 16, 17, 18)

    curr_res &= core#MASK_LED_PW
    curr_res := (curr_res | bits) & core#SPO2CONFIG_MASK
    writereg(core#SPO2CONFIG, 1, @curr_res)

PUB DataOverrun{}: flag
' Flag indicating data overrun
'   Returns: Number of FIFO samples overrun/lost (0..31)
    readreg(core#OVERFLOWCNT, 1, @flag)

PUB DeviceID{}: id
' Get device part number/ID
'   Returns: $15xx (xx = revision ID; can be $00..$FF)
    readreg(core#REVID, 2, @id)

PUB FIFOIntLevel(level): curr_lvl
' Set number of unread level in FIFO required to assert an interrupt
'   Valid values: 17..*32
'   Any other value polls the chip and returns the current setting
    curr_lvl := $00
    readreg(core#FIFOCONFIG, 1, @curr_lvl)
    case level
        17..32:
            level := 32-level
        other:
            curr_lvl &= core#BITS_FIFO_A_FULL

    level := ((curr_lvl & core#MASK_FIFO_A_FULL) | level) & core#FIFOCONFIG_MASK
    writereg(core#FIFOCONFIG, 1, @level)

PUB FIFORead(ptr_data) | tmp[2]
' Read PPG data from the FIFO
    readreg(core#FIFODATA, 6, @tmp)
    _ir_sample := (tmp.byte[0] << 16 | tmp.byte[1] << 8 | tmp.byte[2]) & $3FFFF
    _red_sample := (tmp.byte[3] << 16 | tmp.byte[4] << 8 | tmp.byte[5]) & $3FFFF
    long[ptr_data][0] := _ir_sample
    long[ptr_data][1] := _red_sample

PUB FIFORollover(state): curr_state
' Enable FIFO data rollover
'   Valid values:
'       TRUE (-1 or 1): If FIFO becomes completely filled, new data will overwrite old data (oldest data first)
'      *FALSE (0): If FIFO becomes completely filled, it won't be updated until new data is read
    curr_state := $00
    readreg(core#FIFOCONFIG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#FLD_FIFO_ROLLOVER_EN
        other:
            return ((curr_state >> core#FLD_FIFO_ROLLOVER_EN) & %1) == 1

    state := ((curr_state & core#MASK_FIFO_ROLLOVER_EN) | state) & core#FIFOCONFIG_MASK
    writereg(core#FIFOCONFIG, 1, @state)

PUB FIFOFull{}: flag
' Flag indicating FIFO is full
'   Returns: TRUE (-1) if full, FALSE otherwise
    return ((interrupt1{} >> 2) & 1) == 1

PUB FIFOUnreadSamples{}: nr_samples | rd_ptr, wr_ptr
' Number of undread samples in FIFO
'   Returns: Integer
    readreg(core#FIFOWRITEPTR, 1, @wr_ptr)
    readreg(core#FIFOREADPTR, 1, @rd_ptr)

    return (||( 16 + wr_ptr - rd_ptr ) // 16)

PUB Interrupt1{}: status
' Get interrupt 1 status
'   Bits 210
'       2: FIFO interrupt level reached (set using FIFOIntLevel()
'       1: New data sample ready
'       0: Ambient light cancellation overflow (ambient light is affecting reading)
    readreg(core#INTSTATUS1, 2, @status)
    status >>= core#FLD_ALC_OVF

PUB Interrupt2{}: status
' Get interrupt 2 status
'   1: Die temperature measurement ready
    readreg(core#INTSTATUS2, 2, @status)

PUB Int1Mask(mask): curr_mask
' Set interrupt 1 mask
'   Bits 210
'       2: FIFO interrupt level reached (set using FIFOIntLevel()
'       1: New data sample ready
'       0: Ambient light cancellation overflow (ambient light is affecting reading)
'       Default: %000
'   Any other value polls the chip and returns the current setting
    readreg(core#INTENABLE1, 1, @curr_mask)
    case mask
        %000..%111:
            mask <<= core#FLD_ALC_OVF
        other:
            return curr_mask >> core#FLD_ALC_OVF

    writereg(core#INTENABLE1, 1, @mask)

PUB Int2Mask(mask): curr_mask
' Set interrupt 2 mask
'   Valid values:
'       %00: Disabled
'       %10: Die temperature ready interrupt enabled
'       Default: %00
'   Any other value polls the chip and returns the current setting
    readreg(core#INTENABLE2, 1, @curr_mask)
    case mask
        %00, %10:
            mask <<= core#FLD_DIE_TEMP_RDY_EN
        other:
            return curr_mask >> core#FLD_DIE_TEMP_RDY_EN

    writereg(core#INTENABLE2, 1, @mask)

PUB IRLEDCurrent(curr) | curr_set
' Set IR LED current limit, in microAmperes
'   Valid values: 0..51000 (default: 0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Per the datasheet, actual measured LED current for each part can vary widely due to trimming methodology
    curr_set := $00
    readreg(core#LED2PA, 1, @curr_set)
    case curr
        0..51_000:
            curr /= 200
        other:
            return curr_set * 200

    writereg(core#LED2PA, 1, @curr)

PUB LastIR{}: ir_sam
' Return most recent IR sample data
    return _ir_sample

PUB LastRed{}: red_sam
' Return most recent RED sample data
    return _red_sample

PUB PPGDataReady{}: flag
' Flag indicating an unread PPG data sample is ready
'   Returns: TRUE (-1) if sample ready, FALSE otherwise
    return ((Interrupt1 >> 1) & 1) == 1

PUB RedLEDCurrent(curr) | curr_set
' Set Red LED current limit, in microAmperes
'   Valid values: 0..51000 (default: 0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Per the datasheet, actual measured LED current for each part can vary widely due to trimming methodology
    curr_set := $00
    readreg(core#LED1PA, 1, @curr_set)
    case curr
        0..51_000:
            curr /= 200
        other:
            return curr_set * 200

    writereg(core#LED1PA, 1, @curr)

PUB OpMode(mode): curr_mode
' Set operation mode
'   Valid values:
'       HR (2): Heart-rate mode
'       SPO2 (3): SpO2 mode
'       MULTI_LED (7): TBD
'   Any other value polls the chip and returns the current setting
    curr_mode := $00
    readreg(core#MODECONFIG, 1, @curr_mode)
    case mode
        HR, SPO2, MULTI_LED:
        other:
            return curr_mode & core#BITS_MODE

    mode := ((curr_mode & core#MASK_MODE) | mode) & core#MODECONFIG_MASK
    writereg(core#MODECONFIG, 1, @mode)

PUB Powered(state) | curr_state
' Enable sensor power
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: When powered down, all settings are retained by the sensor,
'       and all interrupts are cleared.
    curr_state := $00
    readreg(core#MODECONFIG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := (||(state) ^ 1) << core#FLD_SHDN
        other:
            return ((curr_state >> core#FLD_SHDN) & 1) == 1

    state := ((curr_state & core#MASK_SHDN) | state) & core#MODECONFIG_MASK
    writereg(core#MODECONFIG, 1, @state)

PUB Reset{} | tmp
' Perform soft-reset
    tmp := 1 << core#FLD_RESET
    writereg(core#MODECONFIG, 1, @tmp)

PUB SampleAverages(nr_samples) | curr_set
' Set averaging used per FIFO sample (number of samples)
'   Valid values: *1, 2, 4, 8, 16, 32
'   Any other value polls the chip and returns the current setting
'   NOTE: A setting of 1 effectively disables averging
    curr_set := $00
    readreg(core#FIFOCONFIG, 1, @curr_set)
    case nr_samples
        1, 2, 4, 8, 16, 32:
            nr_samples := lookdownz(nr_samples: 1, 2, 4, 8, 16, 32) << core#FLD_SMP_AVE
        other:
            curr_set := (curr_set >> core#FLD_SMP_AVE) & core#BITS_SMP_AVE
            return lookupz(curr_set: 1, 2, 4, 8, 16, 32, 32, 32)

    nr_samples := ((curr_set & core#MASK_SMP_AVE) | nr_samples) & core#FIFOCONFIG_MASK
    writereg(core#FIFOCONFIG, 1, @nr_samples)

PUB SpO2SampleRate(rate): curr_rate
' Set SpO2 sensor sample rate, in rate
'   Valid values: *50, 100, 200, 400, 800, 1000, 1600, 3200
'   Any other value polls the chip and returns the current setting
    curr_rate := $00
    readreg(core#SPO2CONFIG, 1, @curr_rate)
    case rate
        50, 100, 200, 400, 800, 1000, 1600, 3200:
            rate := lookdownz(rate: 50, 100, 200, 400, 800, 1000, 1600, 3200) << core#FLD_SPO2_SR
        other:
            curr_rate := (curr_rate >> core#FLD_SPO2_SR) & core#BITS_SPO2_SR
            return lookupz(curr_rate: 50, 100, 200, 400, 800, 1000, 1600, 3200)

    rate := ((curr_rate & core#MASK_SPO2_SR) | rate) & core#SPO2CONFIG_MASK
    writereg(core#SPO2CONFIG, 1, @rate)

PUB SpO2Scale(range): curr_rng
' Set SpO2 sensor full-scale range, in nanoAmperes
'   Valid values: *2048, 4096, 8192, 16384
'   Any other value polls the chip and returns the current setting
    curr_rng := $00
    readreg(core#SPO2CONFIG, 1, @curr_rng)
    case range
        2048, 4096, 8192, 16384:
            range := lookdownz(range: 2048, 4096, 8192, 16384) << core#FLD_SPO2_ADC_RGE
        other:
            curr_rng := (curr_rng >> core#FLD_SPO2_ADC_RGE) & core#BITS_SPO2_ADC_RGE
            return lookupz(curr_rng: 2048, 4096, 8192, 16384)

    range := ((curr_rng & core#MASK_SPO2_ADC_RGE) | range) & core#SPO2CONFIG_MASK
    writereg(core#SPO2CONFIG, 1, @range)

PUB Temperature{}: temp | int, fract, tmp
' Read die temperature
'   Returns: Temperature in centi-degrees Celsius (signed)
    int := fract := 0
    tmp := %1
    writereg(core#DIETEMPCONFIG, 1, @tmp)                       ' Trigger a measurement

    readreg(core#DIETEMP_INT, 1, @int)                          ' LSB = 1C (signed 8b)
    readreg(core#DIETEMP_FRACT, 1, @fract)                      ' LSB = +0.0625C (always additive)

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
            i2c.start{}
            i2c.wr_block(@cmd_packet, 2)
            i2c.start{}
            i2c.write (SLAVE_RD)
            i2c.rd_block(buff_addr, nr_bytes, TRUE)
            i2c.stop{}
        other:
            return

PRI writeReg(reg, nr_bytes, buff_addr) | cmd_packet, tmp
'' Write num_bytes to the slave device from the address stored in buff_addr
    case reg                                                    'Basic register validation
        $02..$0D, $11, $12, $21:
            cmd_packet.byte[0] := SLAVE_WR
            cmd_packet.byte[1] := reg
            i2c.start{}
            i2c.wr_block(@cmd_packet, 2)
            repeat tmp from 0 to nr_bytes-1
                i2c.write(byte[buff_addr][tmp])
            i2c.stop{}
        other:
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
