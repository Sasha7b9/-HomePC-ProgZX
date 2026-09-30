    DEVICE ZXSPECTRUM48
    ORG 32768

Start:
    LD   HL, 22528        ; HL = начало атрибутов
    LD   BC, 768          ; BC = счётчик
    XOR  A                ; A = 0

Loop:
    LD   (HL), A          ; записать значение
    INC  HL               ; следующий адрес
    INC  A                ; X++
    DEC  BC               ; BC--
    LD   D, A             ; сохраняем A
    LD   A, B
    OR   C                ; проверяем BC на 0
    LD   A, D             ; восстанавливаем A
    JR   NZ, Loop         ; повторяем, если BC ≠ 0
    RET
