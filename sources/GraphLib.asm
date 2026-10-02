; *****************************************************************************
; GraphLib.asm — Высокопроизводительная графическая библиотека для ZX Spectrum
; *****************************************************************************

; Глобальная переменная режима рисования
; 0 - рисование нулями (Clear), 1 - единицами (Set), 2 - инверсия (XOR)
mode_draw: DB 2

; *****************************************************************************
; ApplyDrawMode — динамически перенастраивает графический код под выбранный mode_draw
; *****************************************************************************
ApplyDrawMode:
    ld   a, (mode_draw)
    and  a
    jr   z, _set_mode_0     ; Если 0 -> режим сброса в 0 (AND)
    dec  a
    jr   z, _set_mode_1     ; Если 1 -> режим установки в 1 (OR)
    jr   _set_mode_2        ; Иначе (2) -> режим инверсии (XOR)

; --- РЕЖИМ 0: Рисование нулями (Стирание) ---
_set_mode_0:
    ld   a, 0xA6            ; Код команды: and (hl)
    ld   (SMC_SetPoint), a
    ld   (SMC_DrawVLine), a
    ld   (SMC_HLine_First), a
    ld   (SMC_HLine_Full), a
    ld   (SMC_HLine_Last), a
    ld   (SMC_HLine_OneByte), a

    ; Настройка целых байт горизонтальной линии: прямая запись 0x00
    ld   a, 0x36            ; Код команды: ld (hl), n
    ld   (SMC_HLine_Opcode), a
    ld   a, 0x00            ; n = 0x00
    ld   (SMC_HLine_Whole), a 
    ret

; --- РЕЖИМ 1: Рисование единицами (Стандартная прорисовка) ---
_set_mode_1:
    ld   a, 0xB6            ; Код команды: or (hl)
    ld   (SMC_SetPoint), a
    ld   (SMC_DrawVLine), a
    ld   (SMC_HLine_First), a
    ld   (SMC_HLine_Full), a
    ld   (SMC_HLine_Last), a
    ld   (SMC_HLine_OneByte), a

    ; Настройка целых байт горизонтальной линии: прямая запись 0xFF
    ld   a, 0x36            ; Код команды: ld (hl), n
    ld   (SMC_HLine_Opcode), a
    ld   a, 0xFF            ; n = 0xFF
    ld   (SMC_HLine_White_Byte), a ; Используем уникальную метку для байта
    ret

; --- РЕЖИМ 2: Рисование через инверсию (XOR) ---
_set_mode_2:
    ld   a, 0xAE            ; Код команды: xor (hl)
    ld   (SMC_SetPoint), a
    ld   (SMC_DrawVLine), a
    ld   (SMC_HLine_First), a
    ld   (SMC_HLine_Full), a
    ld   (SMC_HLine_Last), a
    ld   (SMC_HLine_OneByte), a

    ; ЭКСТРЕМАЛЬНОЕ ИСПРАВЛЕНИЕ ДЛЯ XOR:
    ; Вместо "ld (hl), n" (0x36) мы превращаем этот участок в команду "xor (hl)" (0xAE)
    ; и "ld (hl), a" (0x77). Чтобы уложиться ровно в те же 3 байта в памяти, 
    ; мы перепишем сам цикл горизонтальной линии, сделав его универсальным.
    ld   a, 0xAE            ; Код команды: xor (hl)
    ld   (SMC_HLine_Opcode), a
    ld   a, 0x77            ; Код команды: ld (hl), a
    ld   (SMC_HLine_Whole), a
    ret



; *****************************************************************************
; SetPoint — ставит одиночную точку на экран
;   Input:  B = Y (0..191), C = X (0..255)
;   Портит: A, DE, HL
; *****************************************************************************
SetPoint:
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

    ; 3. Проверка режима для инверсии маски в Режиме 0
    push bc
    ld   bc, (mode_draw)    
    ld   a, c               
    and  a
    ld   a, (de)            
    jr   nz, 1f
    cpl                     
