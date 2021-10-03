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
.equ LED_PIN = PINA   
.equ LED_PIN_0 = PINA0      
.equ LED_PIN_1 = PINA1      
.equ LED_PIN_2 = PINA2     
.equ LED_PIN_3 = PINA3      

;
; Buttons constants
.equ SW_DIR = DDRA
.equ SW_PORT = PORTA
.equ SW_PIN = PINA
.equ SW_PIN_4 = PINA4
.equ SW_PIN_5 = PINA5
.equ SW_PIN_6 = PINA6
.equ SW_PIN_7 = PINA7

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

;
; SW Flags states constants
.equ SW_FLAG_1 = 0xe0
.equ SW_FLAG_2 = 0xd0
.equ SW_FLAG_3 = 0xb0
.equ SW_FLAG_4 = 0x70

.macro init_stack_p         ; Setup stack pointer
  ldi @0, low(@1)
  out SPL, @0
.endm

;
; @0 - I/O Register
; @1 - Data to write
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

;
; @0 - New state
.macro set_state
  push r16
  lds r16, CURRENT_STATE_ADDRESS

  sts PREVIOUS_STATE_ADDRESS, r16
  stsi CURRENT_STATE_ADDRESS, @0
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
SW_FLAGS_ADDRESS: .byte 0x01

.cseg                       ; Code segment
.org 0x00                   ; Start program at 0x00

;
; Setup vectors
rjmp start                  ; Program start at RESET vector
reti                        ; External Interrupt Request 0 / inactive
rjmp PCINT0_vect            ; Pin Change Interrupt Request 0 / active
reti                        ; Pin Change Interrupt Request 1 / inactive
reti                        ; Watchdog Time-out / inactive
reti                        ; Timer/Counter1 Capture Event / inactive
reti                        ; Timer/Counter1 Compare Match A / inactive
reti                        ; Timer/Counter1 Compare Match B / inactive
reti                        ; Timer/Counter1 Overflow / inactive
reti                        ; Timer/Counter0 Compare Match A / inactive
reti                        ; Timer/Counter0 Compare Match B / inactive
reti                        ; Timer/Counter0 Overflow / inactive
reti                        ; Analog Comparator / inactive
reti                        ; ADC Conversion Complete / inactive
reti                        ; EEPROM Ready / inactive
reti                        ; USI START / inactive
reti                        ; USI Overflow / inactive

;
; Interrupt service routines
PCINT0_vect:                 
  push r17
  push r18
  ; // TODO update flag only in POLLING state of MCU
  in r18, SREG
  in r17, PINA              ; Load current pins status of PINA
  andi r17, 0xf0            ; Get pins status of only buttons
  rcall delay_50ms
  sts SW_FLAGS_ADDRESS, r17 ; Update flag status in SRAM
  out SREG, r18

  pop r18
  pop r17
reti

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
    
    lds r18, SW_FLAGS_ADDRESS
    led_1:
      cpi r18, SW_FLAG_1
      brne led_off_1
      led_on_1:
        sbi LED_PORT, 0
        rjmp led_2
      led_off_1:
        cbi LED_PORT, 0
    led_2:
      cpi r18, SW_FLAG_2
      brne led_off_2
      led_on_2:
        sbi LED_PORT, 1
        rjmp led_3
      led_off_2:
        cbi LED_PORT, 1
    led_3:
      cpi r18, SW_FLAG_3
      brne led_off_3
      led_on_3:
        sbi LED_PORT, 2
        rjmp led_4
      led_off_3:
        cbi LED_PORT, 2
    led_4:
      cpi r18, SW_FLAG_4
      brne led_off_4
      led_on_4:
        sbi LED_PORT, 3
        rjmp polling
      led_off_4:
        cbi LED_PORT, 3
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
  ;
  ; Enable Port Change Interrupt
  ldi r16, (1<<PCIE0)
  out GIMSK, r16

  ;
  ; Set Pin Change Mask Register
  ldi r16, (1<<PCINT4) | (1<<PCINT5)| (1<<PCINT6) | (1<<PCINT7)
  out PCMSK0, r16

  clr r16

  sei                       ; Enable Global Interrupts
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