    DEVICE ZXSPECTRUM48
    ORG 32768

Start:

    XOR  A                ; A = 0

Start1:

;    LD   HL, 22528        ; HL = начало атрибутов
;    LD   BC, 768          ; BC = счётчик

    LD HL, 16384
    LD BC, 6144

Loop:
    LD   (HL), A          ; записать значение
    INC  HL               ; следующий адрес
    ;ADD  A, A
    INC  A                ; X++
    DEC  BC               ; BC--
    LD   D, A             ; сохраняем A
    LD   A, B
    OR   C                ; проверяем BC на 0
    LD   A, D             ; восстанавливаем A
    JR   NZ, Loop         ; повторяем, если BC ≠ 0
    INC  A
    JP   Start1

program_length = $-Start

    include     TapLib.asm
    MakeTape ZXSPECTRUM48, "noname3.tap", "NONAME3", Start, program_length, Start
