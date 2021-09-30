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

;
; States constants
.equ INIT_STATE = 0x01
.equ SHOWING_STATE = 0x02
.equ POLLING_STATE = 0x03
.equ COMPLETION_STATE = 0x04

.macro init_stack_p         ; Setup stack pointer
  ldi @0, low(@1)
  out SPL, @0
.endm

.macro outi                 ; Out to i/o reg
  push r16
  ldi r16, @1
  out @0, r16
  pop r16
.endm

.macro stsi                 ; Write to SRAM
  push r16
  ldi r16, @1
  sts @0, r16
  pop r16
.endm

.macro set_state
  push r16
  lds r16, CURRENT_STATE_ADDRESS

  sts PREVIOUS_STATE_ADDRESS, r16
  stsi CURRENT_STATE_ADDRESS, @0
  pop r16
.endm

.dseg                       ; Data segment
.org	SRAM_START

CURRENT_STATE_ADDRESS:  .byte	0x01
PREVIOUS_STATE_ADDRESS: .byte 0x02

.cseg                       ; Code segment
.org 0x00                   ; Start program at 0x00

setup:                      ; Setup program
  init_stack_p r16, RAMEND  ; Init stack pointer of MCU
  set_state INIT_STATE      ; Turn MCU state to initialization

loop:                       ; Program loop
  lds r16, CURRENT_STATE_ADDRESS
  init:                     ; Init state
    cpi r16, INIT_STATE
    brne showing
    rcall MCU_Init
    set_state SHOWING_STATE
  showing:                  ; Showing state
    cpi r16, SHOWING_STATE
    brne polling
    rcall effect_1
  polling:                  ; Polling state
    cpi r16, POLLING_STATE
    brne completion
  completion:
    cpi r16, COMPLETION_STATE ; Completion state
    brne default
  default:                  ; Do nothing
rjmp loop

effect_1:                   ; Shift bits of an leds in port every 50ms
  push r17
  push r18
  push r19
  push r20

  in r20, LED_PORT

  outi LED_PORT, 0xf1
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

  outi LED_PORT, 0xf8
  rcall delay_50ms
  ldi r17, 0x08
  ldi r19, 3
  _eff_1_shift_r:            ; Shift bits to right loop
    ldi r18, 0xf0
    lsr r17
    add r18, r17
    out LED_PORT, r18
    rcall delay_50ms
    dec r19
    brne _eff_1_shift_r

  ;
  ; Out saved PORT values
  out LED_PORT, r20

  pop r20
  pop r19
  pop r18
  pop r17
ret

MCU_Init:
  rcall init_ports
ret

init_ports:                 ; Init MCU ports
  push r16

  ; Setup PORTA 
  ldi r16, 0x0f
  out DDRA, r16             ; Set directions of leds and buttons
  swap r16
  out PORTA, r16            ; Set low signal on leds and pull-up on buttons

  ; Setup PORTB
  sbi DDRB, BUZZ_PIN        ; Set direction of buzzer pin to output
  cbi PORTB, BUZZ_PIN       ; Set low signal on buzzer

  pop r16
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