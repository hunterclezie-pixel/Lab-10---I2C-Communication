// Hunter Clezie
// RCET3375
// Lab10I2CPt1
// https://github.com/hunterclezie-pixel/Lab-10---I2C-Communication.git

; PIC16F883 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

; config statements should precede project file includes.
#include <xc.inc>  
    ; General Purpose Registers
    pin_digit1     EQU 0x20 ; First entered PIN digit
    pin_digit2     EQU 0x21 ; Second entered PIN digit
    pin_digit3     EQU 0x22 ; Third entered PIN digit
    pin_digit4     EQU 0x23 ; Fourth entered PIN digit
    Count5ms	   EQU 0x24 ; Outer debounce delay counter
    Count50us      EQU 0x25 ; Inner debounce delay counter

    ; Reusable EEPROM registers (only these 3 GPRs used by EEPROM routines)
    ee_address     EQU 0x26  ; EEPROM address
    ee_data        EQU 0x27  ; Byte to read or write
    ee_status      EQU 0x28  ; EEPROM status bits
    
    ; Additional application registers
    digit_count    EQU 0x29 ; Number of PIN digits entered
    key_held       EQU 0x2A ; Bit 0 = key has been pressed
    key_code       EQU 0x2B ; Scanned key (0-15, FF = none)
    candidate_key  EQU 0x2C ; Key saved during debounce
    keyLow         EQU 0x2D ; Key status bits for keys 1,2,3,A,4,5,6,B
    mode	   EQU 0x2E ; Current lock service mod
    keyHigh        EQU 0x2F ; Key status bits for keys 7,8,9,C,*,0,#,D
    pulse_count    EQU 0x30 ; Timer0 overflow counter
    pin_index      EQU 0x31 ; PIN comparison counter
      
    ; Two copies of the proposed PIN, kept in RAM only
    new_pin1       EQU 0x32
    new_pin2       EQU 0x33
    new_pin3       EQU 0x34
    new_pin4       EQU 0x35
    confirm_pin1   EQU 0x36
    confirm_pin2   EQU 0x37
    confirm_pin3   EQU 0x38
    confirm_pin4   EQU 0x39
    pin_match      EQU 0x3A ; 1 = PIN matched, 0 = not matched
    pin_update     EQU 0x3B ; Bit 0 = EEPROM update in progress
    temp_digit     EQU 0x3C ; Temporary byte for RAM comparisons

    ; Constant (a number, NOT a register)
    TIMEOUT_OVERFLOWS EQU 15 ; 15 x 65.536 ms = about 1 second
    PIN_EE_START   EQU 0x00
    PIN_LENGTH     EQU 0x04
    PIN_MARKER_ADDR EQU 0x04  ; Fifth EEPROM address
    VALID_MARKER   EQU 0xC4  ; Only this value means PIN is valid
   
   ; Part 4 service modes
    MODE_INVALID_NEW      EQU 0x00
    MODE_INVALID_CONFIRM  EQU 0x01
    MODE_LOCKED           EQU 0x02
    MODE_ARMED            EQU 0x03 ; C was pressed; wait for #
    MODE_CHANGE_AUTH      EQU 0x04
    MODE_CHANGE_NEW       EQU 0x05
    MODE_CHANGE_CONFIRM   EQU 0x06

    ; EEPROM status bit positions
    EEPROM_READ    EQU 0
    EEPROM_WRITE   EQU 1
    EEPROM_ERROR   EQU 2
    GIE_SAVED      EQU 3     ; Temporarily save GIE during unlock
      
; Special keypad codes
    NO_KEY         EQU 0xFF
    STAR_KEY       EQU 0x0A
    HASH_KEY       EQU 0x0B
 
; Reset Vector at 0000h. Execution starts here after reset.
PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup

; Interrupt Vector
PSECT isrVect,class=CODE,delta=2

; Main code section starts at 0008h. User code goes here.
PSECT code,class=CODE,delta=2

