    DEVICE ZXSPECTRUM48

    ORG 32768

Start:

; *** Рисуем прямоугольники
    ld bc, 0x0000   ; B = Y (16), C = X (16) — начальный левый верхний угол
    ld de, 0x1010   ; D = Ширина (16), E = Высота (16) — начальный размер
    ld h, 35         ; Счётчик цикла: нужно нарисовать 5 прямоугольников

.loop_rect:
    push bc
    push de
    push hl         ; Сохраняем счётчик цикла, так как DrawRect портит HL
    
    call DrawRect   ; Рисуем текущий прямоугольник
    
    pop  hl         ; Восстанавливаем счётчик цикла
    pop  de
    pop  bc
    
    ; --- Смещение для следующего прямоугольника ---
    ld   a, b
    add  a, 3      ; Сдвигаем Y на 20 пикселей вниз
    ld   b, a
    
    ld   a, c
    add  a, 6      ; Сдвигаем X на 20 пикселей вправо
    ld   c, a
    
    ; --- Уменьшаем счётчик и проверяем цикл ---
    dec  h          ; Уменьшаем количество оставшихся прямоугольников
    jr   nz, .loop_rect  ; Если не ноль, переходим к следующему
    
; *** Закрашиваем прямоугольники
    ld bc, 0x2000   ; B = Y (0), C = X (0) — начальный левый верхний угол
    ld de, 0x1010   ; D = Ширина (16), E = Высота (16) — начальный размер
    ld h, 35         ; Счётчик цикла: нужно нарисовать 5 прямоугольников

.loop_fill:
    push bc
    push de
    push hl         ; Сохраняем счётчик цикла, так как DrawRect портит HL
    
    call FillRect   ; Рисуем текущий прямоугольник
    
    pop  hl         ; Восстанавливаем счётчик цикла
    pop  de
    pop  bc
    
    ; --- Смещение для следующего прямоугольника ---
    ld   a, b
    add  a, 3      ; Сдвигаем Y на 20 пикселей вниз
    ld   b, a
    
    ld   a, c
    add  a, 6      ; Сдвигаем X на 20 пикселей вправо
    ld   c, a
    
    ; --- Уменьшаем счётчик и проверяем цикл ---
    dec  h          ; Уменьшаем количество оставшихся прямоугольников
    jr   nz, .loop_fill  ; Если не ноль, переходим к следующему

; *** Рисуем горизонтальные линии
    ld bc, 0x5020
    ld a, 1
.loop_line_h:
    push af
    push bc
    call DrawHLine
    pop bc
    dec c
    inc b
    pop af
    inc a
    inc a
    cp 51
    jr nz, .loop_line_h

    dec a

.loop_line_h2:
    push af
    push bc
    call DrawHLine
    pop bc
    inc c
    inc b   
    pop af
    dec a
    dec a
    jr nz, .loop_line_h2

; *** Рисуем вертикальные линии
    ld bc, 0x9020
    ld a, 1
.loop_line_v:
    push af
    push bc
    call DrawVLine
    pop bc
    inc c
    dec b
    pop af
    inc a
    inc a
    cp 51
    jr nz, .loop_line_v

    dec a

.loop_line_v2:
    push af
    push bc
    call DrawVLine
    pop bc
    inc c
    inc b   
    pop af
    dec a
    dec a
    jr nz, .loop_line_v2
    
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
