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

.equ TRUE = 1
.equ FALSE = 0

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

;
; @0 - SRAM Address
; @1 - Data to write
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

.macro set_btn_flag
  push r16
  ldi r16, @0
  sts BTN_FLAGS_ADDRESS, r16
  pop r16
.endm

.macro clr_btn_flag
  push r16
  lds r16, BTN_FLAGS_ADDRESS
  cbr r16, @0
  sts BTN_FLAGS_ADDRESS, r16
  pop r16
.endm

.dseg                       ; Data segment
.org	SRAM_START

;
; MCU Global states
CURRENT_STATE_ADDRESS:  .byte	0x01
PREVIOUS_STATE_ADDRESS: .byte 0x01

;
; Button flags
BTN_FLAGS_ADDRESS: .byte 0x01

.cseg                       ; Code segment
.org 0x00                   ; Start program at 0x00

rjmp start
rjmp PCINT4_ISR

;
; Interrupt service routines
PCINT4_ISR:                 ; First button
  set_btn_flag 0x01
reti

ldi r18, 0x00
sts BTN_FLAGS_ADDRESS, r18

;
; Program start at reset
start:
  init_stack_p r16, RAMEND  ; Init stack pointer of MCU
  set_state INIT_STATE      ; Turn MCU state to initialization

loop:                       ; Program loop
  lds r16, CURRENT_STATE_ADDRESS
  init:                     ; Init state
    cpi r16, INIT_STATE
    brne showing
    rcall MCU_Init
    ; rcall delay_1s
    set_state SHOWING_STATE
  showing:                  ; Showing state
    cpi r16, SHOWING_STATE
    brne polling

    lds r18, BTN_FLAGS_ADDRESS
    cpi r18, 0x01
    brne led_off
    led_on:
      sbi LED_PORT, 2
      rcall delay_50ms
      rjmp polling
    led_off:
      cbi LED_PORT, 2
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
  rcall init_interrupts
  rcall delay_before_start  ; Init MCU and delay before start main program
ret

delay_before_start:
  ldi r17, 6
  _init_loop_loading:
    rcall effect_1
    dec r17
    brne _init_loop_loading
  rcall delay_1s
ret

init_interrupts:
  push r16

  ;
  ; Enable Port Change Interrupt
  ldi r16, (1<<PCIE0)
  out GIMSK, r16

  ;
  ; Set Pin Change Mask Register
  ldi r16, (1<<PCINT4) | (1<<PCINT5) | (1<<PCINT6) | (1<<PCINT7)
  out PCMSK0, r16
  clr r16

  sei                       ; Enable Global Interrupts

  pop r16
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

delay_50ms:                 ; For 1MHz frequency
  push r18
  push r19

  ldi r18, 65    
  ldi r19, 239     
    _loop_d_50ms: 
      dec  r19          
      brne _loop_d_50ms 
      dec  r18          
      brne _loop_d_50ms 
      nop 
  pop r19
  pop r18              
ret

delay_1s:                   ; For 1MHz frequency 
  .equ outer_count = 100
  .equ inner_count = 2499

  push r24
  push r25

  ldi r18, outer_count       
    _reset:                   
      ldi r24, low(inner_count)
      ldi r25, high(inner_count)
    _loop:                  
      sbiw r24, 1             
      brne _loop             

      dec r18                 
      brne _reset             
      ldi r18, outer_count
  pop r25
  pop r24
ret

info: .db "Memory led game. Written by Sergey Yarkov 27.09.2021"