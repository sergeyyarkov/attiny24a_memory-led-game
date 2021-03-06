; 
; Project name: memory-led-game
; Description: Simple memory game using leds
; Source code: https://github.com/sergeyyarkov/attiny24a_memory-led-game
; Device: ATtiny24A
; Package: 14-pin-PDIP_SOIC
; Assembler: AVR macro assembler 2.2.7
; Clock frequency: 8MHz with CKDIV8
; Fuses: lfuse: 0x42, hfuse: 0xDF, efuse: 0xFF, lock:0xFF
;
; Written by Sergey Yarkov 27.09.2021

.include "def.inc"					; Include type definitions of MCU
.list                       		; Enable listing

;
; Registers
.def seq_length_r 		= r10		; Current length of sequence
.def wdt_counter 		= r11		; Counter for wathdog timer
.def temp_r 			= r16		; Temp general register A
.def temp_r_b 			= r23		; Temp general register B
.def temp_r_c 			= r26		; Temp general register C
.def mcu_state_r 		= r17		; Current state of MCU. This register will be compared in an main loop
.def delay_counter_r 	= r19 		; Register for storing delay counter
.def poll_step_r 		= r20		; Current poll step for checking the input with answer

;
; LEDS constants
.equ LED_DIR 	= DDRA     
.equ LED_PORT 	= PORTA   
.equ LED_PIN 	= PINA   
.equ LED_PIN_0 	= PINA0      
.equ LED_PIN_1 	= PINA1      
.equ LED_PIN_2 	= PINA2     
.equ LED_PIN_3 	= PINA3      

;
; Buttons constants
.equ SW_DIR 	= DDRA
.equ SW_PORT 	= PORTA
.equ SW_PIN 	= PINA
.equ SW_PIN_4 	= PINA4
.equ SW_PIN_5 	= PINA5
.equ SW_PIN_6 	= PINA6
.equ SW_PIN_7 	= PINA7

;
; Buzzer constants
.equ BUZZ_DIR 	= DDRB
.equ BUZZ_PORT 	= PORTB
.equ BUZZ_PIN 	= PINB2

;
; States constants
.equ INIT_STATE 	= 0x01
.equ SHOWING_STATE 	= 0x02
.equ POLLING_STATE 	= 0x03

;
; SW Flags states constants
.equ SW_FLAG_1 = 0xe0
.equ SW_FLAG_2 = 0xd0
.equ SW_FLAG_3 = 0xb0
.equ SW_FLAG_4 = 0x70

.equ SEQ_LENGTH = 2

; Value that stored in OCR0A for each tone
; 880Hz = 71
; 785Hz = 80
; 590Hz = 105
; 440Hz = 142

.include "macros.asm"       ; Include macros

.dseg                       ; Data segment
.org	SRAM_START

; MCU Global states addresses
CURRENT_STATE_ADDRESS:  		.byte	0x01
PREVIOUS_STATE_ADDRESS: 		.byte 	0x01

; Button flags
SW_FLAGS_ADDRESS: 				.byte	0x01

.cseg                       ; Code segment
.org 0x00

; MCU vectors
rjmp 	RESET_vect			; Program start at RESET vector
reti                        ; External Interrupt Request 0 / inactive
rjmp 	PCINT0_vect			; Pin Change Interrupt Request 0 / active
reti                        ; Pin Change Interrupt Request 1 / inactive
rjmp 	WDT_vect			; Watchdog Time-out / active
reti                        ; Timer/Counter1 Capture Event / inactive
reti                        ; Timer/Counter1 Compare Match A / inactive
reti                        ; Timer/Counter1 Compare Match B / inactive
reti                        ; Timer/Counter1 Overflow / inactive
reti						; Timer/Counter0 Compare Match A / inactive
reti                        ; Timer/Counter0 Compare Match B / inactive
rjmp 	TIM0_OVF_vect		; Timer/Counter0 Overflow / active
reti                        ; Analog Comparator / inactive
reti                        ; ADC Conversion Complete / inactive
reti                        ; EEPROM Ready / inactive
reti                        ; USI START / inactive
reti                        ; USI Overflow / inactive

; watchdog time-out interrupt handler
WDT_vect:
  	inc 	wdt_counter
	in 		temp_r_c, WDTCSR
	ori 	temp_r_c, (1<<WDIE)
	out 	WDTCSR, temp_r_c  
	reti