1:
    pop  bc

SMC_SetPoint:
    or   (hl)               
    ld   (hl), a
    ret


; *****************************************************************************
; DrawHLine — БЕЗУПРЕЧНАЯ ГОРИЗОНТАЛЬНАЯ ЛИНИЯ
; *****************************************************************************
DrawHLine:
    and  a
    ret  z                  

    push af                 
    
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

    ld   a, c
    and  7                  
    ld   e, a               

    ld   a, 8
    sub  e
    ld   b, a               

    pop  af                 
    ld   d, a               

    ; Проверяем переходы (используем jp во избежание Target out of range)
    cp   b
    jp   c, _one_byte       
    jp   z, _one_byte_full  

    ; --- Сценарий: Линия длиннее одного байта ---
    push hl                 
    ld   a, e
    ld   hl, MaskRightTable
    add  a, l
    ld   l, a
    ld   a, (hl)            
    
    push bc
    ld   b, a
    ld   a, (mode_draw)
    and  a
    ld   a, b
    jr   nz, 1f
    cpl
1:
    pop  bc
    pop  hl                 
    
SMC_HLine_First:
    or   (hl)               
    ld   (hl), a            
    inc  l                  

    ld   a, d
    sub  b
    ld   d, a               

    ; --- Исправленный цикл заливки целых байт ---
_whole_loop:
    ld   a, d
    cp   8
    jr   c, _last_byte      
    
    ; Загружаем в аккумулятор значение для XOR-инверсии (все единицы)
    ld   a, 0xFF            
    
SMC_HLine_Opcode:
    ld   (hl), a            ; В режимах 0 и 1 тут остаётся ld (hl), a (или мы меняем на xor (hl)?)
                            ; Самый простой способ сделать честный XOR без каши с регистрами:
                            ; Давайте оставим "ld a, 0xFF" и превратим команду ниже либо в "ld (hl), a", либо в "xor (hl) : ld (hl), a"!

SMC_HLine_Whole EQU $-1     ; Второй байт команды (n или 0x77 - ld (hl), a)
SMC_HLine_White_Byte EQU $-1 ; Ссылка на n для режима 1
    nop                     ; Третий байт — предохранитель для выравнивания размера команд
    
    inc  l                  ; Переходим к следующему байту по горизонтали
    
    ld   a, d
    sub  8
    ld   d, a               ; Уменьшаем остаток длины
    jr   _whole_loop


    ; Рисуем финальный хвост
_last_byte:
    ld   a, d
    and  a
    ret  z                  
    
    push hl
    ld   a, d               
    ld   hl, MaskLeftTable
    add  a, l
    ld   l, a
    ld   a, (hl)            
    
    push bc
    ld   b, a
    ld   a, (mode_draw)
    and  a
    ld   a, b
    jr   nz, 1f
    cpl
1:
    pop  bc
    pop  hl
    
SMC_HLine_Last:
    or   (hl)               
    ld   (hl), a
    ret

_one_byte_full:
    push hl
    ld   a, e
    ld   hl, MaskRightTable
    add  a, l
    ld   l, a
    ld   a, (hl)
    
    push bc
    ld   b, a
    ld   a, (mode_draw)
    and  a
    ld   a, b
    jr   nz, 1f
    cpl
1:
    pop  bc
    pop  hl
SMC_HLine_Full:
    or   (hl)               
    ld   (hl), a
    ret

    ; --- Сценарий: Вся линия внутри одного байта ---
_one_byte:
    push hl                 

    ld   a, e
    ld   hl, MaskRightTable
    add  a, l
    ld   l, a
    ld   a, (hl)
    ld   b, a               

    ld   a, e
    add  a, d               
    ld   hl, MaskLeftTable
    add  a, l
    ld   l, a
    ld   a, (hl)            
    
    and  b                  
    ld   b, a
    
    ld   a, (mode_draw)
    and  a
    ld   a, b               
    jr   nz, 1f
    cpl