Setup:
    ; Bank 0: Outputs OFF before the pins become outputs
    BANKSEL PORTA
    CLRF PORTA      ; Solenoid and buzzer OFF
    CLRF PORTB      ; Keep keypad rows LOW
    MOVLW 0x80
    MOVWF PORTC     ; Display Write HIGH
 
    ; Bank 3
    BANKSEL ANSEL
    CLRF ANSEL      ; Disable analog inputs
    CLRF ANSELH
    BCF EECON1,7    ; Select data EEPROM
    BCF EECON1,2    ; Disable EEPROM writing
 
    ; Bank 1
    BANKSEL TRISA
    BCF TRISA,0     ; RA0 simulated solenoid output
    BCF TRISA,1     ; RA1 buzzer output
    BCF TRISA,2     ; RA2 EEPROM error LED output
    MOVLW 0xFF
    MOVWF TRISB     ; RB0-RB7 start as inputs
    CLRF TRISC      ; Display outputs
    MOVLW 0xFF
    MOVWF WPUB      ; Weak pull-ups on keypad columns
    MOVLW 0x07
    MOVWF OPTION_REG ; RBPU=0 (pull-ups on), internal clock, 1:256 prescaler
 
    ; Bank 0
    BANKSEL TMR0
    CLRF TMR0        ; Clear Timer0 counter
    BCF INTCON,2     ; Clear Timer0 overflow flag
    BCF INTCON,7     ; Leave global interrupts disabled
    CLRF T1CON      ; Timer1 starts OFF (used for nonblocking beeps)
    BCF PIR1,0      ; Clear Timer1 overflow flag
 
    ; Clear all application registers
    CLRF pin_digit1
    CLRF pin_digit2
    CLRF pin_digit3
    CLRF pin_digit4
    CLRF digit_count
    CLRF key_held
    CLRF candidate_key
    CLRF keyLow
    CLRF mode
    CLRF keyHigh
    CLRF pulse_count
    CLRF pin_index
    CLRF pin_match
    CLRF pin_update
    CLRF temp_digit
    CLRF new_pin1
    CLRF new_pin2
    CLRF new_pin3
    CLRF new_pin4
    CLRF confirm_pin1
    CLRF confirm_pin2
    CLRF confirm_pin3
    CLRF confirm_pin4
    CLRF ee_address
    CLRF ee_data
    CLRF ee_status
    MOVLW NO_KEY
    MOVWF key_code
    BCF STATUS,7     ; IRP = 0: indirect addressing uses bank 0/1
 
    ; Check if a valid PIN is stored in EEPROM
    CALL CheckPINRecord
    
GOTO Main
 
Main:
    CALL ServiceBeep ; Finish beep without blocking keypad scans
 
    ; Check for a keypad press
    CALL ScanKey
    BANKSEL key_code
    MOVLW NO_KEY
    XORWF key_code,W
    BTFSC STATUS,2
    GOTO KeyReleased
 
    ; Ignore a key that is still being held
    BTFSC key_held,0
    GOTO Main
 
    ; Debounce a new key press
    MOVF key_code,W
    MOVWF candidate_key
    CALL Delay10ms
    CALL ScanKey
    BANKSEL candidate_key
    MOVF candidate_key,W
    XORWF key_code,W
    BTFSS STATUS,2
    GOTO Main        ; Not a stable press
    BSF key_held,0   ; Count this press only once
    CALL BeepKey     ; All 16 keys produce a beep
    CALL HandleKey   ; Process the new key
    GOTO Main
 
KeyReleased:
    ; Wait for a stable release before accepting another press
    BTFSS key_held,0
    GOTO Main
    CALL Delay10ms
    CALL ScanKey
    BANKSEL key_code
    MOVLW NO_KEY
    XORWF key_code,W
    BTFSS STATUS,2
    GOTO Main
    BCF key_held,0
    GOTO Main
 
ScanKey:
    ; Determine which key is pressed on the 4x4 keypad
    BANKSEL keyLow
    CLRF keyLow      ; Clearing lower key status bits
    CLRF keyHigh     ; Clearing higher key status bits
 
; Checks Row 4 of the 4x4 matrix
    BANKSEL TRISB
    MOVLW 0xF7       ; RB3 output LOW, rest of PORTB inputs
    MOVWF TRISB
    BANKSEL PORTB
    NOP              ; Let the row settle
    NOP
 
; Checks each column 1-4
    BTFSS PORTB,4    ; Column 1 for '*' key being pressed
    BSF keyHigh,4
    BTFSS PORTB,5    ; Column 2 for '0' key being pressed
    BSF keyHigh,5
    BTFSS PORTB,6    ; Column 3 for '#' key being pressed
    BSF keyHigh,6
    BTFSS PORTB,7    ; Column 4 for 'D' key being pressed
    BSF keyHigh,7
 
