    DEVICE ZXSPECTRUM48
    ORG 32768

Start:

    ld c, 0      ; x
    ld b, 0      ; y

MainCycle:
    call SetPoint1      ; Ставим точку
    inc c               ; Переходим к следующему x
    jr nz, MainCycle    ; Если не ноль, ставим следующую точку
    inc b               ; А если x==0, то увеличиваем y на единицу
    ld a, b
    cp 176              ; Проверяем, достигли ли последней требуемой строки
    jr nz, MainCycle    ;
    
    ret                 ; Выход из программы

; --- Ваша подпрограмма SetPoint1, использующая ПЗУ ---
SetPoint2:
    push bc          ; Сохраняем наши цикловые регистры X и Y

    ; Шаг 1: Кладем Y (из регистра B) на стек калькулятора BASIC
    ld a, c
    call $2D28       ; ПЗУ: STACK-A (кладет значение из A на стек калькулятора)

    ; Шаг 2: Кладем X (из регистра C) на стек калькулятора BASIC
    pop bc           ; Временно достаем BC, чтобы забрать C
    push bc          ; И снова прячем в стек для цикла
    ld a, b          ; Переносим X в A
    call $2D28       ; ПЗУ: STACK-A (теперь X тоже на стеке калькулятора)

    ; Шаг 3: Вызываем штатный PLOT ПЗУ
    call $22DC       ; ПЗУ: ПОЛНЫЙ PLOT (заберет координаты со стека,
                     ; учтет INK/PAPER/OVER и нарисует точку)

    pop bc           ; Восстанавливаем оригинальные B и C для MainCycle
    ret

SetPoint1:
    ; --- HL = ((y % 64) % 8) * 256 ---
    ld   a, b
    and  63             ; A = y % 64
    and  7              ; A = (y % 64) % 8
    ld   h, a
    ld   l, 0

    ; --- DE = ((y % 64) / 8) * 32 ---
    ld   a, b
    and  63             ; A = y % 64
    srl  a
    srl  a
    srl  a              ; A = (y % 64) / 8
    ld   d, 0
    ld   e, a
    sla  e
    rl   d
    sla  e
    rl   d
    sla  e
    rl   d
    sla  e
    rl   d
    sla  e
    rl   d
    add  hl, de

    ; --- HL += (y / 64) * 2048 ---
    ld   a, b
    srl  a
    srl  a
    srl  a
    srl  a
    srl  a
    srl  a              ; A = y / 64 (0, 1, 2)
    ; Умножаем на 2048 = 8 * 256
    ; A * 2048 = A в битах 11…8
    ld   d, a
    ld   e, 0
    ; DE = A * 256
    ; Нужно A * 2048 = A * 256 * 8
    ; Сдвигаем DE влево 3 раза
    sla  e
    rl   d
    sla  e
    rl   d
    sla  e
    rl   d              ; DE = (y / 64) * 2048
    add  hl, de

    ; --- HL += x / 8 ---
    ld   a, c
    srl  a
    srl  a
    srl  a
    ld   d, 0
    ld   e, a
    add  hl, de

    ; --- HL += 16384 ---
    ld   de, 16384
    add  hl, de

    ld   d, (hl)
    
    ; Здесь нужно установить бит, соотвествующий трём младшим битам в C
    ; --- Строим маску через таблицу ---
    push hl
    ld   a, c
    and  7              ; A = x % 8
    ld   hl, BitTable
    add  a, l
    ld   l, a
    ld   a, (hl)        ; A = маска

    ; --- Устанавливаем бит в D ---
    or   d              ; A = mask | D
    ld   d, a           ; D = байт с установленным битом
    pop hl
    
    ld (hl), d
    ret
    
BitTable:
    DB 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01
    
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
    


program_length = $-Start

    include     TapLib.asm
    MakeTape ZXSPECTRUM48, "fill_scr.tap", "FILL_SCR", Start, program_length, Start
