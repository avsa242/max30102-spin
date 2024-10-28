{
----------------------------------------------------------------------------------------------------
    Filename:       sensor.bio.pulse-ox.max30102.spin
    Description:    Driver for the MAX30102 pulse-oximeter/heart-rate sensor
    Author:         Jesse Burt
    Started:        Apr 2, 2020
    Updated:        Oct 26, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

#include "sensor.temp.common.spinh"             ' use code common to temperature sensor drivers


CON

    { default I/O settings; these can be overridden in the parent object }
    SCL             = 28
    SDA             = 29
    I2C_FREQ        = 100_000
    I2C_ADDR        = 0                         ' unsupported by device


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


    SLAVE_WR        = core.SLAVE_ADDR
    SLAVE_RD        = core.SLAVE_ADDR|1
    I2C_MAX_FREQ    = core.I2C_MAX_FREQ


VAR

    long _ir_sample, _red_sample


OBJ

#ifdef MAX30102_I2C_BC
    i2c:    "com.i2c.nocog"                     ' I2C engine (bytecode/cogless)
#else
    i2c:    "com.i2c"                           ' I2C engine (PASM/1 extra cog)
#endif
    core:   "core.con.max30102"                 ' HW-specific constants
    time:   "time"                              ' timekeeping methods


PUB null()
' This is not a top-level object


PUB start(): status
' Start using default I/O settings
    return startx(SCL, SDA, I2C_FREQ)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start the driver with custom I/O settings
'   SCL_PIN:    I2C clock, 0..31
'   SDA_PIN:    I2C data, 0..31
'   I2C_HZ:     I2C clock speed (max official specification is 400_000 but is unenforced)
'   Returns:
'       cog ID+1 of I2C engine on success (= calling cog ID+1, if the bytecode I2C engine is used)
'       0 on failure
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) )
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core.T_POR)
            if ( dev_id() == core.DEVID_RESP )
                reset()
                return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()


PUB defaults()
' Factory default settings
    reset()


PUB preset_pulse()
' Preset settings for pulse/HR measurement
    reset()
    powered(TRUE)
    opmode(HR)
    'XXX fill in


PUB preset_oxysat()
' Preset settings for oxygen saturation/SpO2 measurement (includes HR)
    reset()
    powered(TRUE)
    adc_res(15)
    opmode(SPO2)
    spo2_scale(8192)
    spo2_sample_rate(1600)
    sample_averages(32)
    int1_mask(%010)


PUB adc_res(sres=-2): c
' Set sensor ADC resolution, in bits
'   Valid values: *15, 16, 17, 18
'   Any other value polls the chip and returns the current setting
    c := readreg(core.SPO2CFG)
    case sres
        15, 16, 17, 18:
            sres := ( (c & core.LED_PW_MASK) | lookdownz(sres: 15, 16, 17, 18) )
            writereg(core.SPO2CFG, sres)
        other:
            return lookupz(c & core.LED_PW_BITS: 15, 16, 17, 18)


PUB dev_id(): id
' Read device identification
'   Returns: $15
    id := readreg(core.REVID, 2)
    return id.byte[1]


PUB fifo_data_overrun(): f
' Flag indicating FIFO data has overrun
'   Returns: TRUE (-1) or FALSE (0)
    return ( fifo_samples_lost() <> 0 )


PUB fifo_full(): f
' Flag indicating FIFO is full
'   Returns: TRUE (-1) if full, FALSE otherwise
    return ( ( (interrupt1() >> 2) & 1) == 1)


PUB fifo_mode(mode=-2): c
' Set FIFO operating mode
'   Valid values:
'      *FIFO (0): If FIFO becomes completely filled, it won't be updated
'           until new data is read
'       STREAM (1): If FIFO becomes completely filled, new data will
'           overwrite old data (oldest data first)
    c := readreg(core.FIFOCFG)
    case mode
        FIFO, STREAM:
            mode := ( (c & core.FIFO_RLOV_EN_MASK) | (mode << core.FIFO_RLOV_EN) )
            writereg(core.FIFOCFG, mode)
        other:
            return ((c >> core.FIFO_RLOV_EN) & 1)


PUB fifo_overflow_ctr(val=-2): c
' Set FIFO overflow counter
'   val: overflow threshold
'   Returns:
'       current setting, if val is invalid
    case val
        0..31:
            writereg(core.OVERFL_CNT, val)
        other:
            return readreg(core.OVERFL_CNT)


PUB fifo_rd_ptr(rd_loc=-2): c
' Set FIFO read pointer
'   rd_loc: address within FIFO to set read pointer to
'   Returns:
'       current setting, if rd_loc is invalid
    case rd_loc
        0..31:
            writereg(core.FIFO_RDPTR, rd_loc)
        other:
            return readreg(core.FIFO_RDPTR)