; pin change on button interrupt handler
PCINT0_vect:
	push 	r17
	push 	r18
	clr wdt_counter
	in 		r18, MCUCR
	cbr 	r18, (1<<SE)
	; turn off the sleep mode
	out 	MCUCR, r18
	; save status register            
	in 		r18, SREG
	lds 	mcu_state_r, CURRENT_STATE_ADDRESS      
	cpi 	mcu_state_r, POLLING_STATE
	; do not change button flags unless in POLLING state of mcu
	brne 	quit
	in 		r17, PINA
	; get pins status of only buttons
	andi 	r17, 0xf0
	; button debounce
	rcall 	delay_20ms
	; update flag status in SRAM
	sts 	SW_FLAGS_ADDRESS, r17 
	out 	SREG, r18

	quit:
	pop 	r18
	pop 	r17
	reti

; random byte generator
TIM0_OVF_vect:
	push 	temp_r_b
	in 		temp_r_b, SREG
	
	rjmp 	gen_start

  	ldi 	temp_r, 168
  	in 		r21, TCNT0
  
  	gen_start:
	eor 	temp_r, r21
	swap 	temp_r
	add 	r21, temp_r
	out 	SREG, temp_r_b
	pop 	temp_r_b
	reti

; initialize MCU
MCU_Init:
	rcall 	init_ports
	rcall 	init_interrupts
	rcall 	init_buzzer
	
	; init important registers for game
	ldi 	delay_counter_r, 0xff
	ldi 	poll_step_r, 1
	ldi 	temp_r_c, SEQ_LENGTH
	mov 	seq_length_r, temp_r_c
	clr 	ZH
	ldi 	ZL, $80
	
	; delay before start main loop
	rcall 	MCU_Delay
	rcall 	init_wdt
	rcall 	init_sm

	sei
	ret

MCU_Delay:
	ldi 	temp_r_b, 3
	_init_loop_loading:
		rcall 	effect_1
		dec 	temp_r_b
		brne 	_init_loop_loading
		rcall 	delay_1s
		clr 	temp_r_b
	ret

WDT_off:
	cli
    wdr
    ; clear WDRF in MCUSR
    ldi     temp_r, (0<<WDRF)
    out     MCUSR, r16
    ; write logical one to WDCE and WDE
    ; keep old prescaler setting to prevent unintentional Watchdog Reset
    in      temp_r, WDTCSR
    ori     temp_r, (1<<WDCE) | (1<<WDE)
    out     WDTCSR, temp_r
    ; turn off WDT
    ldi     temp_r, (0<<WDE)
    out     WDTCSR, temp_r
	sei
    ret  

; program start at reset vector
RESET_vect:
  init_stack_p 	temp_r, RAMEND
  set_state 	INIT_STATE

