    DEVICE ZXSPECTRUM48
    ORG 32768


Start:
    ; 1. Включаем стандартный режим прорисовки и генерируем фон
    ld   a, 1
    ld   (mode_draw), a
    call ApplyDrawMode

    ; Нарисуем сетку прямоугольников для красивого фона
    ld   bc, 0x0505
    ld   de, 0x2020
    ld   h, 4
.bg_loop:
    push bc
    push de
    push hl
    call DrawRect
    pop  hl
    pop  de
    pop  bc
    ld   a, c
    add  a, 40
    ld   c, a
    dec  h
    jr   nz, .bg_loop

    ; 2. ПЕРЕКЛЮЧАЕМ ДВИЖОК В РЕЖИМ XOR ДЛЯ СПРАЙТОВ
    ; (Функция DrawSprite16x16 жестко использует XOR внутри, но для стабильности 
    ;  выставим флаг, чтобы другие элементы не портили логику).
    ld   a, 2
    ld   (mode_draw), a
    call ApplyDrawMode

    ; Начальные координаты пришельца
    ld   b, 10              ; Y = 10
    ld   c, 0               ; X = 0 (начинаем с левого края)

.animation_loop:
    ; --- СТАДИЯ A: РИСУЕМ СПРАЙТ НА НОВОМ МЕСТЕ ---
    push bc
    ld   ix, Sprite_Alien   ; Загружаем адрес графики пришельца
    call DrawSprite16x16    ; Нарисовали пришельца поверх фона!
    pop  bc

    ; Небольшая задержка, чтобы человеческий глаз успел увидеть кадр
;    call Delay_Frame

    ; --- СТАДИЯ Б: СТИРАЕМ СПРАЙТ ПОВТОРНЫМ XOR В ТЕХ ЖЕ КООРДИНАТАХ ---
    push bc
    ld   ix, Sprite_Alien   ; Указатель нужно восстановить, так как DrawSprite его увеличил
    call DrawSprite16x16    ; ПОВТОРНЫЙ XOR СТЁР ПРИШЕЛЬЦА И ИДЕАЛЬНО ВОССТАНОВИЛ ФОН!
    pop  bc

    ; --- СТАДИЯ В: СДВИГАЕМ КООРДИНАТУ ---
    inc  c                  ; Сдвигаем X на 1 пиксель вправо!
    ld   a, c
    cp   220                ; Двигаем, пока не дойдем до правого края экрана
    jr   nz, .animation_loop

    ; Пришелец долетел до конца, выход
    ret


; Данные спрайта 16x16 (каждая строка — 2 байта)
Sprite_Alien:
    DB 0x03, 0xC0    ;   00000011 11000000
    DB 0x0F, 0xF0    ;   00001111 11110000
    DB 0x1E, 0x78    ;   00011110 01111000
    DB 0x3C, 0x3C    ;   00111100 00111100
    DB 0x7F, 0xFE    ;   01111111 11111110
    DB 0x6D, 0xB6    ;   01101101 10110110  (Глаза)
    DB 0x7F, 0xFE    ;   01111111 11111110
    DB 0x3E, 0x7C    ;   00111110 01111100
    DB 0x1F, 0xF8    ;   00011111 11111000
    DB 0x0C, 0x30    ;   00001100 00110000
    DB 0x1E, 0x78    ;   00011110 01111000
    DB 0x33, 0xCC    ;   00110011 11001100
    DB 0x61, 0x86    ;   01100001 10000110
    DB 0x40, 0x02    ;   01000000 00000010
    DB 0xC0, 0x03    ;   11000000 00000011
    DB 0xC0, 0x03    ;   11000000 00000011

; *****************************************************************************
; DrawSprite16x16 — Высокоскоростной табличный отрисовщик спрайтов 16x16 (XOR)
;   Специфическая оптимизация под SjASMPlus
;   Input:  B = Y (0..176), C = X (0..240), IX = Адрес данных спрайта
; *****************************************************************************
DrawSprite16x16:
    push ix                 ; Сохраняем исходный указатель на спрайт
    push bc                 ; Сохраняем исходные координаты (B=Y, C=X)

    ; 1. Получаем смещение пикселей (X % 8) для таблицы переходов сдвига
    ld   a, c
    and  7
    add  a, a               ; Умножаем на 2 (размер одного указателя DW)
    ld   e, a
    ld   d, 0
    ld   hl, _shift_jmp_table
    add  hl, de
    ld   a, (hl)
    ld   (_SMC_Shift_Jmp), a ; Настраиваем адрес быстрого сдвига (младший байт)
    inc  hl
    ld   a, (hl)
    ld   (_SMC_Shift_Jmp+1), a ; Старший байт

    ; 2. Вычисляем номер начального столбца (X / 8)
    ld   a, c
    srl  a
    srl  a
    srl  a
    and  0x1F
    ld   (sprite_col_num), a   

    ld   a, 16                 ; Настраиваем высоту спрайта (16 строк)
    ld   (sprite_lines_cnt), a