PUB fifo_read(ptr_data) | tmp[2]
' Read PPG data from the FIFO
    tmp[0] := tmp[1] := 0
    i2c.start()
    i2c.write(SLAVE_WR)
    i2c.write(core.FIFODATA)
    i2c.start()
    i2c.write(SLAVE_RD)
    i2c.rdblock_lsbf(@tmp, 6, i2c.NAK)
    i2c.stop()

    _ir_sample := (tmp.byte[0] << 16 | tmp.byte[1] << 8 | tmp.byte[2]) & $3FFFF
    _red_sample := (tmp.byte[3] << 16 | tmp.byte[4] << 8 | tmp.byte[5]) & $3FFFF
    long[ptr_data][0] := _ir_sample
    long[ptr_data][1] := _red_sample


PUB fifo_samples_lost(): n
' Number of FIFO samples lost
'   Returns: 0..31
    return readreg(core.OVERFL_CNT)


PUB fifo_clr_overflow() | tmp 'xxx tentatively named
' Clear FIFO overflow flag
    writereg(core.OVERFL_CNT, 0)


PUB fifo_thresh(level=-2): c
' Set number of unread level in FIFO required to assert an interrupt
'   Valid values: 17..*32
'   Any other value polls the chip and returns the current setting
    c := readreg(core.FIFOCFG)
    case level
        17..32:
            level := ( (c & core.FIFO_A_FULL_MASK) | (32-level) )
            writereg(core.FIFOCFG, level)
        other:
            return (c & core.FIFO_A_FULL_BITS)


