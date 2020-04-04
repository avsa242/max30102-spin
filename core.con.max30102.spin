{
    --------------------------------------------
    Filename: core.con.max30102.spin
    Author:
    Description:
    Copyright (c) 2020
    Started Apr 02, 2020
    Updated Apr 02, 2020
    See end of file for terms of use.
    --------------------------------------------
}

CON

    I2C_MAX_FREQ                = 400_000               'Change to your device's maximum bus rate, according to its datasheet
    SLAVE_ADDR                  = $57 << 1


    INTSTATUS1                  = $00
    INTSTATUS2                  = $01
    INTENABLE1                  = $02
    INTENABLE2                  = $03
    FIFOWRITEPTR                = $04
    OVERFLOWCNT                 = $05
    FIFOREADPTR                 = $06
    FIFODATA                    = $07

    FIFOCONFIG                  = $08
    FIFOCONFIG_MASK             = $FF
        FLD_SMP_AVE             = 5
        FLD_FIFO_ROLLOVER_EN    = 4
        FLD_FIFO_A_FULL         = 0
        BITS_SMP_AVE            = %111
        MASK_SMP_AVE            = FIFOCONFIG_MASK ^ (BITS_SMP_AVE << FLD_SMP_AVE)
        MASK_FIFO_ROLLOVER_EN   = FIFOCONFIG_MASK ^ (1 << FLD_FIFO_ROLLOVER_EN)
        MASK_FIFO_A_FULL        = FIFOCONFIG_MASK ^ (1 << FLD_FIFO_A_FULL)

    MODECONFIG                  = $09
    MODECONFIG_MASK             = $C7
        FLD_SHDN                = 7
        FLD_RESET               = 6
        FLD_MODE                = 0
        BITS_MODE               = %111
        MASK_SHDN               = MODECONFIG_MASK ^ (1 << FLD_SHDN)
        MASK_MODE               = MODECONFIG_MASK ^ (BITS_MODE << FLD_MODE)

    SPO2CONFIG                  = $0A
' RESERVED                      = $0B
    LED1PA                      = $0C
    LED2PA                      = $0D
' RESERVED                      = $0E
' RESERVED                      = $0F
    LEDMODECTRL12               = $11
    LEDMODECTRL34               = $12
' RESERVED                      = $13
' RESERVED                      = $14
' RESERVED                      = $15
' RESERVED                      = $16
' RESERVED                      = $17
' RESERVED                      = $18
' RESERVED                      = $19
' RESERVED                      = $1A
' RESERVED                      = $1B
' RESERVED                      = $1C
' RESERVED                      = $1D
' RESERVED                      = $1E
    DIETEMP_INT                 = $1F
    DIETEMP_FRACT               = $20
    DIETEMPCONFIG               = $21
' RESERVED                      = $22
' RESERVED                      = $23
' RESERVED                      = $24
' RESERVED                      = $25
' RESERVED                      = $26
' RESERVED                      = $27
' RESERVED                      = $28
' RESERVED                      = $29
' RESERVED                      = $2A
' RESERVED                      = $2B
' RESERVED                      = $2C
' RESERVED                      = $2D
' RESERVED                      = $2E
' RESERVED                      = $2F
    REVID                       = $FE   ' Revision: Can be $00..$FF
    PARTID                      = $FF
    PARTID_RESP                 = $15

PUB Null
'' This is not a top-level object
