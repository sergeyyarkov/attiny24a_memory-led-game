; 
; Project name: memory-led-game
; Description: Simple memory game using leds
; Source code: https://github.com/sergeyyarkov/attiny24a_memory-led-game
; Device: ATtiny24A
; Package: 14-pin-PDIP_SOIC
; Assembler: gavrasm v5.0
; Clock frequency: 8MHz with CKDIV8
; Fuses: lfuse: 0x42, hfuse: 0xDF, efuse: 0xFF, lock:0xFF
;
; Written by Sergey Yarkov 27.09.2021

.device ATtiny24A           ; Setup device name
.list                       ; Enable listing

;
; LEDS constants
.equ LED_DIR = DDRA     
.equ LED_PORT = PORTA      
.equ LED_PIN_0 = PINA0      
.equ LED_PIN_1 = PINA1      
.equ LED_PIN_2 = PINA2     
.equ LED_PIN_3 = PINA3      

;
; Buttons constants
.equ BTN_DIR = DDRA
.equ BTN_PORT = PORTA
.equ BTN_PIN_4 = PINA4
.equ BTN_PIN_5 = PINA5
.equ BTN_PIN_6 = PINA6
.equ BTN_PIN_7 = PINA7

;
; Buzzer constants
.equ BUZZ_DIR = DDRB
.equ BUZZ_PORT = PORTB
.equ BUZZ_PIN = PINB2

.macro init_stack_p         ; Setup stack pointer
  ldi @0, low(@1)
  out SPL, @0
.endm

.org 0x00                   ; Start program at 0x00
.cseg                       ; Code segment

main:                       ; Start up program
  init_stack_p r16, RAMEND
  rcall init_ports          ; Initialize MCU ports

loop:                       ; Program loop
  rcall effect_1  
  rjmp loop

effect_1:
  push r17
  push r18
  push r19
  push r20

  in r20, LED_PORT

  ;
  ; Set first led to high
  ldi r17, 0xf1
  out LED_PORT, r17
  rcall delay_50ms

  ldi r17, 0x01
  ldi r19, 3
  _eff_1_shift_l:            ; Shift bits to left loop
    ldi r18, 0xf0
    lsl r17
    add r18, r17
    out LED_PORT, r18
    rcall delay_50ms
    dec r19
    brne _eff_1_shift_l


  ;
  ; Set first led to high
  ldi r17, 0xf8
  out LED_PORT, r17
  rcall delay_50ms

  ;
  ; Shift remaining bits
  ldi r17, 0xf8
  ldi r19, 3
  _eff_1_shift_r:
    ldi r18, 0xf0
    lsr r17
    sub r18, r17
    out LED_PORT, r18
    rcall delay_50ms
    dec r19
    brne _eff_1_shift_r

  ;
  ; Out saved PORT values
  out LED_PORT, r20

  pop r17
  pop r18
  pop r19
  pop r20
ret

init_ports:                 ; Init MCU ports
  ; Setup PORTA 
  ldi r16, 0x0f
  out DDRA, r16             ; Set directions of leds and buttons
  swap r16
  out PORTA, r16            ; Set low signal on leds and pull-up on buttons

  ; Setup PORTB
  sbi DDRB, BUZZ_PIN        ; Set direction of buzzer pin to output
  cbi PORTB, BUZZ_PIN       ; Set low signal on buzzer
  clr r16
ret 

delay_1s:                   ; For 1MHz frequency 
.equ outer_count = 100
.equ inner_count = 2499

ldi r18, outer_count 
  _reset_d_1s:                   
    ldi r24, low(inner_count)
    ldi r25, high(inner_count)
  _loop_d_1s:                  
    sbiw r24, 1            
    brne _loop_d_1s

    dec r18                
    brne _reset_d_1s            
    ldi r18, outer_count    
ret

delay_50ms:
push r18
push r19

ldi r18, 65     ; 1c
ldi r19, 239     ; 1c
  _loop_d_50ms: 
    dec  r19          ; 1c
    brne _loop_d_50ms ; 2 or 1c = 665c
    dec  r18          ; 1c
    brne _loop_d_50ms ; 2 or 1c
    nop 
pop r19
pop r18              
ret

info: .db "Memory led game. Written by Sergey Yarkov 27.09.2021"
