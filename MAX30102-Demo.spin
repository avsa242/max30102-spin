{
    --------------------------------------------
    Filename: MAX30102-Demo.spin
    Author: Jesse Burt
    Description: Preliminary demo of the MAX30102 driver
        Displays an auto-adjusting chart of
        SpO2 and HR data (raw ADC counts only)
    Copyright (c) 2020
    Started Apr 02, 2020
    Updated Jun 30, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-modifiable constants
    SCL_PIN     = 0
    SDA_PIN     = 1
    I2C_HZ      = 400_000

    SER_RX      = cfg#SER_RX_DEF
    SER_TX      = cfg#SER_TX_DEF
    SER_BAUD    = 115_200
    LED         = cfg#LED1
    VGA_PINGROUP= 2                                         ' 0, 1, 2, 3 (VGA pin base = pingroup * 8)
' --

    WIDTH       = vga#DISP_WIDTH
    HEIGHT      = vga#DISP_HEIGHT
    BPL         = WIDTH * vga#BYTESPERPX
    BUFFSZ      = (WIDTH * HEIGHT)
    XMAX        = WIDTH - 1
    YMAX        = HEIGHT - 1

    PRESCALE    = 10

OBJ

    cfg         : "core.con.boardcfg.quickstart-hib"
    ser         : "com.serial.terminal.ansi"
    io          : "io"
    time        : "time"
    max30102    : "sensor.bio.pulseoximeter.max30102.i2c"
    vga         : "display.vga.bitmap.160x120"
    fnt         : "font.5x8"

VAR

    long _settings_changed
    long _i_red, _i_ir, _ir_offset, _red_offset, _div
    long _red_data, _ir_data, _last_red, _last_ir, _die_temp
    long _key_stack[50], _acq_stack[50]
    byte _max30102_cog
    byte _framebuff[BUFFSZ]

PUB Main | x

    Setup

    vga.fgcolor(vga#MAX_COLOR)

    repeat
        repeat x from 0 to XMAX
            vga.line(x-1, YMAX-_last_ir, x, YMAX-_ir_data, vga#MAX_COLOR)
            vga.line(x-1, YMAX-_last_red, x, YMAX-_red_data, %%300)
'            vga.plot(x, _ir_data #> 0, vga#MAX_COLOR)
'            vga.plot(x, _red_data #> 0, %%300)
            if _settings_changed
                displaysettings
            time.msleep(10)
            vga.box(x+1, 0, x+5, YMAX, 0, TRUE)

' Scroll View
    repeat
        vga.waitvsync
        vga.plot(XMAX-2, _ir_data #> 0, vga#MAX_COLOR)
        vga.plot(XMAX-2, _red_data #> 0, %%300)
        vga.scrollleft(0, 0, XMAX, YMAX)
        if _settings_changed
            displaysettings

   flashled(LED, 100)

PUB DisplaySettings

    ser.position(0, 7)
    ser.printf(string("IR: %d, Red: %d     \n"), max30102.lastir, max30102.lastred, 0, 0, 0, 0)
    ser.printf(string("Red current: %d  \n"), _i_red, 0, 0, 0, 0, 0)
    ser.printf(string("IR current: %d  \n"), _i_ir, 0, 0, 0, 0, 0)
    ser.printf(string("IR offset: %d  \n"), _ir_offset, 0, 0, 0, 0, 0)
    ser.printf(string("Red offset: %d  \n"), _red_offset, 0, 0, 0, 0, 0)
    ser.printf(string("Div: %d\n"), _div, 0, 0, 0, 0, 0)
    ser.printf(string("Die temp: %d\n"), _die_temp, 0, 0, 0, 0, 0)
    _settings_changed := FALSE

PUB cog_acquire | tmp[2], irlc, irhc, rlc, rhc

    repeat until _max30102_cog := max30102.Startx(SCL_PIN, SDA_PIN, I2C_HZ)

' Initial settings
    _i_red := 4_000                                         ' Red LED current (uA)
    _i_ir := 4_000                                          ' IR LED current
    _ir_offset := 37_000
    _red_offset := 32_000
    _div := 70

    max30102.opmode(max30102#SPO2)                          ' SPO2, HR 
    max30102.spo2scale(8192)                                ' 2048, 4096, 8192, 16384
    max30102.spo2samplerate(1600)                           ' 50, 100, 200, 400, 800, 1000, 1600, 3200
    max30102.sampleaverages(32)                             ' 1, 2, 4, 8, 16, 32
    max30102.int1mask(%010)                                 ' Bits 2..0:
'                                                               2: FIFO level
'                                                               1: New data available (required)
'                                                               0: Amb. light cancellation overflow

    max30102.redledcurrent(_i_red)
    max30102.irledcurrent(_i_ir)

    repeat
        repeat until max30102.ppgdataready
        max30102.fiforead(@tmp)
        _last_ir := _ir_data
        _last_red := _red_data
        _ir_data := ((max30102.lastir-_ir_offset)*PRESCALE)/_div    ' Prescale to preserve precision
        _red_data := ((max30102.lastred-_red_offset)*PRESCALE)/_div ' then shrink it down

        if _ir_data =< 0                                    ' If chart data goes offscreen
            irlc++                                          '   increment a counter
        if irlc => 10                                       ' If the counter reaches the threshold
            _ir_offset-=250                                 '   change the visual offset to bring
            irlc := 0                                       '   the chart back onscreen
            _settings_changed := TRUE                       ' Notify the main cog

        if _red_data =< 0
            rhc++
        if rhc => 10
            _red_offset-=250
            rhc := 0
            _settings_changed := TRUE

        if _ir_data => YMAX
            irhc++
        if irhc => 10
            _ir_offset+=250
            irhc := 0
            _settings_changed := TRUE

        if _red_data => YMAX
            rlc++
        if rlc => 10
            _red_offset+=250
            rlc := 0
            _settings_changed := TRUE

        if _settings_changed                                ' If any settings are changed
            max30102.redledcurrent(_i_red)                  ' Tell the sensor about the LED currents
            max30102.irledcurrent(_i_ir)                    '   - they might've changed
            _die_temp := max30102.temperature               ' Update sensor die temperature

PUB cog_keyInput | key

    repeat
        key := ser.charin
            case key
                "=":                                        ' Change LED current
                    _i_red := (_i_red + 0_200) <# 51_000    '   (both IR and Red)
                    _i_ir := (_i_ir + 0_200) <# 51_000
                    max30102.redledcurrent(_i_red)
                    max30102.irledcurrent(_i_ir)
                "-":
                    _i_red := (_i_red - 0_200) #> 0
                    _i_ir := (_i_ir - 0_200) #> 0
                    max30102.redledcurrent(_i_red)
                    max30102.irledcurrent(_i_ir)

                "I":                                        ' Manually change IR data chart offset
                    _ir_offset := (_ir_offset + 250) <# 2_621_440
                "i":
                    _ir_offset := (_ir_offset - 250) #> 65_000

                "R":                                        ' Manually change Red data chart offset
                    _red_offset := (_red_offset + 250) <# 2_621_440
                "r":
                    _red_offset := (_red_offset - 250) #> 65_000

                "D":                                        ' Manually change chart scale divisor
                    _div := (_div + 1) <# 10_0
                "d":
                    _div := (_div - 1) #> 1_0
                " ":
                OTHER:
                    next

            _settings_changed := TRUE

PUB Setup

    repeat until ser.StartRXTX (SER_RX, SER_TX, 0, SER_BAUD)
    time.MSleep(30)
    ser.Clear
    ser.Str(string("Serial terminal started", ser#CR, ser#LF))

    if vga.Start (VGA_PINGROUP, WIDTH, HEIGHT, @_framebuff)
        ser.str(string("VGA Bitmap driver started", ser#CR, ser#LF))
'        vga.FontAddress(fnt.BaseAddr)
'        vga.FontSize(6, 8)
        vga.clear
'        vga.fgcolor(vga#MAX_COLOR)
'        vga.str(string("Ready."))
    else
        ser.str(string("VGA Bitmap driver failed to start - halting", ser#CR, ser#LF))

    cognew(cog_keyInput, @_key_stack)
    cognew(cog_acquire, @_acq_stack)

    repeat until _max30102_cog
    ser.str(string("MAX30102 driver started", ser#CR, ser#LF))

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
