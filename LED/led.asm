; =========================================
; executor.asm - ИСПОЛНИТЕЛЬ
; Спрашивает имя файла, загружает и выполняет
; =========================================

.include "m328pdef.inc"
.include "name.asm"          ; R0C0, R0C1, ..., R9C9
.include "audio.asm"         ; Аудиопорт

; ===== ОПКОДЫ =====
.equ OP_0x01 = 0x01   ; led-on
.equ OP_0x02 = 0x02   ; led-off
.equ OP_0x03 = 0x03   ; rdg.key
.equ OP_0x04 = 0x04   ; cnd
.equ OP_0x05 = 0x05   ; delay
.equ OP_0xFF = 0xFF   ; end

; ===== БУФЕРЫ =====
.dseg
.org 0x0100
filename:   .byte 20        ; Имя файла
program:    .byte 256       ; Загруженная программа
last_key:   .byte 1         ; Последняя нажатая клавиша

.cseg
.org 0x0000

; =========================================
; ГЛАВНАЯ ПРОГРАММА
; =========================================
main:
    call init_uart          ; Для общения с терминалом
    call init_matrix        ; Настроить светодиоды

    ; =====================================
    ; 1. СПРОСИТЬ ИМЯ ФАЙЛА
    ; =====================================
ask_filename:
    call print_string
    .db "Введите имя файла: ", 0

    call read_string        ; Читаем имя файла в filename

    ; =====================================
    ; 2. ЗАГРУЗИТЬ ФАЙЛ
    ; =====================================
    call load_file

    ; =====================================
    ; 3. ВЫПОЛНИТЬ
    ; =====================================
    call execute_program

    ; =====================================
    ; 4. ГОТОВО
    ; =====================================
    call print_string
    .db "Готово!", 0

loop:
    rjmp loop

; =========================================
; ЗАГРУЗКА ФАЙЛА
; =========================================
load_file:
    ; Читаем HEX-строку из UART и переводим в байты
    ; Пример: "01 63 02 63 03 FF"
    ; Результат: program[] = {0x01, 0x63, 0x02, 0x63, 0x03, 0xFF}
    
    push r16
    push r17
    push r18
    push r19
    
    ldi ZL, low(program)    ; Указатель на буфер программы
    ldi ZH, high(program)
    
load_loop:
    call read_hex_byte      ; Читаем один байт из UART
    cpi r16, 0xFF           ; Если конец?
    breq load_done
    st Z+, r16              ; Сохраняем байт в программу
    rjmp load_loop
    
load_done:
    ldi r16, OP_0xFF        ; Добавляем OP_END
    st Z+, r16
    
    pop r19
    pop r18
    pop r17
    pop r16
    ret

; =========================================
; ВЫПОЛНЕНИЕ ПРОГРАММЫ
; =========================================
execute_program:
    ldi ZL, low(program)
    ldi ZH, high(program)

execute_loop:
    ld r16, Z+              ; Читаем команду

    cpi r16, OP_0x01
    breq exec_led_on

    cpi r16, OP_0x02
    breq exec_led_off

    cpi r16, OP_0x03
    breq exec_rdg_key

    cpi r16, OP_0x04
    breq exec_cnd

    cpi r16, OP_0x05
    breq exec_delay

    cpi r16, OP_0xFF
    breq exec_end

    ; Неизвестная команда
    call print_string
    .db "Ошибка: неизвестный опкод!", 0
    ret

; =========================================
; led-on # — ВКЛЮЧИТЬ СВЕТОДИОД
; =========================================
exec_led_on:
    ld r16, Z+              ; Читаем номер пина (0-99)
    call set_led_on
    rjmp execute_loop

; =========================================
; led-off # — ВЫКЛЮЧИТЬ СВЕТОДИОД
; =========================================
exec_led_off:
    ld r16, Z+
    call set_led_off
    rjmp execute_loop

; =========================================
; rdg.key — ПРОЧИТАТЬ КЛАВИШУ
; =========================================
exec_rdg_key:
    call read_key_from_uart
    sts last_key, r16
    rjmp execute_loop

