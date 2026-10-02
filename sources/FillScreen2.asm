    DEVICE ZXSPECTRUM48

    ORG 32768

Start:
    ld c, 0      ; x
    ld b, 0      ; y
    ld de, 150

.loop:
    ld bc, 0x1010
    ld de, 0x1010
    call DrawRect
    ret
    
Delay:
    push bc
    ld bc, 0xFFF
Delay1:
    dec bc
    ld a,b
    or c
    jr nz, Delay1
    pop bc
    ret
    
    include GraphLib.asm

program_length = $-Start

    include TapLib.asm
    MakeTape ZXSPECTRUM48, "fill_scr.tap", "FILL_SCR", Start, program_length, Start