; main program loop
loop:
	ldi 	temp_r_c, 20
	cp 		wdt_counter, temp_r_c
	brsh 	_mcu_sleep
	rjmp 	feed
	_mcu_sleep:
		clr wdt_counter
		rcall	WDT_off
		in		temp_r_c, MCUCR
		sbr 	temp_r_c, (1<<SE)
		out 	MCUCR, temp_r_c
		cli
		sleep
	feed:
  		lds 	mcu_state_r, CURRENT_STATE_ADDRESS
	; init state
  	init:
		cpi 	mcu_state_r, INIT_STATE
		brne 	showing
		rcall 	MCU_Init
		set_state SHOWING_STATE

	; showing state
  	showing:
		cpi 	mcu_state_r, SHOWING_STATE
		brne 	polling
		; generate sequence and save answer to SRAM
		rcall 	show_sequence
		set_state POLLING_STATE

	; polling state
	polling:
		cpi 	mcu_state_r, POLLING_STATE
		brne 	default
		btn_1:
			lds		r18, SW_FLAGS_ADDRESS
			cpi 	r18, SW_FLAG_1
			brne 	btn_2
		led_on_1:
			outi 	OCR0A, 142
			sbi 	LED_PORT, 0
			sbi 	BUZZ_DIR, BUZZ_PIN
			rcall 	btn_handler    
			cbi 	LED_PORT, 0
			cbi 	BUZZ_DIR, BUZZ_PIN
			rjmp btn_1

		btn_2:
			lds 	r18, SW_FLAGS_ADDRESS
			cpi 	r18, SW_FLAG_2
			brne 	btn_3
		led_on_2:
			outi 	OCR0A, 71
			sbi 	LED_PORT, 1
			sbi 	BUZZ_DIR, BUZZ_PIN
			rcall 	btn_handler
			cbi 	LED_PORT, 1
			cbi 	BUZZ_DIR, BUZZ_PIN
			rjmp 	btn_2

		btn_3:
			lds 	r18, SW_FLAGS_ADDRESS
			cpi 	r18, SW_FLAG_3
			brne 	btn_4
		led_on_3:
			outi 	OCR0A, 105
			sbi 	LED_PORT, 2
			sbi 	BUZZ_DIR, BUZZ_PIN
			rcall 	btn_handler
			cbi 	LED_PORT, 2
			cbi 	BUZZ_DIR, BUZZ_PIN
			rjmp btn_3

		btn_4:
			lds 	r18, SW_FLAGS_ADDRESS
			cpi 	r18, SW_FLAG_4
			brne 	default
		led_on_4:
			outi 	OCR0A, 80
			sbi 	LED_PORT, 3
			sbi 	BUZZ_DIR, BUZZ_PIN
			rcall 	btn_handler
			cbi 	LED_PORT, 3
			cbi 	BUZZ_DIR, BUZZ_PIN
			rjmp 	btn_4

  	default:									
  		rcall 	OCR0A_reset
	rjmp	loop

; check the input value with answer in SRAM
btn_handler:
	push 	r18
	rcall 	delay_50ms
  	rcall 	delay_50ms
  	rcall 	delay_50ms
  	in 		temp_r_c, PINA
  	mov 	r25, temp_r_c           
	andi 	temp_r_c, 0xf0
	andi 	r25, 0x0f
	clr 	temp_r_c
	sts 	SW_FLAGS_ADDRESS, temp_r_c 
	
	ld 		r24, Z+
	; check answer
	cp 		r25, r24
	; game over
	brne 	_game_over
	
	mov 	r18, seq_length_r
	cp 		r18, poll_step_r
	breq 	_btn_handler_exit_state
	
	inc 	poll_step_r
  
	rjmp 	_btn_handler_exit
	
	_game_over:
		pop 	r18
		rcall 	effect_1
		ldi 	delay_counter_r, 0xff
		ldi 	temp_r_c, SEQ_LENGTH
		dec 	temp_r_c
		mov 	seq_length_r, temp_r_c
		rcall 	reset_game
		ret
	
	_btn_handler_exit_state:
		pop 	r18
		ldi 	temp_r, 0xf0
		out 	LED_PORT, temp_r
		cbi 	BUZZ_DIR, BUZZ_PIN
		rcall 	delay_50ms
		rcall 	effect_2
		rcall 	reset_game
		ret

	_btn_handler_exit:
		pop r18
		ret
	ret

reset_game:
  	clr 	ZH
  	ldi 	ZL, $80
  	cbi 	BUZZ_DIR, BUZZ_PIN
  	ldi 	temp_r, 0xf0
  	out 	LED_PORT, temp_r
  	rcall 	delay_1s
  	set_state SHOWING_STATE
  	ldi 	poll_step_r, 1
  	inc 	seq_length_r
	ret

; generate random sequence of bytes for leds and save answer to SRAM
gen_ran_seq:
	mov 	temp_r_b, seq_length_r
	clr 	YH
	ldi 	YL, $80
	
	_gen_ran_loop:
		; delay is required
		rcall 	delay_50ms
		mov 	r22, r21
		cpi 	r22, 70
		brlo 	_gen_answ_1
		cpi 	r22, 140
		brlo 	_gen_answ_2
		cpi 	r22, 200
		brlo 	_gen_answ_3
		cpi 	r22, 255
		brlo 	_gen_answ_4
	  
	_gen_answ_1:
		ldi 	temp_r_c, 0x01
		rjmp 	_gen_ran_write

	_gen_answ_2:
		ldi 	temp_r_c, 0x02
		rjmp 	_gen_ran_write

	_gen_answ_3:
		ldi 	temp_r_c, 0x04
		rjmp 	_gen_ran_write

	_gen_answ_4:
		ldi 	temp_r_c, 0x08

	_gen_ran_write:
		st 		Y+, temp_r_c
		dec 	temp_r_b
		cpi 	temp_r_b, 0
		brne 	_gen_ran_loop
		nop
	ret