; =========================================
; cnd — УСЛОВИЕ
; =========================================
exec_cnd:
    ld r16, Z+              ; Читаем ASCII-код для сравнения
    lds r17, last_key       ; Загружаем последнюю клавишу
    cp r16, r17
    breq exec_cnd_true
    adiw ZL, 2              ; Пропускаем команду и аргумент
    rjmp execute_loop
exec_cnd_true:
    rjmp execute_loop

; =========================================
; delay — ЗАДЕРЖКА
; =========================================
exec_delay:
    ld r24, Z+              ; Младший байт
    ld r25, Z+              ; Старший байт
    call delay_ms
    rjmp execute_loop

; =========================================
; КОНЕЦ ПРОГРАММЫ
; =========================================
exec_end:
    ret

; =========================================
; set_led_on — ВКЛЮЧИТЬ ПО НОМЕРУ
; =========================================
set_led_on:
    ; r16 = номер светодиода (0-99)
    ; Превращаем в строку и столбец
    ; Зажигаем в матрице 10×10
    
    push r16
    push r17
    push r18
    push r19
    
    ; Разбиваем номер на строку и столбец
    mov r17, r16
    clr r16
div_loop:
    cpi r17, 10
    brlo div_done
    subi r17, 10
    inc r16
    rjmp div_loop
div_done:
    ; r16 = строка (0-9), r17 = столбец (0-9)
    
    ; Включаем строку (катод, активный 0)
    ldi r18, 0xFF
    out PORTD, r18         ; Отключаем все строки
    
    cpi r16, 0
    breq row0
    cpi r16, 1
    breq row1
    cpi r16, 2
    breq row2
    cpi r16, 3
    breq row3
    cpi r16, 4
    breq row4
    cpi r16, 5
    breq row5
    cpi r16, 6
    breq row6
    cpi r16, 7
    breq row7
    cpi r16, 8
    breq row8
    rjmp row9

row0: cbi PORTD, 0  ; rjmp row_done
row1: cbi PORTD, 1  ; rjmp row_done
row2: cbi PORTD, 2  ; rjmp row_done
row3: cbi PORTD, 3  ; rjmp row_done
row4: cbi PORTD, 4  ; rjmp row_done
row5: cbi PORTD, 5  ; rjmp row_done
row6: cbi PORTD, 6  ; rjmp row_done
row7: cbi PORTD, 7  ; rjmp row_done
row8: cbi PORTC, 0  ; rjmp row_done
row9: cbi PORTC, 1  ; rjmp row_done

row_done:

    ; Включаем столбец (анод, активный 1)
    ldi r18, 0x00
    out PORTB, r18         ; Отключаем все столбцы
    
    cpi r17, 0
    breq col0
    cpi r17, 1
    breq col1
    cpi r17, 2
    breq col2
    cpi r17, 3
    breq col3
    cpi r17, 4
    breq col4
    cpi r17, 5
    breq col5
    cpi r17, 6
    breq col6
    cpi r17, 7
    breq col7
    cpi r17, 8
    breq col8
    rjmp col9

col0: sbi PORTB, 0  ; rjmp col_done
col1: sbi PORTB, 1  ; rjmp col_done
col2: sbi PORTB, 2  ; rjmp col_done
col3: sbi PORTB, 3  ; rjmp col_done
col4: sbi PORTB, 4  ; rjmp col_done
col5: sbi PORTB, 5  ; rjmp col_done
col6: sbi PORTB, 6  ; rjmp col_done
col7: sbi PORTB, 7  ; rjmp col_done
col8: sbi PORTC, 2  ; rjmp col_done
col9: sbi PORTC, 3  ; rjmp col_done

col_done:

    pop r19
    pop r18
    pop r17
    pop r16
    ret

; =========================================
; set_led_off — ВЫКЛЮЧИТЬ ПО НОМЕРУ
; =========================================
set_led_off:
    ; r16 = номер светодиода (0-99)
    ; Аналогично set_led_on, но выключаем
    
    push r16
    push r17
    push r18
    push r19
    
    ; Разбиваем номер
    mov r17, r16
    clr r16