PUB fifo_unread_samples(): n | rd_ptr, wr_ptr
' Number of undread samples in FIFO
'   Returns: Integer
    rd_ptr := wr_ptr := 0
    wr_ptr := readreg(core.FIFO_WRPTR)
    rd_ptr := readreg(core.FIFO_RDPTR)

    return ( ||( 16 + wr_ptr - rd_ptr ) // 16 )


PUB fifo_wr_ptr(wr_loc=-2): c
' Set the FIFO write pointer
'   wr_loc: address within the FIFO to set the write pointer
'   Returns:
'       current setting, if wr_loc is invalid
    case wr_loc
        0..31:
            writereg(core.FIFO_WRPTR, wr_loc)
        other:
            return readreg(core.FIFO_WRPTR)


PUB interrupt1(): s
' Get interrupt 1 status
'   Bits 210
'       2: FIFO interrupt level reached (set using fifo_thresh() )
'       1: New data sample ready
'       0: Ambient light cancellation overflow
'           (ambient light is affecting reading)
    return readreg(core.INTSTATUS1, 2) >> core.ALC_OVF


PUB interrupt2(): s
' Get interrupt 2 status
'   1: Die temperature measurement ready
    return readreg(core.INTSTATUS2, 2)


PUB int1_mask(mask=-2): c
' Set interrupt 1 mask
'   Bits 210
'       2: FIFO interrupt level reached (set using fifo_thresh()
'       1: New data sample ready
'       0: Ambient light cancellation overflow
'           (ambient light is affecting reading)
'       Default: %000
'   Any other value polls the chip and returns the current setting
    case mask
        %000..%111:
            writereg(core.INT_EN1, (mask << core.ALC_OVF) )
        other:
            return readreg(core.INT_EN1) >> core.ALC_OVF


PUB int2_mask(mask=-2): c
' Set interrupt 2 mask
'   Valid values:
'       %00: Disabled
'       %10: Die temperature ready interrupt enabled
'       Default: %00
'   Any other value polls the chip and returns the current setting
    case mask
        %00, %10:
            writereg(core.INT_EN2, (mask << core.DIE_TEMP_RDY_EN) )
        other:
            return readreg(core.INT_EN2) >> core.DIE_TEMP_RDY_EN


PUB ir_led_current(curr=-2): c
' Set IR LED current limit, in microAmperes
'   Valid values: 0..51000 (default: 0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Per the datasheet, actual measured LED current for each part can
'       vary widely due to trimming methodology
    case curr
        0..51_000:
            curr /= 200
            writereg(core.LED2PA, curr)
        other:
            return ( readreg(core.LED2PA) * 200 )


PUB last_ir(): s
' Return most recent IR sample data
    return _ir_sample


PUB last_red(): s
' Return most recent RED sample data
    return _red_sample


PUB pilot_led_current(curr=-2): c
' Set Pilot LED current limit, in microAmperes
'   Valid values: 0..51000 (default: 0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Per the datasheet, actual measured LED current for each part can
'       vary widely due to trimming methodology
    case curr
        0..51_000:
            writereg(core.PILOT_PA, (curr / 200) )
        other:
            return ( readreg(core.PILOT_PA) * 200 )


PUB ppg_data_rdy(): f
' Flag indicating an unread PPG data sample is ready
'   Returns: TRUE (-1) if sample ready, FALSE otherwise
    return ( (interrupt1() >> 1) & 1) == 1


PUB red_led_current(curr=-2): c
' Set Red LED current limit, in microAmperes
'   Valid values: 0..51000 (default: 0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Per the datasheet, actual measured LED current for each part can
'       vary widely due to trimming methodology
    case curr
        0..51_000:
            writereg(core.LED1PA, (curr / 200) )
        other:
            return ( readreg(core.LED1PA) * 200 )


PUB opmode(mode=-2): c
' Set operation mode
'   Valid values:
'       HR (2): Heart-rate mode
'       SPO2 (3): SpO2 mode
'       MULTI_LED (7): TBD
'   Any other value polls the chip and returns the current setting
    c := readreg(core.MODECFG)
    case mode
        HR, SPO2, MULTI_LED:
            writereg(core.MODECFG, ( (c & core.MODE_MASK) | mode) )
        other:
            return (c & core.MODE_BITS)


PUB powered(state=-2): c
' Enable sensor power
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: When powered down, all settings are retained by the sensor,
'       and all interrupts are cleared.
    c := readreg(core.MODECFG)
    case ||(state)
        0, 1:
            state := (||(state) ^ 1) << core.SHDN
            writereg(core.MODECFG, ( (c & core.SHDN_MASK) | state) )
        other:
            return ( ( (c >> core.SHDN) & 1) == 1)


PUB reset()
' Perform soft-reset
    writereg(core.MODECFG, (1 << core.RESET) )


PUB sample_averages(nr_samples=-2): c
' Set averaging used per FIFO sample (number of samples)
'   Valid values: *1, 2, 4, 8, 16, 32
'   Any other value polls the chip and returns the current setting
'   NOTE: A setting of 1 effectively disables averging
    c := readreg(core.FIFOCFG)
    case nr_samples
        1, 2, 4, 8, 16, 32:
            nr_samples := lookdownz(nr_samples: 1, 2, 4, 8, 16, 32) << core.SMP_AVE
            writereg(core.FIFOCFG, ( (c & core.SMP_AVE_MASK) | nr_samples) )
        other:
            c := ( (c >> core.SMP_AVE) & core.SMP_AVE_BITS )
            return lookupz(c: 1, 2, 4, 8, 16, 32, 32, 32)


PUB spO2_sample_rate(rate=-2): c
' Set SpO2 sensor sample rate, in Hz
'   Valid values: *50, 100, 200, 400, 800, 1000, 1600, 3200
'   Any other value polls the chip and returns the current setting
    c := readreg(core.SPO2CFG)
    case rate
        50, 100, 200, 400, 800, 1000, 1600, 3200:
            rate := lookdownz(rate: 50, 100, 200, 400, 800, 1000, 1600, 3200) << core.SPO2_SR
            writereg(core.SPO2CFG, ( (c & core.SPO2_SR_MASK) | rate) )
        other:
            c := ( (c >> core.SPO2_SR) & core.SPO2_SR_BITS )
            return lookupz(c: 50, 100, 200, 400, 800, 1000, 1600, 3200)


PUB spO2_scale(range=-2): c
' Set SpO2 sensor full-scale range, in nanoAmperes
'   Valid values: *2048, 4096, 8192, 16384
'   Any other value polls the chip and returns the current setting
    c := readreg(core.SPO2CFG)
    case range
        2048, 4096, 8192, 16384:
            range := lookdownz(range: 2048, 4096, 8192, 16384) << core.SPO2_ADC_RGE
            writereg(core.SPO2CFG, ( (c & core.SPO2_ADC_RGE_MASK) | range) )
        other:
            c := ((c >> core.SPO2_ADC_RGE) & core.SPO2_ADC_RGE_BITS)
            return lookupz(c: 2048, 4096, 8192, 16384)


PUB temp_data(): t
' Read temperature ADC data
'   Returns: s12
    writereg(core.DIETEMPCFG, 1)                ' Trigger a measurement
    return readreg(core.DIETEMP_INT, 2)


PUB temp_word2deg(temp_adc): t | int, fract
' Convert temperature ADC word to temperature
'   Returns: temperature, in hundredths of a degree, in chosen scale
'   bits 11..4: integer (LSB = 1C), bits 3..0: fractional (LSB = 0.0625C)
    int := ~temp_adc.byte[0]                    ' extend sign
    fract := temp_adc.byte[1]
    int *= 1_0000                               ' Scale up to
    fract *= 0_0625                             '   preserve precision
    t := (int + fract) / 100
    case _temp_scale
        C:
            return t
        F:
            return ((t * 9_00) / 5_00) + 32_00
        other:
            return FALSE


PRI readreg(reg_nr, nr_bytes=1): v | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register #
        $00..$0A, $0C, $0D, $11, $12, $1F..$21, $FE, $FF:
            v := 0
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start()
            i2c.write(SLAVE_RD)
            i2c.rdblock_lsbf(@v, nr_bytes, i2c.NAK)
            i2c.stop()
        other:
            return


PRI writereg(reg_nr, val, nr_bytes=1) | cmd_pkt, tmp
' Write nr_bytes to the device from ptr_buff
    case reg_nr                                 ' validate register #
        $02..$0D, $11, $12, $21:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wrblock_lsbf(@val, nr_bytes)
            i2c.stop()
        other:
            return


DAT
{
Copyright 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

