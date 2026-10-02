; *****************************************************************************
; GraphLib.asm — Высокопроизводительная графическая библиотека для ZX Spectrum
; *****************************************************************************

; Глобальная переменная режима рисования
; 0 - рисование нулями (Clear), 1 - единицами (Set), 2 - инверсия (XOR)
mode_draw: DB 2

; *****************************************************************************
; ApplyDrawMode — динамически перенастраивает графический код под выбранный mode_draw
;   Вход:   Переменная [mode_draw] (0, 1 или 2)
;   Портит: A, HL, BC
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
;    ld   (SMC_HLine_Full), a
    ld   (SMC_HLine_Last), a
    ld   (SMC_HLine_OneByte), a

    ; Направляем горизонтальную линию на ПРЯМОЙ цикл (Абсолютный JP)
    ld   a, 0xC3            ; Код команды: jp nnnn
    ld   (SMC_HLine_LoopSelect), a
    ld   hl, _whole_loop_direct
    ld   (SMC_HLine_LoopSelect + 1), hl

    ld   a, 0x00            ; Заливаем чистыми нулями
    ld   (SMC_HLine_Whole_Val), a 
    ret

; --- РЕЖИМ 1: Рисование единицами (Стандартная прорисовка) ---
_set_mode_1:
    ld   a, 0xB6            ; Код команды: or (hl)
    ld   (SMC_SetPoint), a
    ld   (SMC_DrawVLine), a
    ld   (SMC_HLine_First), a
;    ld   (SMC_HLine_Full), a
    ld   (SMC_HLine_Last), a
    ld   (SMC_HLine_OneByte), a

    ; Направляем горизонтальную линию на ПРЯМОЙ цикл (Абсолютный JP)
    ld   a, 0xC3            ; Код команды: jp nnnn
    ld   (SMC_HLine_LoopSelect), a
    ld   hl, _whole_loop_direct
    ld   (SMC_HLine_LoopSelect + 1), hl

    ld   a, 0xFF            ; Заливаем единицами
    ld   (SMC_HLine_Whole_Val), a
    ret

; --- РЕЖИМ 2: Рисование через инверсию (XOR) ---
_set_mode_2:
    ld   a, 0xAE            ; Код команды: xor (hl)
    ld   (SMC_SetPoint), a
    ld   (SMC_DrawVLine), a
    ld   (SMC_HLine_First), a
;    ld   (SMC_HLine_Full), a
    ld   (SMC_HLine_Last), a
    ld   (SMC_HLine_OneByte), a

    ; НАДЁЖНОЕ ИСПРАВЛЕНИЕ: Направляем горизонтальную линию на ЧЕСТНЫЙ XOR-цикл
    ld   a, 0xC3            ; Код команды: jp nnnn
    ld   (SMC_HLine_LoopSelect), a
    ld   hl, _whole_loop_xor
    ld   (SMC_HLine_LoopSelect + 1), hl
    ret


; *****************************************************************************
; SetPoint — ставит одиночную точку на экран
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
; DrawHLine — ГОРИЗОНТАЛЬНАЯ ЛИНИЯ С ЧЕСТНЫМ СУПЕР-XOR ЦИКЛОМ
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

; --- ДИСПЕТЧЕР ЦИКЛОВ (SMC динамически записывает сюда JP ветки А или Б) ---
SMC_HLine_LoopSelect:
    jp   _whole_loop_direct ; Резервируем 3 байта (Код 0xC3 и 16-битный адрес)

; --- ВЕТКА А: Прямая заливка байт (для режимов OR и AND) ---
_whole_loop_direct:
    ld   a, d
    cp   8
    jr   c, _last_byte      
    
    ld   a, 0xFF            
SMC_HLine_Whole_Val EQU $-1
    ld   (hl), a         
    inc  l                  
    
    ld   a, d
    sub  8
    ld   d, a               
    jr   _whole_loop_direct

; --- ВЕТКА Б: Честная побайтовая XOR-инверсия (для режима 2) ---
_whole_loop_xor:
    ld   a, d
    cp   8
    jr   c, _last_byte      
    
    ld   a, (hl)            
    xor  0xFF               
    ld   (hl), a            
    inc  l                  
    
    ld   a, d
    sub  8
    ld   d, a               
    jr   _whole_loop_xor


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
    ld   a, e
    ld   hl, MaskRightTable
    add  a, l
    ld   l, a
    ld   a, (hl)            ; Считали маску в A
    
    push bc
    ld   b, a
    ld   a, (mode_draw)
    and  a
    ld   a, b
    jr   nz, 1f
    cpl
1:
    pop  bc
    or   (hl)               ; Применяем прямо к экрану (адрес HL не менялся)
    ld   (hl), a
    ret


    ; --- Сценарий: Вся линия внутри одного байта (ИСПРАВЛЕНО) ---
_one_byte:
    push hl                 ; [Стек: сохранили адрес экрана]

    ; 1. Маска правого отсечения (от X до конца байта)
    ld   a, e
    ld   hl, MaskRightTable
    add  a, l
    ld   l, a
    ld   a, (hl)
    ld   b, a               ; ЖЕЛЕЗНО: прячем маску правого края в B (стек не трогаем!)

    ; 2. Маска левого отсечения (до конца линии: E + D)
    ld   a, e
    add  a, d               
    ld   hl, MaskLeftTable
    add  a, l
    ld   l, a
    ld   a, (hl)            ; A = маска левого отсечения
    
    and  b                  ; Вырезаем чистый кусок линии (A = маска левая AND маска правая)
    ld   e, a               ; Прячем готовую маску отрезка в безопасный E
    
    ld   a, (mode_draw)
    and  a
    ld   a, e               ; Восстановили маску отрезка в A
    jr   nz, _skip_inv_ob
    cpl                     ; Для режима 0 инвертируем
_skip_inv_ob:
    pop  hl                 ; [Стек: восстановили точный адрес экрана!]
SMC_HLine_OneByte:
    or   (hl)               
    ld   (hl), a
    ret                     ; Безопасный возврат в DrawRect



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
; DrawRect — рисует контур прямоугольника (Защита через индексные регистры)
;   Input:  B = Y (0..191) — верхний левый угол
;           C = X (0..255) — верхний левый угол
;           D = Ширина в пикселях (1..255)
;           E = Высота в пикселях (1..192)
;   Портит: A, BC, DE, HL
; *****************************************************************************
DrawRect:
    ; Верхняя линия
    push bc
    push de
    ld a, d
    call DrawHLine
    pop de
    pop bc

    ; Нижняя линия
    push bc
    push de
    ld a, b
    add a, e
    ld b, a
    ld a, d
    call DrawHLine
    pop de
    pop bc
    
    ; Левая линия
    push bc
    push de
    inc b
    ld a, e
    dec a
    call DrawVLine
    pop de
    pop bc

    ; Правая линия
    ld a, c
    add d
    dec a
    inc b
    ld c, a
    ld a, e
    dec a
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
; ТАБЛИЦЫ (ALIGN 256 гарантирует младший байт 0x00)
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