; Checks Row 3 of the 4x4 matrix
    BANKSEL TRISB
    MOVLW 0xFB       ; RB2 output LOW, rest of PORTB inputs
    MOVWF TRISB
    BANKSEL PORTB
    NOP
    NOP
 
    BTFSS PORTB,4    ; Column 1 for '7' key being pressed
    BSF keyHigh,0
    BTFSS PORTB,5    ; Column 2 for '8' key being pressed
    BSF keyHigh,1
    BTFSS PORTB,6    ; Column 3 for '9' key being pressed
    BSF keyHigh,2
    BTFSS PORTB,7    ; Column 4 for 'C' key being pressed
    BSF keyHigh,3
 
; Checks Row 2 of the 4x4 matrix
    BANKSEL TRISB
    MOVLW 0xFD       ; RB1 output LOW, rest of PORTB inputs
    MOVWF TRISB
    BANKSEL PORTB
    NOP
    NOP
 
    BTFSS PORTB,4    ; Column 1 for '4' key being pressed
    BSF keyLow,4
    BTFSS PORTB,5    ; Column 2 for '5' key being pressed
    BSF keyLow,5
    BTFSS PORTB,6    ; Column 3 for '6' key being pressed
    BSF keyLow,6
    BTFSS PORTB,7    ; Column 4 for 'B' key being pressed
    BSF keyLow,7
 
; Checks Row 1 of the 4x4 matrix
    BANKSEL TRISB
    MOVLW 0xFE       ; RB0 output LOW, rest of PORTB inputs
    MOVWF TRISB
    BANKSEL PORTB
    NOP
    NOP
 
    BTFSS PORTB,4    ; Column 1 for '1' key being pressed
    BSF keyLow,0
    BTFSS PORTB,5    ; Column 2 for '2' key being pressed
    BSF keyLow,1
    BTFSS PORTB,6    ; Column 3 for '3' key being pressed
    BSF keyLow,2
    BTFSS PORTB,7    ; Column 4 for 'A' key being pressed
    BSF keyLow,3
 
; Release all rows (all of PORTB back to inputs)
    BANKSEL TRISB
    MOVLW 0xFF
    MOVWF TRISB
    BANKSEL keyLow
 
; Pick one key if several are pressed (D = highest priority)
Test_D:
    BTFSS keyHigh,7  ; Test if D is pressed
    GOTO Test_Hash
    MOVLW 0x0F
    GOTO SaveKeyIndex
 
Test_Hash:
    BTFSS keyHigh,6  ; Test if # is pressed
    GOTO Test_0
    MOVLW HASH_KEY
    GOTO SaveKeyIndex
 
Test_0:
    BTFSS keyHigh,5  ; Test if 0 is pressed
    GOTO Test_Star
    MOVLW 0x00
    GOTO SaveKeyIndex
 
Test_Star:
    BTFSS keyHigh,4  ; Test if * is pressed
    GOTO Test_C
    MOVLW STAR_KEY
    GOTO SaveKeyIndex
 
Test_C:
    BTFSS keyHigh,3  ; Test if C is pressed
    GOTO Test_9
    MOVLW 0x0E
    GOTO SaveKeyIndex
 
Test_9:
    BTFSS keyHigh,2  ; Test if 9 is pressed
    GOTO Test_8
    MOVLW 0x09
    GOTO SaveKeyIndex
 
Test_8:
    BTFSS keyHigh,1  ; Test if 8 is pressed
    GOTO Test_7
    MOVLW 0x08
    GOTO SaveKeyIndex
 
Test_7:
    BTFSS keyHigh,0  ; Test if 7 is pressed
    GOTO Test_B
    MOVLW 0x07
    GOTO SaveKeyIndex
 
Test_B:
    BTFSS keyLow,7   ; Test if B is pressed
    GOTO Test_6
    MOVLW 0x0D
    GOTO SaveKeyIndex
 
Test_6:
    BTFSS keyLow,6   ; Test if 6 is pressed
    GOTO Test_5
    MOVLW 0x06
    GOTO SaveKeyIndex
 
