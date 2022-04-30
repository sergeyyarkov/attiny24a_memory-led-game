;
; Initialize stack pointer
; @0 - Temp register
.macro init_stack_p
  ldi @0, low(@1)
  out SPL, @0
  clr @0
  .ifdef SPH 
	ldi @0, high(RAMEND) 
	out SPH, @0 
	clr @0
  .endif
.endm

;
; out immediate
; @0 - I/O Register
; @1 - Data to write
.macro outi
  push temp_r
  ldi temp_r, @1
  out @0, temp_r
  pop temp_r
.endm

;
; sts immediate
; @0 - SRAM Address
; @1 - Data to write
.macro stsi
  push temp_r
  ldi temp_r, @1
  sts @0, temp_r
  pop temp_r
.endm

;
; Set MCU global state
; @0 - New state
.macro set_state
  sts PREVIOUS_STATE_ADDRESS, mcu_state_r         ; Write previous state to SRAM
  stsi CURRENT_STATE_ADDRESS, @0
.endm

.macro buzzer_on
  sbi BUZZ_DIR, BUZZ_PIN
.endm

.macro buzzer_off
  cbi BUZZ_DIR, BUZZ_PIN
.endm

.macro beep_led_1
  outi OCR0A, 142
  sbi LED_PORT, 0
  sbi BUZZ_DIR, BUZZ_PIN
  rcall delay
  cbi LED_PORT, 0
  cbi BUZZ_DIR, BUZZ_PIN
.endm

.macro beep_led_2
  outi OCR0A, 71
  sbi LED_PORT, 1
  sbi BUZZ_DIR, BUZZ_PIN
  rcall delay
  cbi LED_PORT, 1
  cbi BUZZ_DIR, BUZZ_PIN
.endm

.macro beep_led_3
  outi OCR0A, 105
  sbi LED_PORT, 2
  sbi BUZZ_DIR, BUZZ_PIN
  rcall delay
  cbi LED_PORT, 2
  cbi BUZZ_DIR, BUZZ_PIN
.endm

.macro beep_led_4
  outi OCR0A, 80
  sbi LED_PORT, 3
  sbi BUZZ_DIR, BUZZ_PIN
  rcall delay
  cbi LED_PORT, 3
  cbi BUZZ_DIR, BUZZ_PIN
.endm



