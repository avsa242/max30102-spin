{
    --------------------------------------------
    Filename: sensor.bio.pulseoximeter.max30102.i2c.spin
    Author: Jesse Burt
    Description: Driver for the MAX30102 pulse-oximeter/heart-rate sensor
    Copyright (c) 2021
    Started Apr 02, 2020
    Updated Aug 15, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    I2C_MAX_FREQ    = core#I2C_MAX_FREQ

' Operating modes
    HR              = %010
    SPO2            = %011
    MULTI_LED       = %111

' FIFO operating modes
    FIFO            = 0
    STREAM          = 1

' Temperature scales
    C               = 0
    F               = 1

VAR

    long _ir_sample, _red_sample
    byte _temp_scale

OBJ

    i2c : "com.i2c"                             ' PASM I2C engine (~400kHz)
    core: "core.con.max30102"                   ' HW-specific constants
    time: "time"                                ' timekeeping methods

PUB Null{}
' This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins, and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom I/O pins and bus speed
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)
            if i2c.present(SLAVE_WR)       ' check device bus presence
                if deviceid{} == core#DEVID_RESP
                    reset{}
                    return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB Stop{}
' Stop I2C engine
    i2c.deinit{}

PUB Defaults{}
' Factory default settings
    reset{}

PUB Preset_Pulse{}
' Preset settings for pulse/HR measurement
    reset{}
    powered(TRUE)
    'XXX fill in

PUB Preset_OxySat{}
' Preset settings for oxygen saturation/SpO2 measurement (includes HR)
    reset{}
    powered(TRUE)
    adcres(15)
    opmode(SPO2)
    spo2scale(8192)
    spo2samplerate(1600)
    sampleaverages(32)
    int1mask(%010)