Test_5:
    BTFSS keyLow,5   ; Test if 5 is pressed
    GOTO Test_4
    MOVLW 0x05
    GOTO SaveKeyIndex
 
Test_4:
    BTFSS keyLow,4   ; Test if 4 is pressed
    GOTO Test_A
    MOVLW 0x04
    GOTO SaveKeyIndex
 
Test_A:
    BTFSS keyLow,3   ; Test if A is pressed
    GOTO Test_3
    MOVLW 0x0C
    GOTO SaveKeyIndex
 
Test_3:
    BTFSS keyLow,2   ; Test if 3 is pressed
    GOTO Test_2
    MOVLW 0x03
    GOTO SaveKeyIndex
 
Test_2:
    BTFSS keyLow,1   ; Test if 2 is pressed
    GOTO Test_1
    MOVLW 0x02
    GOTO SaveKeyIndex
 
Test_1:
    BTFSS keyLow,0   ; Test if 1 is pressed
    GOTO NoKey
    MOVLW 0x01
    GOTO SaveKeyIndex
 
NoKey:
    MOVLW NO_KEY     ; No key active
 
SaveKeyIndex:
    BANKSEL key_code
    MOVWF key_code   ; Save the actual key value
    RETURN
 
HandleKey:
    ; All keys reach this routine only once per debounced physical press
    BANKSEL mode
    MOVLW STAR_KEY
    XORWF key_code,W
    BTFSC STATUS,2
    GOTO CancelPIN       ; * cancels in every service mode
 
    ; C followed by # starts PIN change (only while locked)
    MOVLW MODE_ARMED
    XORWF mode,W
    BTFSC STATUS,2
    GOTO HandleArmed
 
    MOVLW 0x0E           ; C key
    XORWF key_code,W
    BTFSC STATUS,2
    GOTO HandleC
 
    MOVLW HASH_KEY
    XORWF key_code,W
    BTFSC STATUS,2
    GOTO SubmitPIN
 
    ; A, B, D or other unexpected non-numeric keys abort
    MOVLW 0x0A
    SUBWF key_code,W     ; Carry = 1 when key >= 10
    BTFSC STATUS,0
    GOTO BadEntry
 
    ; Only four digits may be entered before #
    MOVLW PIN_LENGTH
    XORWF digit_count,W
    BTFSC STATUS,2
    GOTO BadEntry
 
    ; Save numeric key in one of four RAM locations
    MOVF digit_count,W
    ADDLW pin_digit1
    MOVWF FSR
    MOVF key_code,W
    MOVWF INDF
    INCF digit_count,F
 
    MOVF digit_count,W
    ADDLW 0x30           ; Display 1, 2, 3 or 4
    CALL DisplayChar
    RETURN
 
HandleC:
    ; C is allowed only as the first key while normally locked
    MOVLW MODE_LOCKED
    XORWF mode,W
    BTFSS STATUS,2
    GOTO BadEntry
    MOVF digit_count,F   ; Z = 1 when no digits entered
    BTFSS STATUS,2
    GOTO BadEntry
    MOVLW MODE_ARMED
    MOVWF mode
    MOVLW 0x43           ; C = change request
    CALL DisplayChar
    RETURN
 
HandleArmed:
    MOVLW HASH_KEY
    XORWF key_code,W
    BTFSS STATUS,2
    GOTO BadEntry        ; C must be followed immediately by #
    CALL ClearEntry
    MOVLW MODE_CHANGE_AUTH
    MOVWF mode
    MOVLW 0x41           ; A = enter current PIN to authenticate
    CALL DisplayChar
    RETURN
 
SubmitPIN:
    ; A full entry is exactly four digits followed by #
    MOVLW PIN_LENGTH
    XORWF digit_count,W
    BTFSS STATUS,2
    GOTO BadEntry
 
    MOVLW MODE_INVALID_NEW
    XORWF mode,W
    BTFSC STATUS,2
    GOTO SaveFirstNewPIN
 
    MOVLW MODE_INVALID_CONFIRM
    XORWF mode,W
    BTFSC STATUS,2
    GOTO ConfirmNewPIN
 
    MOVLW MODE_LOCKED
    XORWF mode,W
    BTFSC STATUS,2
    GOTO NormalUnlock
 
    MOVLW MODE_CHANGE_AUTH
    XORWF mode,W
    BTFSC STATUS,2
    GOTO AuthenticateChange
 
    MOVLW MODE_CHANGE_NEW
    XORWF mode,W
    BTFSC STATUS,2
    GOTO SaveFirstNewPIN
 
    MOVLW MODE_CHANGE_CONFIRM
    XORWF mode,W
    BTFSC STATUS,2
    GOTO ConfirmNewPIN
 
    GOTO BadEntry
 
