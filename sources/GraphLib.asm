SetPoint:
    ; Вход: B = Y (0..191), C = X (0..255)
    ; Портит: A, DE, HL

    ld   d, HIGH Table_H
    ld   e, b
    ld   a, (de)
    ld   h, a               

    ld   d, HIGH Table_L
    ld   a, (de)            
    ld   l, a               

    ld   a, c
    rrca
    rrca
    rrca                    
    and  0x1F               
    or   l                  
    ld   l, a               

    ld   d, HIGH BitTable
    ld   e, c
    ld   a, (de)            

    or   (hl)
    ld   (hl), a
    ret

; *************************************************************
; DrawHLine — БЕЗУПРЕЧНАЯ ГОРИЗОНТАЛЬНАЯ ЛИНИЯ
; *************************************************************
DrawHLine:
    and  a
    ret  z                  

    push af                 ; [Стек: сохраняем длину]
    
    ; --- 1. Вычисляем адрес байта экрана ---
    ld   d, HIGH Table_H
    ld   e, b
    ld   a, (de)
    ld   h, a               ; H экрана готов

    ld   d, HIGH Table_L
    ; e всё ещё равен b
    ld   a, (de)
    ld   l, a               ; L экрана (базовый) готов

    ld   a, c
    rrca
    rrca
    rrca
    and  0x1F               ; Смещение столбца X / 8
    or   l
    ld   l, a               ; HL = точный адрес байта экрана!

    ; --- 2. Вычисляем параметры масок ---
    ld   a, c
    and  7                  
    ld   e, a               ; E = X % 8 (чистый индекс для MaskRight)

    ld   a, 8
    sub  e
    ld   b, a               ; B = свободных пикселей в 1-м байте

    pop  af                 ; Восстанавливаем длину в A
    ld   d, a               ; D = общая длина линии

    ; Проверяем, помещается ли вся линия в один этот байт?
    cp   b
    jr   c, .one_byte       
    jr   z, .one_byte_full  

    ; --- 3. Сценарий: Линия длиннее одного байта ---
    ; Читаем MaskRightTable по индексу E через HL
    push hl                 ; Сохраняем адрес экрана
    ld   a, e               ; Индекс правого края
    ld   hl, MaskRightTable
    add  a, l
    ld   l, a               ; Так как ALIGN 256, перенос в H невозможен
    ld   a, (hl)            ; A = маска первого байта
    pop  hl                 ; Восстановили адрес экрана
    
    or   (hl)
    ld   (hl), a            
    inc  l                  ; Шаг вправо по экрану

    ; Вычисляем остаток длины: D = D - B
    ld   a, d
    sub  b
    ld   d, a               

    ; --- Цикл заливки целых байт ---
.whole_loop:
    ld   a, d
    cp   8
    jr   c, .last_byte      
    
    ld   (hl), 0xFF         
    inc  l                  
    
    ld   a, d
    sub  8
    ld   d, a               
    jr   .whole_loop

    ; Рисуем финальный хвост (1..7 пикселей)
.last_byte:
    ld   a, d
    and  a
    ret  z                  
    
    push hl
    ld   a, d               ; Остаток пикселей как индекс
    ld   hl, MaskLeftTable
    add  a, l
    ld   l, a
    ld   a, (hl)            ; Читаем точную маску хвоста
    pop  hl
    
    or   (hl)
    ld   (hl), a
    ret

.one_byte_full:
    push hl
    ld   a, e
    ld   hl, MaskRightTable
    add  a, l
    ld   l, a
    ld   a, (hl)
    pop  hl
    or   (hl)
    ld   (hl), a
    ret

    ; --- Сценарий: Вся линия внутри одного байта ---
.one_byte:
    push hl                 ; Сохраняем адрес экрана

    ; 1. Маска правого отсечения (от X до конца байта)
    ld   a, e
    ld   hl, MaskRightTable
    add  a, l
    ld   l, a
    ld   a, (hl)
    ld   b, a               ; B = маска справа

    ; 2. Маска левого отсечения (до конца линии: E + D)
    ld   a, e
    add  a, d               
    ld   hl, MaskLeftTable
    add  a, l
    ld   l, a
    ld   a, (hl)            ; A = маска слева
    
    and  b                  ; Вырезаем чистый кусок линии
    ld   b, a
    
    pop  hl                 ; Восстановили адрес экрана
    ld   a, b               
    or   (hl)
    ld   (hl), a
    ret