div_off_loop:
    cpi r17, 10
    brlo div_off_done
    subi r17, 10
    inc r16
    rjmp div_off_loop
div_off_done:
    ; r16 = строка, r17 = столбец
    
    ; Выключаем строку (отключаем катод)
    cpi r16, 0
    breq off_row0
    cpi r16, 1
    breq off_row1
    cpi r16, 2
    breq off_row2
    cpi r16, 3
    breq off_row3
    cpi r16, 4
    breq off_row4
    cpi r16, 5
    breq off_row5
    cpi r16, 6
    breq off_row6
    cpi r16, 7
    breq off_row7
    cpi r16, 8
    breq off_row8
    rjmp off_row9

off_row0: sbi PORTD, 0  ; rjmp off_row_done
off_row1: sbi PORTD, 1  ; rjmp off_row_done
off_row2: sbi PORTD, 2  ; rjmp off_row_done
off_row3: sbi PORTD, 3  ; rjmp off_row_done
off_row4: sbi PORTD, 4  ; rjmp off_row_done
off_row5: sbi PORTD, 5  ; rjmp off_row_done
off_row6: sbi PORTD, 6  ; rjmp off_row_done
off_row7: sbi PORTD, 7  ; rjmp off_row_done
off_row8: sbi PORTC, 0  ; rjmp off_row_done
off_row9: sbi PORTC, 1  ; rjmp off_row_done

off_row_done:

    ; Выключаем столбец (отключаем анод)
    cpi r17, 0
    breq off_col0
    cpi r17, 1
    breq off_col1
    cpi r17, 2
    breq off_col2
    cpi r17, 3
    breq off_col3
    cpi r17, 4
    breq off_col4
    cpi r17, 5
    breq off_col5
    cpi r17, 6
    breq off_col6
    cpi r17, 7
    breq off_col7
    cpi r17, 8
    breq off_col8
    rjmp off_col9

off_col0: cbi PORTB, 0  ; rjmp off_col_done
off_col1: cbi PORTB, 1  ; rjmp off_col_done
off_col2: cbi PORTB, 2  ; rjmp off_col_done
off_col3: cbi PORTB, 3  ; rjmp off_col_done
off_col4: cbi PORTB, 4  ; rjmp off_col_done
off_col5: cbi PORTB, 5  ; rjmp off_col_done
off_col6: cbi PORTB, 6  ; rjmp off_col_done
off_col7: cbi PORTB, 7  ; rjmp off_col_done
off_col8: cbi PORTC, 2  ; rjmp off_col_done
off_col9: cbi PORTC, 3  ; rjmp off_col_done

off_col_done:

    pop r19
    pop r18
    pop r17
    pop r16
    ret

; =========================================
; init_matrix — НАСТРОЙКА ВСЕХ ПИНОВ
; =========================================
init_matrix:
    ; Настраиваем все пины на выход
    ldi r16, 0xFF
    out DDRB, r16        ; PORTB (столбцы 0-7 + динамик)
    out DDRC, r16        ; PORTC (строки 8-9 + столбцы 8-9)
    out DDRD, r16        ; PORTD (строки 0-7)
    
    ; Выключаем все светодиоды
    clr r16
    out PORTB, r16
    out PORTC, r16
    out PORTD, r16
    
    ret

; =========================================
; init_uart — НАСТРОЙКА UART
; =========================================
init_uart:
    ; Настройка UART на 9600 бод, 8 бит, 1 стоп
    ; Для F_CPU = 16 МГц
    
    ldi r16, low(103)    ; UBRR = 103 (9600 бод)
    out UBRR0L, r16
    ldi r16, high(103)
    out UBRR0H, r16
    
    ldi r16, (1<<TXEN0) | (1<<RXEN0)  ; Включаем TX и RX
    out UCSR0B, r16
    
    ldi r16, (1<<UCSZ01) | (1<<UCSZ00) ; 8 бит данных
    out UCSR0C, r16
    
    ret

; =========================================
; print_string — ВЫВОД СТРОКИ
; =========================================
print_string:
    ; Текст после вызова
    pop r30              ; Адрес строки из стека
    pop r31
    