PUB ADCRes(sres): curr_res
' Set sensor ADC resolution, in bits
'   Valid values: *15, 16, 17, 18
'   Any other value polls the chip and returns the current setting
    curr_res := 0
    readreg(core#SPO2CFG, 1, @curr_res)
    case sres
        15, 16, 17, 18:
            sres := lookdownz(sres: 15, 16, 17, 18) & core#LED_PW_BITS
        other:
            curr_res &= core#LED_PW_BITS
            return lookupz(curr_res: 15, 16, 17, 18)

    sres := ((curr_res & core#LED_PW) | sres)
    writereg(core#SPO2CFG, 1, @sres)

PUB DeviceID{}: id
' Read device identification
'   Returns: $15
    readreg(core#REVID, 2, @id)
    return id.byte[1]

PUB FIFODataOverrun{}: flag
' Flag indicating FIFO data has overrun
'   Returns: TRUE (-1) or FALSE (0)
    return (fifosampleslost{} <> 0)

PUB FIFOFull{}: flag
' Flag indicating FIFO is full
'   Returns: TRUE (-1) if full, FALSE otherwise
    return (((interrupt1{} >> 2) & 1) == 1)

PUB FIFOMode(mode): curr_mode
' Set FIFO operating mode
'   Valid values:
'      *FIFO (0): If FIFO becomes completely filled, it won't be updated
'           until new data is read
'       STREAM (1): If FIFO becomes completely filled, new data will
'           overwrite old data (oldest data first)
    curr_mode := 0
    readreg(core#FIFOCFG, 1, @curr_mode)
    case mode
        FIFO, STREAM:
            mode <<= core#FIFO_RLOV_EN
        other:
            return ((curr_mode >> core#FIFO_RLOV_EN) & 1)

    mode := ((curr_mode & core#FIFO_RLOV_EN_MASK) | mode)
    writereg(core#FIFOCFG, 1, @mode)

PUB FIFORead(ptr_data) | tmp[2]
' Read PPG data from the FIFO
    readreg(core#FIFODATA, 6, @tmp)
    _ir_sample := (tmp.byte[0] << 16 | tmp.byte[1] << 8 | tmp.byte[2]) & $3FFFF
    _red_sample := (tmp.byte[3] << 16 | tmp.byte[4] << 8 | tmp.byte[5]) & $3FFFF
    long[ptr_data][0] := _ir_sample
    long[ptr_data][1] := _red_sample

PUB FIFOSamplesLost{}: nr_smp
' Number of FIFO samples lost
'   Returns: 0..31
    readreg(core#OVERFL_CNT, 1, @nr_smp)

PUB FIFOThreshold(level): curr_lvl
' Set number of unread level in FIFO required to assert an interrupt
'   Valid values: 17..*32
'   Any other value polls the chip and returns the current setting
    curr_lvl := 0
    readreg(core#FIFOCFG, 1, @curr_lvl)
    case level
        17..32:
            level := 32-level
        other:
            return (curr_lvl & core#FIFO_A_FULL_BITS)

    level := ((curr_lvl & core#FIFO_A_FULL) | level)
    writereg(core#FIFOCFG, 1, @level)

PUB FIFOUnreadSamples{}: nr_samples | rd_ptr, wr_ptr
' Number of undread samples in FIFO
'   Returns: Integer
    readreg(core#FIFO_WRPTR, 1, @wr_ptr)
    readreg(core#FIFO_RDPTR, 1, @rd_ptr)

    return (||( 16 + wr_ptr - rd_ptr ) // 16)

PUB Interrupt1{}: status
' Get interrupt 1 status
'   Bits 210
'       2: FIFO interrupt level reached (set using FIFOIntLevel()
'       1: New data sample ready
'       0: Ambient light cancellation overflow
'           (ambient light is affecting reading)
    readreg(core#INTSTATUS1, 2, @status)
    status >>= core#ALC_OVF

PUB Interrupt2{}: status
' Get interrupt 2 status
'   1: Die temperature measurement ready
    readreg(core#INTSTATUS2, 2, @status)

PUB Int1Mask(mask): curr_mask
' Set interrupt 1 mask
'   Bits 210
'       2: FIFO interrupt level reached (set using FIFOIntLevel()
'       1: New data sample ready
'       0: Ambient light cancellation overflow
'           (ambient light is affecting reading)
'       Default: %000
'   Any other value polls the chip and returns the current setting
    case mask
        %000..%111:
            mask <<= core#ALC_OVF
            writereg(core#INT_EN1, 1, @mask)
        other:
            curr_mask := 0
            readreg(core#INT_EN1, 1, @curr_mask)
            return curr_mask >> core#ALC_OVF

PUB Int2Mask(mask): curr_mask
' Set interrupt 2 mask
'   Valid values:
'       %00: Disabled
'       %10: Die temperature ready interrupt enabled
'       Default: %00
'   Any other value polls the chip and returns the current setting
    case mask
        %00, %10:
            mask <<= core#DIE_TEMP_RDY_EN
            writereg(core#INT_EN2, 1, @mask)
        other:
            curr_mask := 0
            readreg(core#INT_EN2, 1, @curr_mask)
            return curr_mask >> core#DIE_TEMP_RDY_EN

PUB IRLEDCurrent(curr) | curr_set
' Set IR LED current limit, in microAmperes
'   Valid values: 0..51000 (default: 0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Per the datasheet, actual measured LED current for each part can
'       vary widely due to trimming methodology
    case curr
        0..51_000:
            curr /= 200
            writereg(core#LED2PA, 1, @curr)
        other:
            curr_set := 0
            readreg(core#LED2PA, 1, @curr_set)
            return curr_set * 200

PUB LastIR{}: ir_sam
' Return most recent IR sample data
    return _ir_sample

PUB LastRed{}: red_sam
' Return most recent RED sample data
    return _red_sample

PUB PPGDataReady{}: flag
' Flag indicating an unread PPG data sample is ready
'   Returns: TRUE (-1) if sample ready, FALSE otherwise
    return ((interrupt1{} >> 1) & 1) == 1

PUB RedLEDCurrent(curr) | curr_set
' Set Red LED current limit, in microAmperes
'   Valid values: 0..51000 (default: 0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Per the datasheet, actual measured LED current for each part can
'       vary widely due to trimming methodology
    case curr
        0..51_000:
            curr /= 200
            writereg(core#LED1PA, 1, @curr)
        other:
            curr_set := 0
            readreg(core#LED1PA, 1, @curr_set)
            return curr_set * 200

PUB OpMode(mode): curr_mode
' Set operation mode
'   Valid values:
'       HR (2): Heart-rate mode
'       SPO2 (3): SpO2 mode
'       MULTI_LED (7): TBD
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#MODECFG, 1, @curr_mode)
    case mode
        HR, SPO2, MULTI_LED:
        other:
            return (curr_mode & core#MODE_BITS)

    mode := ((curr_mode & core#MODE_MASK) | mode)
    writereg(core#MODECFG, 1, @mode)

PUB Powered(state) | curr_state
' Enable sensor power
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: When powered down, all settings are retained by the sensor,
'       and all interrupts are cleared.
    curr_state := 0
    readreg(core#MODECFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := (||(state) ^ 1) << core#SHDN
        other:
            return (((curr_state >> core#SHDN) & 1) == 1)

    state := ((curr_state & core#SHDN_MASK) | state)
    writereg(core#MODECFG, 1, @state)

PUB Reset{} | tmp
' Perform soft-reset
    tmp := 1 << core#RESET
    writereg(core#MODECFG, 1, @tmp)

PUB SampleAverages(nr_samples) | curr_set
' Set averaging used per FIFO sample (number of samples)
'   Valid values: *1, 2, 4, 8, 16, 32
'   Any other value polls the chip and returns the current setting
'   NOTE: A setting of 1 effectively disables averging
    curr_set := 0
    readreg(core#FIFOCFG, 1, @curr_set)
    case nr_samples
        1, 2, 4, 8, 16, 32:
            nr_samples := lookdownz(nr_samples: 1, 2, 4, 8, 16, 32)
            nr_samples <<= core#SMP_AVE
        other:
            curr_set := (curr_set >> core#SMP_AVE) & core#SMP_AVE_BITS
            return lookupz(curr_set: 1, 2, 4, 8, 16, 32, 32, 32)

    nr_samples := ((curr_set & core#SMP_AVE_MASK) | nr_samples)
    writereg(core#FIFOCFG, 1, @nr_samples)

PUB SpO2SampleRate(rate): curr_rate
' Set SpO2 sensor sample rate, in Hz
'   Valid values: *50, 100, 200, 400, 800, 1000, 1600, 3200
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core#SPO2CFG, 1, @curr_rate)
    case rate
        50, 100, 200, 400, 800, 1000, 1600, 3200:
            rate := lookdownz(rate: 50, 100, 200, 400, 800, 1000, 1600, 3200)
            rate <<= core#SPO2_SR
        other:
            curr_rate := (curr_rate >> core#SPO2_SR) & core#SPO2_SR_BITS
            return lookupz(curr_rate: 50, 100, 200, 400, 800, 1000, 1600, 3200)

    rate := ((curr_rate & core#SPO2_SR_MASK) | rate)
    writereg(core#SPO2CFG, 1, @rate)

PUB SpO2Scale(range): curr_rng
' Set SpO2 sensor full-scale range, in nanoAmperes
'   Valid values: *2048, 4096, 8192, 16384
'   Any other value polls the chip and returns the current setting
    curr_rng := 0
    readreg(core#SPO2CFG, 1, @curr_rng)
    case range
        2048, 4096, 8192, 16384:
            range := lookdownz(range: 2048, 4096, 8192, 16384)
            range <<= core#SPO2_ADC_RGE
        other:
            curr_rng := ((curr_rng >> core#SPO2_ADC_RGE) & core#SPO2_ADC_RGE_BITS)
            return lookupz(curr_rng: 2048, 4096, 8192, 16384)

    range := ((curr_rng & core#SPO2_ADC_RGE_MASK) | range)
    writereg(core#SPO2CFG, 1, @range)

PUB TempData{}: temp_adc | tmp
' Read temperature ADC data
'   Returns: s12
    tmp := 1
    writereg(core#DIETEMPCFG, 1, @tmp)       ' Trigger a measurement

    temp_adc := 0
    readreg(core#DIETEMP_INT, 2, @temp_adc)

PUB Temperature{}: temp
' Current Temperature, in hundredths of a degree
'   Returns: Integer
'   (e.g., 2105 is equivalent to 21.05 deg C)
    return tempword2deg(tempdata{})

PUB TempScale(scale): curr_scale
' Set temperature scale used by Temperature method
'   Valid values:
'      *C (0): Celsius
'       F (1): Fahrenheit
'   Any other value returns the current setting
    case scale
        C, F:
            _temp_scale := scale
        other:
            return _temp_scale

PUB TempWord2Deg(temp_adc): temp | int, fract
' Convert temperature ADC word to temperature
'   Returns: temperature, in hundredths of a degree, in chosen scale
'   bits 11..4: integer (LSB = 1C), bits 3..0: fractional (LSB = 0.0625C)
    int := ~temp_adc.byte[0]                    ' extend sign
    fract := temp_adc.byte[1]
    int *= 1_0000                               ' Scale up to
    fract *= 0_0625                             '   preserve precision
    temp := (int + fract) / 100
    case _temp_scale
        C:
            return temp
        F:
            return ((temp * 9_00) / 5_00) + 32_00
        other:
            return FALSE

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_packet, tmp
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register #
        $00..$0A, $0C, $0D, $11, $12, $1F..$21, $FE, $FF:
            cmd_packet.byte[0] := SLAVE_WR
            cmd_packet.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_packet, 2)
            i2c.start{}
            i2c.write (SLAVE_RD)
            i2c.rdblock_lsbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
        other:
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_packet, tmp
' Write nr_bytes to the device from ptr_buff
    case reg_nr                                    ' validate register #
        $02..$0D, $11, $12, $21:
            cmd_packet.byte[0] := SLAVE_WR
            cmd_packet.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_packet, 2)
            i2c.wrblock_lsbf(ptr_buff, nr_bytes)
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
