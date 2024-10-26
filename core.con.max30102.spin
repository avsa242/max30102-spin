{
----------------------------------------------------------------------------------------------------
    Filename:       core.con.max30102.spin
    Description:    MAX30102-specific constants
    Author:         Jesse Burt
    Started:        Apr 2, 2020
    Updated:        Oct 26, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    I2C_MAX_FREQ            = 400_000
    SLAVE_ADDR              = $57 << 1
    T_POR                   = 1_000         ' uSec

    DEVID_RESP              = $15

' Register definitions
    INTSTATUS1              = $00
    INTSTATUS1_MASK         = $E1
        A_FULL              = 7
        PPG_RDY             = 6
        ALC_OVF             = 5
        PWR_RDY             = 0

    INTSTATUS2              = $01
    INTSTATUS2_MASK         = $02
        DIE_TEMP_RDY        = 1

    INT_EN1                 = $02
    INT_EN1_MASK            = $E0
        A_FULL_EN           = 7
        PPG_RDY_EN          = 6
        ALC_OVF_EN          = 5

    INT_EN2                 = $03
    INT_EN2_MASK            = $02
        DIE_TEMP_RDY_EN     = 1

    FIFO_WRPTR              = $04
    OVERFL_CNT              = $05
    FIFO_RDPTR              = $06
    FIFODATA                = $07

    FIFOCFG                 = $08
    FIFOCFG_MASK            = $FF
        SMP_AVE             = 5
        FIFO_RLOV_EN        = 4
        FIFO_A_FULL         = 0
        SMP_AVE_BITS        = %111
        FIFO_A_FULL_BITS    = %1111
        SMP_AVE_MASK        = (SMP_AVE_BITS << SMP_AVE) ^ FIFOCFG_MASK
        FIFO_RLOV_EN_MASK   = (1 << FIFO_RLOV_EN) ^ FIFOCFG_MASK
        FIFO_A_FULL_MASK    = FIFO_A_FULL_BITS ^ FIFOCFG_MASK

    MODECFG                 = $09
    MODECFG_MASK            = $C7
        SHDN                = 7
        RESET               = 6
        MODE                = 0
        MODE_BITS           = %111
        SHDN_MASK           = (1 << SHDN) ^ MODECFG_MASK
        MODE_MASK           = MODE_BITS ^ MODECFG_MASK

    SPO2CFG                 = $0A
    SPO2CFG_MASK            = $7F
        SPO2_ADC_RGE        = 5
        SPO2_SR             = 2
        LED_PW              = 0
        SPO2_ADC_RGE_BITS   = %11
        SPO2_SR_BITS        = %111
        LED_PW_BITS         = %11
        SPO2_ADC_RGE_MASK   = (SPO2_ADC_RGE_BITS << SPO2_ADC_RGE) ^ SPO2CFG_MASK
        SPO2_SR_MASK        = (SPO2_SR_BITS << SPO2_SR) ^ SPO2CFG_MASK
        LED_PW_MASK         = LED_PW_BITS ^ SPO2CFG_MASK

' RESERVED                  = $0B
    LED1PA                  = $0C
    LED2PA                  = $0D
' RESERVED                  = $0E
' RESERVED                  = $0F
    PILOT_PA                = $10
    LEDMODECTRL12           = $11
    LEDMODECTRL34           = $12
' RESERVED                  = $13
' RESERVED                  = $14
' RESERVED                  = $15
' RESERVED                  = $16
' RESERVED                  = $17
' RESERVED                  = $18
' RESERVED                  = $19
' RESERVED                  = $1A
' RESERVED                  = $1B
' RESERVED                  = $1C
' RESERVED                  = $1D
' RESERVED                  = $1E
    DIETEMP_INT             = $1F
    DIETEMP_FRACT           = $20
    DIETEMPCFG              = $21
' RESERVED                  = $22
' RESERVED                  = $23
' RESERVED                  = $24
' RESERVED                  = $25
' RESERVED                  = $26
' RESERVED                  = $27
' RESERVED                  = $28
' RESERVED                  = $29
' RESERVED                  = $2A
' RESERVED                  = $2B
' RESERVED                  = $2C
' RESERVED                  = $2D
' RESERVED                  = $2E
' RESERVED                  = $2F
    REVID                   = $FE           ' Revision: Can be $00..$FF
    PARTID                  = $FF


PUB null()
' This is not a top-level object

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