1:
    pop  hl                 
SMC_HLine_OneByte:
    or   (hl)               
    ld   (hl), a
    ret


; *****************************************************************************
; DrawVLine — рисует вертикальную линию
; *****************************************************************************
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

_v_loop:
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

    ld   a, (mode_draw)
    and  a
    ld   a, e               
    jr   nz, 1f
    cpl
1:
SMC_DrawVLine:
    or   (hl)               
    ld   (hl), a            

    inc  b                  
    dec  ixl                
    jr   nz, _v_loop        
    ret


; *****************************************************************************
; DrawRect — рисует контур прямоугольника (БЕЗ ДЫР НА УГЛАХ В XOR)
;   Input:  B = Y (0..191) — верхний левый угол
;           C = X (0..255) — верхний левый угол
;           D = Ширина в пикселях (1..255)
;           E = Высота в пикселях (1..192)
;   Портит: A, BC, DE, HL
; *****************************************************************************
DrawRect:
    ld   a, d
    and  a
    ret  z                  ; Если ширина 0, выходим
    ld   a, e
    and  a
    ret  z                  ; Если высота 0, выходим

    push bc                 ; [Стек: исходные Y и X]
    push de                 ; [Стек: исходные Y и X, Ширина и Высота]

    ; --- 1. Рисуем полную верхнюю горизонтальную грань ---
    ld   a, d               ; Длина линии = ширина (D)
    call DrawHLine          

    ; --- 2. Рисуем левую вертикальную грань (обрезанную на 1 с краёв) ---
    pop  de
    pop  bc
    push bc                 ; Сохраняем оригинальные параметры
    push de
    
    ld   a, e
    cp   3                  ; Если высота < 3 пикселей, вертикальные грани вырождаются
    jr   c, _skip_left_vline
    
    inc  b                  ; Y = Y + 1 (пропускаем верхний угол)
    sub  2                  ; Высота = Высота - 2 (убираем верхнюю и нижнюю точки)
    call DrawVLine          
_skip_left_vline:

    ; --- 3. Рисуем полную нижнюю горизонтальную грань ---
    pop  de
    pop  bc
    push bc
    push de
    ld   a, b
    add  a, e
    dec  a                  
    ld   b, a               ; Переместили Y на нижнюю строчку прямоугольника
    ld   a, d               ; Длина = ширина (D)
    call DrawHLine          

    ; --- 4. Рисуем правую вертикальную грань (обрезанную на 1 с краёв) ---
    pop  de                 ; Восстановили чистые исходные D (ширина) и E (высота)
    pop  bc                 ; Восстановили чистые исходные B (Y) и C (X)
    
    ld   a, e
    cp   3                  ; Проверяем высоту
    ret  c                  ; Если высота < 3, правая грань из-за обрезки углов не нужна
    
    push de
    ; Рассчитываем точное смещение по X для правой стены: X = X + ширина - 1
    ld   a, c
    add  a, d
    dec  a
    ld   c, a               ; C = точная X правой грани
    
    inc  b                  ; Y = Y + 1 (пропускаем верхний угол)
    pop  de
    ld   a, e
    sub  2                  ; Высота = Высота - 2
    call DrawVLine          
    
    ret



; *****************************************************************************
; FillRect — закрашивает прямоугольник (через DrawHLine)
; *****************************************************************************
FillRect:
    ld   a, d
    and  a
    ret  z                  
    ld   a, e
    and  a
    ret  z                  

_row_loop:
    push bc                 
    push de                 

    ld   a, d               
    call DrawHLine          

    pop  de                 
    pop  bc                 

    inc  b                  
    dec  e                  
    jr   nz, _row_loop      
    ret


; =============================================================================
; ТАБЛИЦЫ
; =============================================================================

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