NormalUnlock:
    CALL CurrentPINMatch
    BANKSEL pin_match
    MOVF pin_match,F
    BTFSC STATUS,2
    GOTO BadEntry
    CALL ClearEntry
    MOVLW 0x55           ; U = unlocked
    CALL DisplayChar
    CALL SolenoidPulse   ; Only normal locked mode can unlock
    MOVLW 0x4C           ; L = locked again
    CALL DisplayChar
    RETURN
 
AuthenticateChange:
    CALL CurrentPINMatch
    BANKSEL pin_match
    MOVF pin_match,F
    BTFSC STATUS,2
    GOTO BadEntry        ; Incorrect old PIN cancels change
    CALL ClearEntry
    MOVLW MODE_CHANGE_NEW
    MOVWF mode
    MOVLW 0x4E           ; N = enter new PIN
    CALL DisplayChar
    RETURN
 
SaveFirstNewPIN:
    ; Copy first new PIN from entry RAM into new_pin1..new_pin4
    CALL CopyNewPIN
    CALL ClearEntry
    BANKSEL mode
    INCF mode,F          ; A NEW mode is always followed by its CONFIRM mode
    MOVLW 0x46           ; F = enter new PIN again
    CALL DisplayChar
    RETURN
 
ConfirmNewPIN:
    ; Save confirmation in RAM and compare the two groups
    CALL CopyConfirmPIN
    CALL NewPINMatch
    BANKSEL pin_match
    MOVF pin_match,F
    BTFSC STATUS,2
    GOTO BadEntry        ; A mismatch must not write EEPROM
    CALL ClearEntry
    CALL PINWrite        ; Only called after both new PINs match
    RETURN
 
CancelPIN:
    CALL RestartMode
    MOVLW 0x43           ; C = canceled
    CALL DisplayChar
    RETURN
 
BadEntry:
    CALL RestartMode
    MOVLW 0x45           ; E = incorrect/incomplete/unexpected
    CALL DisplayChar
    RETURN
 
RestartMode:
    ; Invalid-PIN modes (0 and 1) restart at the first new PIN.
    ; Every other mode returns to normal locked mode.
    BANKSEL mode
    MOVLW MODE_LOCKED
    SUBWF mode,W         ; Carry = 1 when mode >= 2
    MOVLW MODE_INVALID_NEW
    BTFSC STATUS,0       ; (MOVLW does not change Carry)
    MOVLW MODE_LOCKED
    MOVWF mode
    CALL ClearEntry
    RETURN
 
ClearEntry:
    BANKSEL digit_count
    CLRF digit_count
    CLRF pin_digit1
    CLRF pin_digit2
    CLRF pin_digit3
    CLRF pin_digit4
    RETURN

CheckPINRecord:
    ; Read the validity marker before allowing normal unlocking
    BANKSEL ee_address
    MOVLW PIN_MARKER_ADDR
    MOVWF ee_address
    CALL EEPROMRead
    BANKSEL ee_data
    MOVLW VALID_MARKER
    XORWF ee_data,W
    BTFSS STATUS,2
    GOTO StartInvalid
 
    ; Even with a valid marker, reject digits outside 0 through 9
    CLRF pin_index
CheckStoredDigit:
    MOVF pin_index,W
    ADDLW PIN_EE_START
    MOVWF ee_address
    CALL EEPROMRead
    BANKSEL ee_data
    MOVLW 0x0A
    SUBWF ee_data,W      ; Carry = 1 when stored digit >= 10
    BTFSC STATUS,0
    GOTO StartInvalid
    INCF pin_index,F
    MOVLW PIN_LENGTH
    XORWF pin_index,W
    BTFSS STATUS,2
    GOTO CheckStoredDigit
 
    ; Valid PIN: start in normal locked mode
    BANKSEL mode
    MOVLW MODE_LOCKED
    MOVWF mode
    CALL ClearEntry
    MOVLW 0x4C           ; L = ready/locked
    CALL DisplayChar
    RETURN
 