_sprite_line_loop:
    ; 3. ТАБЛИЧНЫЙ РАСЧЕТ АДРЕСА СТРОКИ ЭКРАНА
    ld   d, HIGH Table_H
    ld   e, b               ; E = текущий Y
    ld   a, (de)
    ld   h, a               ; H экрана готов

    ld   d, HIGH Table_L    ; E по-прежнему равен Y
    ld   a, (de)
    ld   l, a               ; L экрана готов

    ; 4. Добавляем смещение столбца (X / 8) через логическое OR
    ld   a, (sprite_col_num)
    or   l
    ld   l, a               ; HL = Физический адрес строки на экране

    ; 5. Загружаем 2 байта графики из памяти IX
    ld   d, (ix+0)          
    ld   e, (ix+1)          
    
    ; 6. УЛЬТРАБЫСТРЫЙ СДВИГ БЕЗ DJNZ (Через SMC и каскадный пролет)
    push bc                 ; Защищаем рабочие координаты строки (B=Y) в стек
    ld   c, 0               ; Очищаем C (будет собирать 3-й байт/хвост)

SMC_Shift_Select:
    jp   0x0000             ; Этот JP динамически перезаписывается на нужный шаг сдвига
_SMC_Shift_Jmp EQU SMC_Shift_Select+1

; --- Каскадная сетка сдвигов для SjASMPlus ---
; Если нужен сдвиг на 1 бит, мы прыгаем сразу на _shift_1 и делаем 1 сдвиг.
; Если нужен сдвиг на 7 бит, прыгаем на _shift_7 и проваливаемся сквозь все 7 блоков.
_shift_7: REPT 1 : srl d : rr e : rr c : ENDR
_shift_6: REPT 1 : srl d : rr e : rr c : ENDR
_shift_5: REPT 1 : srl d : rr e : rr c : ENDR
_shift_4: REPT 1 : srl d : rr e : rr c : ENDR
_shift_3: REPT 1 : srl d : rr e : rr c : ENDR
_shift_2: REPT 1 : srl d : rr e : rr c : ENDR
_shift_1: REPT 1 : srl d : rr e : rr c : ENDR
_shift_0: 
    ; 0 бит — чистый пролет

    ld   a, c               ; Забираем получившийся хвост в аккумулятор A
    pop  bc                 ; Из стека вернули чистые рабочие координаты строки (B=Y!)
    ld   c, a               ; Хвост переезжает в C

_sprite_render:
    ; В этой точке: HL = адрес экрана, D = левый байт, E = средний байт, C = хвост

    ; --- Наложение 1-го байта ---
    ld   a, d
    xor  (hl)               
    ld   (hl), a
    inc  l                  ; Шаг на следующий байт экрана вправо

    ; --- Наложение 2-го байта ---
    ld   a, e
    xor  (hl)               
    ld   (hl), a

    ; --- Наложение 3-го байта ---
    ld   a, c               ; Если хвост равен 0, значит сдвига не было — 3-й байт пропускаем
    and  a
    jr   z, _sprite_next_line 
    
    inc  l                  ; Шаг на 3-й байт экрана вправо
    xor  (hl)               
    ld   (hl), a

_sprite_next_line:
    inc  ix                 ; Смещаем указатель данных на следующую строку спрайта
    inc  ix

    inc  b                  ; Y = Y + 1 (переходим на следующую микролинию на экране)
    
    ld   a, (sprite_lines_cnt)
    dec  a
    ld   (sprite_lines_cnt), a
    jr   nz, _sprite_line_loop

    pop  bc                 ; Восстанавливаем оригинальные BC для основного цикла
    pop  ix                 ; Восстанавливаем оригинальный IX
    ret

; --- Таблица адресов переходов для мгновенной настройки сдвига ---
_shift_jmp_table:
    DW _shift_0, _shift_1, _shift_2, _shift_3, _shift_4, _shift_5, _shift_6, _shift_7

; Локальные переменные функции
sprite_lines_cnt:  DB 0
sprite_col_num:    DB 0



; Простая задержка для фреймрейта
Delay_Frame:
    push bc
    ld   bc, 0x1AFF
.d_loop:
    dec  bc
    ld   a, b
    or   c
    jr   nz, .d_loop
    pop  bc
    ret

    include GraphLib.asm

program_length = $-Start

    include TapLib.asm
    MakeTape ZXSPECTRUM48, "sprites.tap", "sprites", Start, program_length, Start