show_sequence:
	; answer stored in SRAM in addr $80:{SEQ_LENGTH}
	rcall 	gen_ran_seq
	show_start:
		mov 	temp_r_b, seq_length_r

		clr 	YH
		ldi 	YL, $80
	
	_sequence_loop:
		cpi 	temp_r_b, 0
		breq 	_seq_quit
		ld 		temp_r_c, Y+
		cpi 	temp_r_c, 0x01
		breq 	beep_1
		cpi 	temp_r_c, 0x02
		breq 	beep_2
		cpi 	temp_r_c, 0x04
		breq 	beep_3
		cpi 	temp_r_c, 0x08
		breq 	beep_4
		
	beep_1:
		beep_led_1
		rcall 	OCR0A_reset
		rjmp 	beep_quit

	beep_2:
		beep_led_2
		rcall 	OCR0A_reset
		rjmp 	beep_quit

	beep_3:
		beep_led_3
		rcall 	OCR0A_reset
		rjmp 	beep_quit

	beep_4:
		beep_led_4
		rcall 	OCR0A_reset

	beep_quit:
		rcall 	delay
		dec 		temp_r_b
		cpi 		temp_r_b, 0
		brne 		_sequence_loop

  	_seq_quit:
		rcall 	dec_delay_counter
		rcall 	delay_50ms
	ret

; this function need to set the OCR0A register to 0xff for overflow interrupt
OCR0A_reset:
	push 	temp_r_b
	ldi 	temp_r_b, 0xff
	out 	OCR0A, temp_r_b
	pop 	temp_r_b
	ret

dec_delay_counter:
	subi 	delay_counter_r, 10
  	cpi 	delay_counter_r, 40
  	brlo 	_reset_counter
  	ret
  	_reset_counter:
    	ldi 	delay_counter_r, 0xff
	ret

effect_1:                   ; Shift bits of an leds in port every 50ms
	push 	r17
	push 	r18
	push 	r19
	push 	r20

  	in r20, LED_PORT

  	outi 	LED_PORT, 0xf1
  	rcall 	delay_50ms
  	ldi 	r17, 0x01
  	ldi 	r19, 3

	; shift bits to left loop
  	_eff_1_shift_l:
		ldi 	r18, 0xf0
		lsl 	r17
		add 	r18, r17
		out 	LED_PORT, r18
		rcall 	delay_50ms
		dec 	r19
		brne 	_eff_1_shift_l

		outi 	LED_PORT, 0xf8
		rcall 	delay_50ms
		ldi 	r17, 0x08
		ldi 	r19, 3

	; shift bits to right loop
  	_eff_1_shift_r:
		ldi 	r18, 0xf0
		lsr 	r17
		add 	r18, r17
		out 	LED_PORT, r18
		rcall 	delay_50ms
		dec 	r19
		brne 	_eff_1_shift_r


  	; out saved PORT values
  	out 	LED_PORT, r20
  	pop 	r20
  	pop 	r19
  	pop 	r18
  	pop 	r17
	ret

effect_2:
  	outi 	OCR0A, 142
  	sbi 	LED_PORT, 0
  	sbi 	BUZZ_DIR, BUZZ_PIN
  	rcall 	delay_50ms
  	rcall 	delay_50ms
  	cbi 	LED_PORT, 0
  	cbi 	BUZZ_DIR, BUZZ_PIN

  	outi 	OCR0A, 105
  	sbi 	LED_PORT, 1
  	sbi 	BUZZ_DIR, BUZZ_PIN
  	rcall 	delay_50ms
  	rcall 	delay_50ms
  	cbi 	LED_PORT, 1
  	cbi 	BUZZ_DIR, BUZZ_PIN

  	outi 	OCR0A, 80
  	sbi 	LED_PORT, 2
  	sbi 	BUZZ_DIR, BUZZ_PIN
  	rcall 	delay_50ms
  	rcall 	delay_50ms
  	cbi 	LED_PORT, 2
  	cbi 	BUZZ_DIR, BUZZ_PIN

  	outi 	OCR0A, 71
  	sbi 	LED_PORT, 3
  	sbi 	BUZZ_DIR, BUZZ_PIN
  	rcall 	delay_50ms
  	rcall 	delay_50ms
  	cbi 	LED_PORT, 3
  	cbi 	BUZZ_DIR, BUZZ_PIN
	ret