StartInvalid:
    BANKSEL mode
    MOVLW MODE_INVALID_NEW
    MOVWF mode
    CALL ClearEntry
    MOVLW 0x4E           ; N = first-use new PIN required
    CALL DisplayChar
    RETURN

CurrentPINMatch:
    ; Compare the four entered digits with the EEPROM PIN.
    ; This routine NEVER operates the solenoid by itself.
    BANKSEL pin_match
    MOVLW 0x01
    MOVWF pin_match
    CLRF pin_index
 
CurrentNextDigit:
    MOVF pin_index,W
    ADDLW PIN_EE_START
    MOVWF ee_address
    CALL EEPROMRead      ; Stored digit returns in ee_data
    BANKSEL pin_index    ; EEPROMRead changes banks
    MOVF pin_index,W
    ADDLW pin_digit1
    MOVWF FSR
    MOVF INDF,W          ; Entered digit
    XORWF ee_data,W      ; Compare with stored EEPROM digit
    BTFSS STATUS,2
    GOTO CurrentMismatch
    INCF pin_index,F
    MOVLW PIN_LENGTH
    XORWF pin_index,W
    BTFSS STATUS,2
    GOTO CurrentNextDigit
    RETURN
 
CurrentMismatch:
    CLRF pin_match
    RETURN
 
CopyNewPIN:
    ; Save the four entered digits as the first new PIN
    BANKSEL pin_digit1
    MOVF pin_digit1,W
    MOVWF new_pin1
    MOVF pin_digit2,W
    MOVWF new_pin2
    MOVF pin_digit3,W
    MOVWF new_pin3
    MOVF pin_digit4,W
    MOVWF new_pin4
    RETURN
 
CopyConfirmPIN:
    ; Save the four entered digits as the confirmation PIN
    BANKSEL pin_digit1
    MOVF pin_digit1,W
    MOVWF confirm_pin1
    MOVF pin_digit2,W
    MOVWF confirm_pin2
    MOVF pin_digit3,W
    MOVWF confirm_pin3
    MOVF pin_digit4,W
    MOVWF confirm_pin4
    RETURN
 
NewPINMatch:
    ; Compare the two four-digit RAM groups (no EEPROM access)
    BANKSEL pin_match
    MOVLW 0x01
    MOVWF pin_match
    CLRF pin_index
 
NewMatchLoop:
    MOVF pin_index,W
    ADDLW new_pin1
    MOVWF FSR
    MOVF INDF,W
    MOVWF temp_digit
    MOVF pin_index,W
    ADDLW confirm_pin1
    MOVWF FSR
    MOVF INDF,W
    XORWF temp_digit,W
    BTFSS STATUS,2
    GOTO NewMismatch
    INCF pin_index,F
    MOVLW PIN_LENGTH
    XORWF pin_index,W
    BTFSS STATUS,2
    GOTO NewMatchLoop
    RETURN
 
NewMismatch:
    CLRF pin_match
    RETURN

PINWrite:
    BANKSEL PORTA
    BCF PORTA,0          ; Never unlock during EEPROM updates
    BSF pin_update,0     ; PIN_UPDATE flag
    MOVLW 0x53           ; S = saving
    CALL DisplayChar
 
    ; Step 1: Invalidate marker before touching the stored digits
    BANKSEL ee_address
    MOVLW PIN_MARKER_ADDR
    MOVWF ee_address
    CLRF ee_data
    CALL WritePINByte
 
    ; Steps 2-5: Write and verify each new digit
    BANKSEL pin_index
    CLRF pin_index
 
PINWriteDigitLoop:
    MOVF pin_index,W
    ADDLW PIN_EE_START
    MOVWF ee_address
    MOVF pin_index,W
    ADDLW new_pin1
    MOVWF FSR
    MOVF INDF,W
    MOVWF ee_data
    CALL WritePINByte
    BANKSEL pin_index    ; WritePINByte changes banks
    INCF pin_index,F
    MOVLW PIN_LENGTH
    XORWF pin_index,W
    BTFSS STATUS,2
    GOTO PINWriteDigitLoop
 
    ; Step 6: Valid marker written LAST
    BANKSEL ee_address
    MOVLW PIN_MARKER_ADDR
    MOVWF ee_address
    MOVLW VALID_MARKER
    MOVWF ee_data
    CALL WritePINByte
 
    ; All six steps verified
    BANKSEL pin_update
    BCF pin_update,0     ; Writing completed and verified
    CALL ClearEntry
    MOVLW MODE_LOCKED
    MOVWF mode
    MOVLW 0x50           ; P = new PIN programmed successfully
    CALL DisplayChar
    RETURN
 
