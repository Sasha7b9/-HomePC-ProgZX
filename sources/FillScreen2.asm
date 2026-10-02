    DEVICE ZXSPECTRUM48

    ORG 32768

Start:

    call ApplyDrawMode   

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
    ld bc, 0x7808
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
 
; *** Рисуем горизонтальные линии
    ld bc, 0x5028
    ld a, 1
.loop_line_hor:
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
    jr nz, .loop_line_hor

    dec a

.loop_line_hor2:
    push af
    push bc
    call DrawHLine
    pop bc
    inc c
    inc b   
    pop af
    dec a
    dec a
    jr nz, .loop_line_hor2
    
; Рисуем 100 произвольных прямоугольников
    ld a, 100
.loop_rects:
    call DrawRandomRect
    dec a
    jr nz, .loop_rects

    ret

DrawRandomRect:
    push af
    
    ; --- 1. Генерируем безопасный Y и Высоту ---
    call GetRandom
    and  63                 ; Ограничиваем Y диапазоном 0..63
    add  a, 30              ; Сдвигаем чуть ниже (Y = 30..93)
    ld   b, a               ; B = Y
    
    call GetRandom
    and  63                 ; Ограничиваем высоту диапазоном 0..63
    inc  a                  ; Защита от нуля (высота минимум 1 пиксель)
    ld   e, a               ; E = Высота
    ; Максимальный Y нижней грани: 93 + 64 = 157 (строго внутри экрана 191!)

    ; --- 2. Генерируем безопасный X и Ширину ---
    call GetRandom
    and  127                ; Ограничиваем X диапазоном 0..127
    ld   c, a               ; C = X
    
    call GetRandom
    and  127                ; Ограничиваем ширину диапазоном 0..127
    inc  a                  ; Защита от нуля (ширина минимум 1 пиксель)
    ld   d, a               ; D = Ширина
    ; Максимальный X правой грани: 127 + 128 = 255 (строго внутри экрана!)

    call DrawRect
    
    pop  af
    ret

   
    include GraphLib.asm
    include UtilsLib.asm

program_length = $-Start

    include TapLib.asm
    MakeTape ZXSPECTRUM48, "fill_scr.tap", "FILL_SCR", Start, program_length, Start