init_interrupts:
  	; enable Port Change Interrupt
  	ldi 	temp_r, (1<<PCIE0)
  	out 	GIMSK, temp_r

	; set Pin Change Mask Register
  	ldi 	temp_r, (1<<PCINT4) | (1<<PCINT5)| (1<<PCINT6) | (1<<PCINT7)
  	out 	PCMSK0, temp_r

  	clr 	temp_r
	ret

init_buzzer:
  	cbi 	BUZZ_DIR, BUZZ_PIN
  
  	; setup timer
  	ldi 	temp_r, (1<<COM0A0) | (1<<WGM01)
	; set CTC timer mode and toggle OC0A pin on Compare Match
  	out 	TCCR0A, temp_r

  	ldi 	temp_r, 255
  	out 	OCR0A, temp_r

  	ldi 	temp_r, (1<<CS01)
  	; prescale on 8
	out 	TCCR0B, temp_r
  
  	ldi 	temp_r, (1<<TOIE0)
	; enable Timer/Counter0 Overflow Interrupt
  	out 	TIMSK0, temp_r
	ret

init_ports:                 	; Init MCU ports 
	; setup PORTA
  	ldi 	temp_r, 0x0f
	; set directions of leds and buttons
  	out 	DDRA, temp_r
  	swap 	temp_r
	; set low signal on leds and pull-up on buttons
  	out 	PORTA, temp_r

  	; setup PORTB
  	sbi 	DDRB, BUZZ_PIN        	; Set direction of buzzer pin to output
  	cbi 	PORTB, BUZZ_PIN       	; Set low signal on buzzer
	ret

init_sm:
    in      temp_r, MCUCR
    ori     temp_r, (1<<SM1)
    ; config sleep mode to power-down
    out     MCUCR, temp_r
    ret

init_wdt:
	cli
	wdr
    
    in		temp_r, WDTCSR
    ori     temp_r, (1<<WDCE) | (1<<WDE)
    ; allow changing the watchdog bits and enable watchdog
    out     WDTCSR, temp_r

    ldi     temp_r, (1<<WDE) | (1<<WDIE) | (1<<WDP2) | (1<<WDP0)
    ; config watchdog to interrupt mode and setup prescaler (0.5 sec)
    out     WDTCSR, temp_r
    sei
	ret

delay:                      	; For 1MHz frequency
  	push 	r18
  	push 	r20
  	ldi 	r18, 255
  	mov 	r20, delay_counter_r
  	_delay_loop:
    nop
    dec 	r18
    brne 	_delay_loop
    nop
    dec 	r20
    brne 	_delay_loop
    nop
  	pop 	r20
  	pop 	r18
	ret

delay_20ms:
  	push 	r18
  	push 	r19

  	ldi 	r18, 26  
  	ldi 	r19, 249   
    _loop_d_20ms: 
		dec  	r19          
		brne 	_loop_d_20ms 
		dec  	r18          
		brne 	_loop_d_20ms 
		pop 	r19
		pop 	r18
	ret

delay_50ms:                 	; For 1MHz frequency
  	push 	r18
  	push 	r19

  	ldi 	r18, 65    
  	ldi 	r19, 239   
    _loop_d_50ms: 
		dec  	r19          
		brne 	_loop_d_50ms 
		dec  	r18          
		brne 	_loop_d_50ms 
		nop 
		pop 	r19
		pop 	r18              
	ret


delay_1s:                   ; For 1MHz frequency 
	push 	r24
	push 	r25

  	.equ outer_count = 100
  	.equ inner_count = 2499

  	ldi 	r18, outer_count       
	_reset:                   
  		ldi 	r24, low(inner_count)
  		ldi 	r25, high(inner_count)
	_loop:                  
		sbiw 	r24, 1             
		brne 	_loop             
		dec 	r18                 
		brne 	_reset             
		ldi 	r18, outer_count
		pop 	r25
		pop 	r24
	ret

info: .db "Memory led game. Written by Sergey Yarkov 27.09.2021"