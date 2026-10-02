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

SetPoint:
    ; Вход: B = Y (0..191), C = X (0..255)
    ; Портит: A, DE, HL

    ; 1. Мгновенно берём готовый H для нашей строки Y из таблицы
    ld   d, HIGH Table_H
    ld   e, b
    ld   a, (de)
    ld   h, a               ; В H теперь точный старший байт адреса экрана

    ; 2. Мгновенно берём базовый L для нашей строки Y из таблицы
    ld   d, HIGH Table_L
    ; e уже равен b
    ld   a, (de)            ; Получили RRR00000 для этой строки
    ld   l, a

    ; 3. Добавляем к L координату X/8
    ld   a, c
    rrca
    rrca
    rrca                    
    and  0x1F               ; A = X / 8
    or   l                  
    ld   l, a               ; HL полностью готов к записи!

    ; 4. Мгновенно берём маску пикселя из таблицы X
    ld   d, HIGH BitTable
    ld   e, c
    ld   a, (de)            ; A = маска

    ; 5. Вывод на экран
    or   (hl)
    ld   (hl), a
    ret



    ALIGN 256
BitTable:
    REPT 32
    DB 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01
    ENDR

    ALIGN 256
Table_H:
    ; Генерируем 192 значения старшего байта адреса для каждой строки Y (0..191)
_Y  = 0
    DUP 192
        DB 0x40 + ((_Y / 64) * 8) + (_Y % 8)
_Y  = _Y + 1
    EDUP
    ; Добиваем оставшиеся 64 байта до 256 для безопасности
    REPT 64
        DB 0
    ENDR

    ALIGN 256
Table_L:
    ; Генерируем 192 значения базового младшего байта знакоместа (RRR00000)
_Y  = 0
    DUP 192
        DB ((_Y % 64) / 8) * 32
_Y  = _Y + 1
    EDUP
    ; Добиваем оставшиеся 64 байта до 256
    REPT 64
        DB 0
    ENDR
    
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
