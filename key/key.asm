; =========================================
; key.asm - ЦИФРОВАЯ КЛАВИАТУРА 0-9
; =========================================

.include "m328pdef.inc"

; ===== ПИНЫ ДЛЯ КНОПОК =====
.equ KEY0 = PC0
.equ KEY1 = PC1
.equ KEY2 = PD0
.equ KEY3 = PD1
.equ KEY4 = PD2
.equ KEY5 = PD3
.equ KEY6 = PD4
.equ KEY7 = PD5
.equ KEY8 = PD6
.equ KEY9 = PD7

; ===== ПИН ДЛЯ СВЕТОДИОДА (индикатор) =====
.equ LED_PIN = PB0

; =========================================
; init_keys - НАСТРОЙКА КНОПОК
; =========================================
init_keys:
    ; Настраиваем пины как входы
    cbi DDRC, KEY0
    cbi DDRC, KEY1
    cbi DDRD, KEY2
    cbi DDRD, KEY3
    cbi DDRD, KEY4
    cbi DDRD, KEY5
    cbi DDRD, KEY6
    cbi DDRD, KEY7
    cbi DDRD, KEY8
    cbi DDRD, KEY9
    
    ; Включаем подтягивающие резисторы (активный 0)
    sbi PORTC, KEY0
    sbi PORTC, KEY1
    sbi PORTD, KEY2
    sbi PORTD, KEY3
    sbi PORTD, KEY4
    sbi PORTD, KEY5
    sbi PORTD, KEY6
    sbi PORTD, KEY7
    sbi PORTD, KEY8
    sbi PORTD, KEY9
    
    ; Светодиод как выход
    sbi DDRB, LED_PIN
    
    ret

; =========================================
; read_key - ЧТЕНИЕ КНОПКИ
; =========================================
read_key:
    ; Выход: r16 = номер кнопки (0-9) или 0xFF если ничего не нажато
    
    push r17
    
    ; Проверяем кнопку 0
    sbis PINC, KEY0
    ldi r16, 0
    breq key_found
    
    ; Проверяем кнопку 1
    sbis PINC, KEY1
    ldi r16, 1
    breq key_found
    
    ; Проверяем кнопку 2
    sbis PIND, KEY2
    ldi r16, 2
    breq key_found
    
    ; Проверяем кнопку 3
    sbis PIND, KEY3
    ldi r16, 3
    breq key_found
    
    ; Проверяем кнопку 4
    sbis PIND, KEY4
    ldi r16, 4
    breq key_found
    
    ; Проверяем кнопку 5
    sbis PIND, KEY5
    ldi r16, 5
    breq key_found
    
    ; Проверяем кнопку 6
    sbis PIND, KEY6
    ldi r16, 6
    breq key_found
    
    ; Проверяем кнопку 7
    sbis PIND, KEY7
    ldi r16, 7
    breq key_found
    
    ; Проверяем кнопку 8
    sbis PIND, KEY8
    ldi r16, 8
    breq key_found
    
    ; Проверяем кнопку 9
    sbis PIND, KEY9
    ldi r16, 9
    breq key_found
    
    ; Ничего не нажато
    ldi r16, 0xFF
    
key_found:
    pop r17
    ret

; =========================================
; wait_key - ЖДЁМ НАЖАТИЯ КНОПКИ
; =========================================
wait_key:
    ; Выход: r16 = номер кнопки (0-9)
    
    push r17
    
wait_loop:
    call read_key
    cpi r16, 0xFF
    breq wait_loop
    
    ; Ждём отпускания (антидребезг)
    call delay_20ms
    
    ; Проверяем, что кнопка всё ещё нажата
    call read_key
    cpi r16, 0xFF
    breq wait_loop      ; Если отпущена — дребезг
    
    ; Ждём, пока отпустят
wait_release:
    call read_key
    cpi r16, 0xFF
    brne wait_release
    
    call delay_20ms     ; Дребезг при отпускании
    
    pop r17
    ret

; =========================================
; key_to_ascii - ПРЕВРАЩАЕМ НОМЕР В ASCII
; =========================================
key_to_ascii:
    ; Вход: r16 = номер (0-9)
    ; Выход: r16 = ASCII-код ('0' - '9')
    
    subi r16, -'0'      ; добавляем '0' (0x30)
    ret

; =========================================
; delay_20ms - ЗАДЕРЖКА 20 МС
; =========================================
delay_20ms:
    ; Для F_CPU = 16 МГц
    push r16
    push r17
    push r18
    
    ldi r18, 20         ; 20 мс
delay_20ms_loop:
    call delay_1ms
    dec r18
    brne delay_20ms_loop
    
    pop r18
    pop r17
    pop r16
    ret

; =========================================
; delay_1ms - ЗАДЕРЖКА 1 МС
; =========================================
delay_1ms:
    push r16
    push r17
    
    ldi r16, 16000
    ldi r17, 39
delay_1ms_inner:
    subi r16, 1
    sbci r17, 0
    brne delay_1ms_inner
    
    pop r17
    pop r16
    ret

; =========================================
; ОСНОВНОЙ ЦИКЛ (пример использования)
; =========================================
main:
    call init_keys
    call init_uart
    
loop:
    call wait_key        ; Ждём нажатия
    call key_to_ascii    ; Превращаем в ASCII
    call uart_putc       ; Отправляем по UART
    
    ; Зажигаем светодиод на 100 мс
    sbi PORTB, LED_PIN
    call delay_100ms
    cbi PORTB, LED_PIN
    
    rjmp loop

; =========================================
; delay_100ms - ЗАДЕРЖКА 100 МС
; =========================================
delay_100ms:
    push r16
    ldi r16, 100
delay_100ms_loop:
    call delay_1ms
    dec r16
    brne delay_100ms_loop
    pop r16
    ret

; =========================================
; init_uart - НАСТРОЙКА UART
; =========================================
init_uart:
    ldi r16, low(103)
    out UBRR0L, r16
    ldi r16, high(103)
    out UBRR0H, r16
    
    ldi r16, (1<<TXEN0)
    out UCSR0B, r16
    
    ldi r16, (1<<UCSZ01) | (1<<UCSZ00)
    out UCSR0C, r16
    
    ret

; =========================================
; uart_putc - ОТПРАВКА БАЙТА
; =========================================
uart_putc:
    push r16
uart_putc_wait:
    sbis UCSR0A, UDRE0
    rjmp uart_putc_wait
    out UDR0, r16
    pop r16
    ret