    DEVICE ZXSPECTRUM48

    ORG 32768

Start:
    ld c, 0      ; x
    ld b, 0      ; y

MainCycle:
    call SetPoint      ; Ставим точку
    inc c               ; Переходим к следующему x
    jr nz, MainCycle    ; Если не ноль, ставим следующую точку
    inc b               ; А если x==0, то увеличиваем y на единицу
    ld a, b
    cp 176              ; Проверяем, достигли ли последней требуемой строки
    jr nz, MainCycle    ;   
    ret                 ; Выход из программы

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
