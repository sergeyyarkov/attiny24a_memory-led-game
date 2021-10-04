;
; Initialize stack pointer
; @0 - Temp register
.macro init_stack_p
  ldi @0, low(@1)
  out SPL, @0
  .ifdef SPH 
    ldi @0, high(RAMEND) 
    out SPH, @0 
  .endif
.endm

;
; out immediate
; @0 - I/O Register
; @1 - Data to write
.macro outi
  push r16
  ldi r16, @1
  out @0, r16
  pop r16
.endm

;
; sts immediate
; @0 - SRAM Address
; @1 - Data to write
.macro stsi
  push r16
  ldi r16, @1
  sts @0, r16
  pop r16
.endm

;
; Set MCU global state
; @0 - New state
.macro set_state
  sts PREVIOUS_STATE_ADDRESS, mcu_state_r         ; Write previous state to SRAM
  stsi CURRENT_STATE_ADDRESS, @0
.endm