WritePINByte:
    ; Write one byte, wait for it, verify it.
    ; EEPROMWrite may skip an unchanged byte, so always verify.
    CALL EEPROMWrite
 
WaitPINWrite:
    BANKSEL EECON1
    BTFSC EECON1,1       ; WR=1 while write is in progress
    GOTO WaitPINWrite
    CALL EEPROMVerifyWrite
 
    ; Any failure stops the whole sequence (no more bytes are written)
    BANKSEL ee_status
    BTFSC ee_status,EEPROM_ERROR
    GOTO PINWriteError
    RETURN
 
PINWriteError:
    ; Stop permanently until a power cycle. No further PIN attempts.
    BANKSEL PORTA
    BCF PORTA,0          ; Solenoid OFF
    BSF PORTA,2          ; RA2 error LED ON
    BCF PORTA,1          ; Buzzer OFF
    MOVLW 0x45           ; E = EEPROM error
    CALL DisplayChar
 
PINErrorHalt:
    GOTO PINErrorHalt

; Nonblocking beep (Timer1) and solenoid pulse
BeepKey:
    BANKSEL T1CON
    CLRF T1CON         ; Stop Timer1 before reloading
    MOVLW 0xB6
    MOVWF TMR1H
    MOVLW 0xC2
    MOVWF TMR1L        ; 0xB6C2 -> 18750 counts of 8 us = 150 ms
    BCF PIR1,0         ; Clear TMR1IF
    BANKSEL PORTA
    BSF PORTA,1        ; Active buzzer ON
    BANKSEL T1CON
    MOVLW 0x31         ; Timer1 on, Fosc/4, 1:8 prescaler
    MOVWF T1CON
    RETURN
 
ServiceBeep:
    BANKSEL T1CON
    BTFSS T1CON,0      ; Timer1 not running?
    RETURN
    BTFSS PIR1,0       ; Not 150 ms yet?
    RETURN
    BCF T1CON,0        ; Stop timer
    BCF PIR1,0
    BANKSEL PORTA
    BCF PORTA,1        ; Active buzzer OFF
    RETURN
 
SolenoidPulse:
    ; Turn on the simulated solenoid for about one second
    BANKSEL PORTA
    BSF PORTA,0          ; Unlock output HIGH
    CLRF pulse_count
    CLRF TMR0
    BCF INTCON,2
 
SolenoidWait:
    CALL ServiceBeep     ; Turn buzzer OFF after 150 ms
    BANKSEL TMR0
    BTFSS INTCON,2
    GOTO SolenoidWait
    BCF INTCON,2
    INCF pulse_count,F
    MOVLW TIMEOUT_OVERFLOWS
    XORWF pulse_count,W
    BTFSS STATUS,2
    GOTO SolenoidWait
    BCF PORTA,0          ; Lock output LOW
    RETURN

EEPROMFetch:
    ; Internal helper: read the EEPROM byte at ee_address, return it in W
    BANKSEL ee_address
    MOVF ee_address,W
    BANKSEL EEADR
    MOVWF EEADR
    BANKSEL EECON1
    BCF EECON1,7         ; EEPGD = 0, data EEPROM
    BSF EECON1,0         ; RD = 1
    BANKSEL EEDATA
    MOVF EEDATA,W
    RETURN
 
EEPROMRead:
    ; Mark EEPROM read as active
    BANKSEL ee_status
    BSF ee_status,EEPROM_READ
 
    ; Read the byte and return it in ee_data
    CALL EEPROMFetch
    BANKSEL ee_data
    MOVWF ee_data
 
    ; Read is finished
    BANKSEL ee_status
    BCF ee_status,EEPROM_READ
    RETURN
 
