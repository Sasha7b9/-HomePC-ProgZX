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
; DrawSprite16x16 — выводит спрайт 16x16 попиксельно в режиме XOR (ИСПРАВЛЕННЫЙ)
; *****************************************************************************
DrawSprite16x16:
    push ix                 ; Сохраняем указатель на графику спрайта
    push bc                 ; Сохраняем исходные координаты (B=Y, C=X)

    ; 1. Рассчитываем смещение внутри байта (X % 8)
    ld   a, c
    and  7
    ld   (sprite_dot_shift), a 

    ; 2. Рассчитываем номер столбца (X / 8) через логические сдвиги вправо
    ld   a, c
    srl  a                  ; Сдвиг 1: старший бит гарантированно становится 0
    srl  a                  ; Сдвиг 2
    srl  a                  ; Сдвиг 3. Теперь в A чистый результат X / 8
    ld   (sprite_col_num), a   

    ld   a, 16                 ; Высота спрайта: строго 16 строк
    ld   (sprite_lines_cnt), a

_sprite_line_loop:
    ; 3. ВЫЧИСЛЯЕМ СТАРШИЙ БАЙТ АДРЕСА ЭКРАНА (H)
    ld   a, b               ; A = текущий Y
    and  %00000111          ; Выделяем микролинию (Y % 8)
    or   %01000000          ; Добавляем базовый адрес экрана (#4000)
    ld   h, a               ; Временный H готов

    ld   a, b               ; Снова берем Y
    srl  a                  ; Логический сдвиг вправо (чистые нули слева!)
    srl  a                  
    srl  a                  
    and  %00011000          ; Выделяем номер трети экрана
    or   h
    ld   h, a               ; СТАРШИЙ БАЙТ ЭКРАНА (H) ПОЛНОСТЬЮ ГОТОВ!

    ; 4. ВЫЧИСЛЯЕМ МЛАДШИЙ БАЙТ АДРЕСА ЭКРАНА (L)
    ld   a, b               ; A = Y
    sla  a                  ; Арифметический сдвиг влево (ноль влетает в бит 0!)
    sla  a                  
    and  %11100000          ; Выделяем номер знакоместа внутри трети
    ld   l, a               ; Временный L готов

    ; 5. Добавляем номер столбца (X / 8)
    ld   a, (sprite_col_num)
    or   l
    ld   l, a               ; HL = Абсолютно точный физический адрес на экране!

    ; 6. Загружаем 2 байта графики спрайта в DE
    ld   d, (ix+0)          
    ld   e, (ix+1)          
    
    ; 7. Попиксельный сдвиг "на лету"
    ld   a, (sprite_dot_shift)
    and  a
    jr   z, _sprite_no_shift 

    ; Если сдвиг нужен, защищаем рабочий Y (в регистре B) перед djnz!
    push bc                 ; [Стек]: Прячем B (текущий Y) и C (координату X)
    ld   c, 0               ; Третий байт для хвоста спрайта
    ld   b, a               ; Количество сдвигов для DJNZ

_sprite_shift_loop:
    srl  d                  ; Чистый логический сдвиг вправо
    rr   e                  
    rr   c                  
    djnz _sprite_shift_loop 

    ld   a, c               ; Забираем готовый хвост в A
    pop  bc                 ; [Стек]: ВОССТАНОВИЛИ ЧИСТЫЕ КООРДИНАТЫ СТРОКИ (B=Y!)
    ld   c, a               ; Хвост переезжает в C
    jr   _sprite_render

_sprite_no_shift:
    ld   c, 0               

_sprite_render:
    ; В этой точке: HL = чистый адрес экрана, D = левый, E = средний, C = хвост

    ; --- Наложение 1-го байта ---
    ld   a, d
    xor  (hl)               
    ld   (hl), a
    inc  l                  

    ; --- Наложение 2-го байта ---
    ld   a, e
    xor  (hl)               
    ld   (hl), a

    ; --- Наложение 3-го байта ---
    ld   a, (sprite_dot_shift)
    and  a
    jr   z, _sprite_next_line 
    
    inc  l                  
    ld   a, c
    xor  (hl)               
    ld   (hl), a

_sprite_next_line:
    inc  ix                 ; Переходим к следующей строке спрайта
    inc  ix

    inc  b                  ; Y = Y + 1 (переходим на следующую микролинию растра)
    
    ld   a, (sprite_lines_cnt)
    dec  a
    ld   (sprite_lines_cnt), a
    jr   nz, _sprite_line_loop

    pop  bc                 ; Восстанавливаем оригинальные BC для основного цикла
    pop  ix                 ; Восстанавливаем оригинальный IX
    ret

; Локальные переменные функции
sprite_lines_cnt:  DB 0
sprite_dot_shift:  DB 0
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


