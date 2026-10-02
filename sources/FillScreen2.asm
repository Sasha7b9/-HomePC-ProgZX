    DEVICE ZXSPECTRUM48

    ORG 32768

Start:
    ld bc, 0x0000   ; B = Y (16), C = X (16) — начальный левый верхний угол
    ld de, 0x1010   ; D = Ширина (16), E = Высота (16) — начальный размер
    ld h, 35         ; Счётчик цикла: нужно нарисовать 5 прямоугольников

.loop:
    push bc
    push de
    push hl         ; Сохраняем счётчик цикла, так как DrawRect портит HL
    
    call DrawRect   ; Рисуем текущий прямоугольник
    
    pop  hl         ; Восстанавливаем счётчик цикла
    pop  de
    pop  bc
    
    ; --- Смещение для следующего прямоугольника ---
    ld   a, b
    add  a, 2      ; Сдвигаем Y на 20 пикселей вниз
    ld   b, a
    
    ld   a, c
    add  a, 2      ; Сдвигаем X на 20 пикселей вправо
    ld   c, a
    
    ; --- Уменьшаем счётчик и проверяем цикл ---
    dec  h          ; Уменьшаем количество оставшихся прямоугольников
    jr   nz, .loop  ; Если не ноль, переходим к следующему
    
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