EEPROMWrite:
    BANKSEL PORTA
    BSF PORTA, 3 ; For getting the EEPROM Write 
    ; Do not start if a write is already active
    BANKSEL ee_status
    BTFSC ee_status,EEPROM_WRITE
    RETURN
 
    ; Do not start if EEIF is already set
    BANKSEL PIR2
    BTFSC PIR2,4
    RETURN
 
    ; Read the currently stored byte (EEADR is now loaded)
    CALL EEPROMFetch
 
    ; Compare stored data with requested data (ee_data is not changed)
    BANKSEL ee_data
    XORWF ee_data,W
    BTFSC STATUS,2
    RETURN               ; Same value, skip the write
 
    ; Copy requested data into EEPROM data register
    MOVF ee_data,W
    BANKSEL EEDATA
    MOVWF EEDATA
 
    ; Mark the write as active and remember if GIE was on
    BANKSEL ee_status
    BSF ee_status,EEPROM_WRITE
    BCF ee_status,GIE_SAVED
    BTFSC INTCON,7       ; INTCON can be read from any bank
    BSF ee_status,GIE_SAVED
 
    ; Enable EEPROM writing
    BANKSEL EECON1
    BCF EECON1,7         ; EEPGD = 0
    BSF EECON1,2         ; WREN = 1
 
    ; Disable global interrupts for unlock
    BCF INTCON,7
 
WaitGIEOff:
    BTFSC INTCON,7
    GOTO WaitGIEOff
 
    ; Required uninterrupted EEPROM unlock
    MOVLW 0x55
    MOVWF EECON2
    MOVLW 0xAA
    MOVWF EECON2
    BSF EECON1,1         ; WR = 1, start writing
 
    ; Restore previous global interrupt state
    BANKSEL ee_status
    BTFSC ee_status,GIE_SAVED
    BSF INTCON,7         ; Turn GIE back on only if it was on before
    BCF ee_status,GIE_SAVED
    BANKSEL PORTA
    BCF PORTA, 3 ; For getting the EEPROM Write 
    RETURN               ; Do not wait for completion
 
EEPROMVerifyWrite:
    ; Read back the byte at ee_address
    CALL EEPROMFetch
 
    ; Compare with the expected ee_data (ee_data is not changed)
    BANKSEL ee_data
    ; MOVLW 0xFF           ; Testing Error
    XORWF ee_data,W
    BTFSC STATUS,2
    GOTO VerifySuccess
 
    ; Verification failed
    BANKSEL ee_status
    BCF ee_status,EEPROM_WRITE
    BSF ee_status,EEPROM_ERROR
    GOTO VerifyFinished
 
VerifySuccess:
    ; Verification passed, clear all status flags
    BANKSEL ee_status
    CLRF ee_status
 
VerifyFinished:
    BANKSEL EECON1
    BCF EECON1,2         ; WREN = 0
    BANKSEL PIR2
    BCF PIR2,4           ; EEIF = 0
    RETURN
 
DisplayChar:
    ; DLG7137 Display
    ANDLW 0x7F            ; Keep the seven ASCII data bits
    IORLW 0x80            ; Keep RC7 Write HIGH
    BANKSEL PORTC
    MOVWF PORTC           ; Put character on the data pins
    NOP                   ; Allow data to settle
    BCF PORTC,7           ; Pulse display Write LOW
    NOP
    BSF PORTC,7           ; Finish the display write
    RETURN
 
Delay10ms:
    CALL Delay5ms
    CALL Delay5ms
    RETURN
 
Delay5ms:
    BANKSEL Count5ms
    MOVLW   0x5E
    MOVWF   Count5ms
 
Delay5msLoop:
    CALL    Delay50usLoop
    DECFSZ  Count5ms,F
    GOTO    Delay5msLoop
    MOVLW   0x04
    MOVWF   Count5ms
    DECFSZ  Count5ms,F
    GOTO    $-1
    RETURN
 
Delay50usLoop:
    ; Delay loop is equal to 44 Tcy when count is 15
    MOVLW 0x0F             ; 1 Tcy move W=15 to count
    MOVWF Count50us        ; 1 Tcy make count equal 15
    DECFSZ Count50us,F     ; 1 Tcy if not zero, 2 Tcy if zero
    GOTO $-1               ; 2 Tcy delay runs 15 times before skipping
    RETURN
 
END