; *************************************************************
; DrawVLine — рисует вертикальную линию
; *************************************************************
DrawVLine:
    and  a
    ret  z                  
    
    push af                 
    
    ld   d, HIGH BitTable
    ld   e, c               
    ld   a, (de)
    push af                 

    ld   a, c
    rrca
    rrca
    rrca
    and  0x1F
    ld   c, a               

    pop  af                 
    ld   e, a               
    
    pop  af                 
    ld   ixl, a             

.v_loop:
    ld   d, HIGH Table_H
    ld   h, d               
    ld   l, b               
    ld   a, (hl)            
    push af                 

    ld   d, HIGH Table_L
    ld   h, d               
    ld   a, (hl)            
    
    or   c                  
    ld   l, a               
    pop  af                 
    ld   h, a               

    ld   a, e               
    or   (hl)
    ld   (hl), a            

    inc  b                  
    dec  ixl                
    jr   nz, .v_loop        
    ret

; *************************************************************
; DrawRect — рисует контур прямоугольника
; *************************************************************
DrawRect:
    ld   a, d
    and  a
    ret  z                  
    ld   a, e
    and  a
    ret  z                  

    push bc                 
    push de                 

    ; 1. Верхняя грань
    ld   a, d               
    call DrawHLine          

    ; 2. Левая грань
    pop  de
    pop  bc
    push bc                 
    push de
    ld   a, e               
    call DrawVLine          

    ; 3. Нижня грань
    pop  de
    pop  bc
    push bc
    push de
    ld   a, b
    add  a, e
    dec  a                  
    ld   b, a               
    ld   a, d               
    call DrawHLine          

    ; 4. Правая грань
    pop  de                 
    pop  bc                 
    
    ld   a, c
    add  a, d
    dec  a
    ld   c, a               
    ld   a, e               
    call DrawVLine          
    
    ret

; *************************************************************
; FillRect — закрашивает прямоугольник (через DrawHLine)
;   Input:  B = Y (0..191) — верхний левый угол
;           C = X (0..255) — верхний левый угол
;           D = Ширина в пикселях (1..255)
;           E = Высота в пикселях (1..192)
;   Портит: A, BC, DE, HL
; *************************************************************
FillRect:
    ; Проверяем размеры на 0
    ld   a, d
    and  a
    ret  z                  
    ld   a, e
    and  a
    ret  z                  

.row_loop:
    push bc                 ; Сохраняем текущие Y и X
    push de                 ; Сохраняем ширину и оставшуюся высоту

    ld   a, d               ; Передаем ширину как длину горизонтальной линии
    call DrawHLine          ; Рисуем одну сплошную строку прямоугольника

    pop  de                 ; Восстанавливаем ширину и высоту
    pop  bc                 ; Восстанавливаем Y и X

    inc  b                  ; Сдвигаем Y на следующую строку вниз
    dec  e                  ; Уменьшаем счетчик высоты
    jr   nz, .row_loop      ; Если высота не дошла до 0, красим следующую строку
    ret


; ============================================================
; ТАБЛИЦЫ (ALIGN 256 гарантирует младший байт 0x00)
; ============================================================

    ALIGN 256
BitTable:
    REPT 32
    DB 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01
    ENDR

    ALIGN 256
Table_H:
_Y  = 0
    DUP 192
        DB 0x40 + ((_Y / 64) * 8) + (_Y % 8)
_Y  = _Y + 1
    EDUP
    REPT 64
        DB 0
    ENDR

    ALIGN 256
Table_L:
_Y  = 0
    DUP 192
        DB ((_Y % 64) / 8) * 32
_Y  = _Y + 1
    EDUP
    REPT 64
        DB 0
    ENDR

    ALIGN 256
MaskRightTable:
    DB 0xFF, 0x7F, 0x3F, 0x1F, 0x0F, 0x07, 0x03, 0x01
    REPT 248
        DB 0
    ENDR

    ALIGN 256
MaskLeftTable:
    DB 0x00, 0x80, 0xC0, 0xE0, 0xF0, 0xF8, 0xFC, 0xFE, 0xFF
    REPT 247
        DB 0
    ENDR