print_loop:
    lpm r16, Z+          ; Читаем байт из Flash
    cpi r16, 0
    breq print_done
    call uart_putc
    rjmp print_loop
print_done:
    push r31             ; Возвращаем адрес после строки
    push r30
    ret

; =========================================
; read_string — ЧТЕНИЕ СТРОКИ
; =========================================
read_string:
    ; Читаем с UART до Enter
    ldi ZL, low(filename)
    ldi ZH, high(filename)
    
read_loop:
    call uart_getc
    cpi r16, 0x0D       ; Enter?
    breq read_done
    cpi r16, 0x08       ; Backspace?
    breq read_backspace
    st Z+, r16
    call uart_putc      ; Эхо
    rjmp read_loop
read_backspace:
    ; TODO: обработка Backspace
    rjmp read_loop
read_done:
    clr r16
    st Z+, r16          ; Добавляем 0 в конец
    ret

; =========================================
; read_key_from_uart — ЧТЕНИЕ КЛАВИШИ
; =========================================
read_key_from_uart:
    call uart_getc
    ret

; =========================================
; read_hex_byte — ЧТЕНИЕ HEX-БАЙТА
; =========================================
read_hex_byte:
    ; Читает два HEX-символа и превращает в байт
    ; Возвращает в r16
    push r17
    
    call uart_getc
    call hex_to_nibble
    swap r16
    
    call uart_getc
    call hex_to_nibble
    or r16, r17
    
    pop r17
    ret

; =========================================
; hex_to_nibble — ПРЕВРАЩАЕТ HEX-СИМВОЛ В НИББЛ
; =========================================
hex_to_nibble:
    ; Вход: r16 = ASCII-символ ('0'-'9', 'A'-'F', 'a'-'f')
    ; Выход: r17 = 0-15, r16 неизменён
    
    cpi r16, '0'
    brlt hex_error
    cpi r16, '9'+1
    brlt hex_digit
    cpi r16, 'A'
    brlt hex_error
    cpi r16, 'F'+1
    brlt hex_upper
    cpi r16, 'a'
    brlt hex_error
    cpi r16, 'f'+1
    brlt hex_lower
    rjmp hex_error

hex_digit:
    subi r16, '0'
    rjmp hex_done
hex_upper:
    subi r16, 'A'-10
    rjmp hex_done
hex_lower:
    subi r16, 'a'-10
hex_done:
    mov r17, r16
    ret
hex_error:
    ldi r17, 0
    ret

; =========================================
; uart_putc — ОТПРАВКА БАЙТА В UART
; =========================================
uart_putc:
    ; Вход: r16 = байт
    push r16
uart_putc_wait:
    sbis UCSR0A, UDRE0  ; Ждём, пока освободится
    rjmp uart_putc_wait
    out UDR0, r16
    pop r16
    ret

; =========================================
; uart_getc — ПРИЁМ БАЙТА ИЗ UART
; =========================================
uart_getc:
    ; Выход: r16 = байт
uart_getc_wait:
    sbis UCSR0A, RXC0   ; Ждём, пока появится байт
    rjmp uart_getc_wait
    in r16, UDR0
    ret

; =========================================
; delay_ms — ЗАДЕРЖКА В МИЛЛИСЕКУНДАХ
; =========================================
delay_ms:
    ; r24:r25 = количество миллисекунд
    push r16
    push r17
    push r18
    
delay_ms_loop:
    call delay_1ms
    sbiw r24, 1
    brne delay_ms_loop
    
    pop r18
    pop r17
    pop r16
    ret

; =========================================
; delay_1ms — ЗАДЕРЖКА 1 МИЛЛИСЕКУНДУ
; =========================================
delay_1ms:
    ; Для F_CPU = 16 МГц
    push r16
    push r17
    
    ldi r16, 16000      ; 16 000 циклов = 1 мс
    ldi r17, 39
delay_1ms_loop:
    subi r16, 1
    sbci r17, 0
    brne delay_1ms_loop
    
    pop r17
    pop r16
    ret