// Hunter Clezie
// RCET3375
// Lab10I2CPt3Master
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
    ; General Purpose Registers (shared RAM)
    ErrorFlag   EQU 0x70    ; Bit 0 = NACK, 1 = timeout, 2 = bus LOW
    WaitCount   EQU 0x71    ; I2C timeout counter
    PointerByte EQU 0x72    ; Slave register pointer
    DataHigh    EQU 0x73    ; ADC upper byte
    DataLow     EQU 0x74    ; Received byte / ADC lower byte
    RxByte      EQU 0x75    ; Most recent received byte
    TimerCount  EQU 0x76    ; Timer0 overflow counter
    WaitOuter   EQU 0x77    ; Second I2C timeout counter

    ; PIC slave address 0x20
    SlaveWrite EQU 0x40     ; Address with Write bit
    SlaveRead  EQU 0x41     ; Address with Read bit
    OtherWrite EQU 0x42     ; Incorrect address 0x21
    DisplayLetter EQU 0x41  ; ASCII 'A' (change to 0x42 for 'B')

    ; Timer0 settings from Part 2
    TimerOption EQU 0x07    ; 1:256 prescaler
    TimerOverflows EQU 15   ; About 0.983 seconds at 4 MHz

; Reset Vector
PSECT resetVect,class=CODE,delta=2
ResetVector:
    GOTO Setup

; Interrupt Vector (not used)
PSECT isrVect,class=CODE,delta=2

; Main Code
PSECT code,class=CODE,delta=2

Setup:
    ; Disable analog inputs so the pins work as digital I/O
    BANKSEL ANSEL
    CLRF ANSEL         ; Disable analog inputs AN0-AN7
    CLRF ANSELH        ; Disable remaining analog inputs

    ; Set up PORTA diagnostic outputs
    BANKSEL PORTA
    CLRF PORTA         ; Start all PORTA outputs LOW
    
    BANKSEL TRISA
    BCF TRISA,0        ; RA0 = NACK / error indicator
    BCF TRISA,1        ; RA1 = I2C transaction indicator

    ; Set up I2C communication pins
    BANKSEL TRISC
    BSF TRISC,3        ; RC3 = SCL, I2C clock
    BSF TRISC,4        ; RC4 = SDA, I2C data

    ; Set up MSSP for I2C Master Mode
    BANKSEL SSPCON
    CLRF SSPCON        ; Clear previous MSSP settings
    BANKSEL SSPCON2
    CLRF SSPCON2       ; Clear I2C control settings
    BANKSEL SSPCON
    MOVLW 0x28         ; Enable MSSP in I2C Master Mode
    MOVWF SSPCON
    BANKSEL SSPSTAT
    BSF SSPSTAT,7      ; Set standard-speed I2C operation

    ; Set I2C clock to 100 kHz using 4 MHz oscillator
    BANKSEL SSPADD
    MOVLW 0x09         ; 4 MHz / (4 x (9 + 1)) = 100 kHz
    MOVWF SSPADD       ; Set I2C clock speed

    ; Set up Timer0 for delays between transactions
    BANKSEL OPTION_REG
    MOVLW TimerOption  ; Load Timer0 prescaler settings
    MOVWF OPTION_REG

    BANKSEL TMR0
    CLRF TMR0          ; Start Timer0 at zero
    BCF INTCON,2       ; Clear Timer0 overflow flag

    ; Clear variables before starting the program
    CLRF ErrorFlag     ; Clear any previous errors
    CLRF WaitCount     ; Clear I2C timeout counter
    CLRF PointerByte   ; Clear selected slave register
    CLRF DataHigh      ; Clear upper data byte
    CLRF DataLow       ; Clear lower data byte
    CLRF RxByte        ; Clear received I2C byte
    CLRF TimerCount    ; Clear Timer0 overflow counter
    CLRF WaitOuter     ; Clear second timeout counter

GOTO Main

Main:
    ; GOTO AddressTest       ; Step 1 - Test correct slave address for ACK
    ; GOTO WrongAddressTest ; Step 1 - Test incorrect address for NACK
    ; GOTO WriteByteTest   ; Step 2 - Send 0xA5 to slave
    ; GOTO ReadByteTest    ; Step 2 - Receive 0x5A from slave
    GOTO PointerA5Test   ; Step 3 - Write and read back pointer 0xA5
    ; GOTO Pointer3CTest   ; Step 3 - Write and read back pointer 0x3C
    ; GOTO SwitchTest      ; Step 4 - Continuously read RB5:RB0 switches
    ; GOTO StatusTest      ; Step 4 - Read slave status register
    ; GOTO DisplayTest     ; Step 5 - Send ASCII character to display
    ; GOTO ADCTest         ; Step 6 - Continuously read 10-bit ADC

; Step 1 - Test Correct Slave Address
AddressTest:
    BANKSEL PORTA
    BSF PORTA,1        ; RA1 HIGH, transaction begins

    ; Generate START condition
    CALL I2CStart

    ; Check if an error occurred
    MOVF ErrorFlag,F
    BTFSS STATUS,2     ; Skip next instruction if no error
    GOTO Halt          ; Stop if error occurred

    ; Send correct slave address with Write bit
    MOVLW SlaveWrite   ; Address 0x20 + Write = 0x40
    CALL I2CSend

    ; Check if slave acknowledged the address
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt          ; Stop if NACK or another error

    ; Generate STOP after successful address test
    CALL I2CStop
    GOTO Halt          ; Wait for MCLR reset

; Step 1 - Test Incorrect Slave Address
WrongAddressTest:
    BANKSEL PORTA
    BSF PORTA,1        ; RA1 HIGH, transaction begins

    ; Generate START condition
    CALL I2CStart

    ; Check for communication errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Send incorrect slave address
    MOVLW OtherWrite   ; Address 0x21 + Write = 0x42
    CALL I2CSend       ; NACK sets RA0 HIGH and attempts STOP
    GOTO Halt          ; Finish address test

; Step 2 - Send One Byte to Slave
WriteByteTest:
    BANKSEL PORTA
    BSF PORTA,1        ; RA1 HIGH, transaction begins

    ; Generate START condition
    CALL I2CStart

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Send slave address with Write bit
    MOVLW SlaveWrite   ; Send 0x40
    CALL I2CSend

    ; Check for ACK
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Send test data byte to slave
    MOVLW 0xA5         ; Test byte required by lab
    CALL I2CSend

    ; Check if slave acknowledged data
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; End communication
    CALL I2CStop
    GOTO Halt

; Step 2 - Read One Byte from Slave
ReadByteTest:
    BANKSEL PORTA
    BSF PORTA,1        ; RA1 HIGH, transaction begins

    ; Read one byte from the slave
    CALL ReadOne       ; Expected value is 0x5A
    GOTO Halt          ; Finish test

; Step 3 - Test Register Pointer 0xA5
PointerA5Test:
    MOVLW 0xA5         ; First test pointer
    MOVWF PointerByte  ; Save pointer for transmission
    GOTO PointerEcho   ; Send pointer and read it back

; Step 3 - Test Register Pointer 0x3C
Pointer3CTest:
    MOVLW 0x3C         ; Second test pointer
    MOVWF PointerByte  ; Save pointer for transmission
    GOTO PointerEcho   ; Send pointer and read it back

; Step 3 - Read Back Selected Pointer
PointerEcho:
    BANKSEL PORTA
    BSF PORTA,1        ; RA1 HIGH, transaction begins

    ; Send pointer to slave
    CALL SelectRegister

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Read the selected pointer back
    CALL ReadOne       ; Returned pointer stored in DataLow
    GOTO Halt

; Step 4 - Continuously Read Slave Switches
SwitchTest:
    ; Wait for Timer0 before next reading
    CALL WaitTimer

    BANKSEL PORTA
    BSF PORTA,1        ; RA1 HIGH, transaction begins

    ; Select switch register
    MOVLW 0x00         ; Pointer 0x00 = PORTB switches
    MOVWF PointerByte

    ; Send pointer to slave
    CALL SelectRegister

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Read switch positions
    CALL ReadOne       ; DataLow contains RB5:RB0

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt
    BANKSEL PORTA
    BCF PORTA,1        ; RA1 LOW, transaction finished
    GOTO SwitchTest    ; Repeat after next timer delay

; Step 4 - Read Slave Device Status
StatusTest:
    BANKSEL PORTA
    BSF PORTA,1        ; RA1 HIGH, transaction begins

    ; Select device status register
    MOVLW 0x04         ; Pointer 0x04 = Device Status
    MOVWF PointerByte

    ; Send pointer to slave
    CALL SelectRegister

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Read status information
    CALL ReadOne       ; DataLow contains status bits
    GOTO Halt

; Step 5 - Send ASCII Character to Display
DisplayTest:
    BANKSEL PORTA
    BSF PORTA,1        ; RA1 HIGH, transaction begins

    ; Select display register
    MOVLW 0x01         ; Pointer 0x01 = DLG7137 display
    MOVWF PointerByte

    ; Load character to display
    MOVLW DisplayLetter ; ASCII value of selected character
    MOVWF DataLow       ; Store character for transmission

    ; Send pointer and character to slave
    CALL WriteOneRegister
    GOTO Halt          ; Finish display test

; Step 6 - Continuously Read Slave ADC
ADCTest:
    ; Wait for Timer0 before reading ADC
    CALL WaitTimer
    BANKSEL PORTA
    BSF PORTA,1        ; RA1 HIGH, transaction begins

    ; Select ADC register
    MOVLW 0x02         ; Pointer 0x02 = Slave AN2 ADC
    MOVWF PointerByte

    ; Send pointer to slave
    CALL SelectRegister

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Read two bytes containing the ADC result
    CALL ReadTwo        ; DataHigh = upper 2 bits, DataLow = lower 8 bits

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    BANKSEL PORTA
    BCF PORTA,1        ; RA1 LOW, transaction finished
    GOTO ADCTest       ; Repeat after next timer delay

; Do-Nothing Loop
Halt:
    BANKSEL PORTA
    BCF PORTA,1        ; RA1 LOW, transaction finished
    GOTO Halt          ; Wait until MCLR reset

; Select Slave Register
SelectRegister:
    ; Generate START condition
    CALL I2CStart

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send slave address with Write bit
    MOVLW SlaveWrite
    CALL I2CSend

    ; Check for ACK
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send selected register pointer
    MOVF PointerByte,W
    CALL I2CSend

    ; Check for ACK
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Generate STOP condition
    CALL I2CStop
    RETURN

; Write One Byte to Slave Register
WriteOneRegister:
    ; Generate START condition
    CALL I2CStart

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send slave address with Write bit
    MOVLW SlaveWrite
    CALL I2CSend

    ; Check for ACK
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send register pointer
    MOVF PointerByte,W
    CALL I2CSend

    ; Check for ACK
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send one data byte
    MOVF DataLow,W
    CALL I2CSend

    ; Check for ACK
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Generate STOP condition
    CALL I2CStop
    RETURN

; Read One Byte from Slave
ReadOne:
    ; Generate START condition
    CALL I2CStart

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send slave address with Read bit
    MOVLW SlaveRead
    CALL I2CSend

    ; Check for ACK
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Receive one byte from slave
    CALL I2CReceive

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Save received byte
    MOVF RxByte,W
    MOVWF DataLow      ; Store received byte in DataLow

    ; Send NACK because no more bytes are needed
    CALL I2CNack

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Generate STOP condition
    CALL I2CStop
    RETURN
    
; Read Two Bytes from Slave
ReadTwo:
    ; Generate START condition
    CALL I2CStart

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send slave address with Read bit
    MOVLW SlaveRead
    CALL I2CSend

    ; Check for ACK
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Receive first ADC byte
    CALL I2CReceive

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Save upper ADC byte
    MOVF RxByte,W
    MOVWF DataHigh

    ; Send ACK to request another byte
    CALL I2CAck

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Receive second ADC byte
    CALL I2CReceive

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Save lower ADC byte
    MOVF RxByte,W
    MOVWF DataLow

    ; Send NACK because reading is finished
    CALL I2CNack

    ; Check for errors
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Generate STOP condition
    CALL I2CStop
    RETURN

I2CStart:
    ; Check if SCL is HIGH before starting
    BANKSEL PORTC
    BTFSS PORTC,3
    GOTO BusLow        ; Error if SCL is LOW

    ; Check if SDA is HIGH before starting
    BTFSS PORTC,4
    GOTO BusLow        ; Error if SDA is LOW

    ; Clear I2C interrupt flag
    BANKSEL PIR1
    BCF PIR1,3         ; SSPIF = 0

    ; Generate START condition
    BANKSEL SSPCON2
    BSF SSPCON2,0      ; SEN = 1, begin START

    ; Wait until START finishes
    CALL WaitSSPIF
    RETURN

BusLow:
    ; I2C Bus LOW Error
    BSF ErrorFlag,2    ; ErrorFlag bit 2 = Bus LOW
    BANKSEL PORTA
    BSF PORTA,0        ; RA0 HIGH, error indicator
    RETURN


; I2C Send One Byte
I2CSend:
    ; Clear I2C interrupt flag
    BANKSEL PIR1
    BCF PIR1,3

    ; Load byte into MSSP buffer
    BANKSEL SSPBUF
    MOVWF SSPBUF       ; Hardware sends byte on SDA

    ; Wait for transmission to finish
    CALL WaitSSPIF

    ; Return if timeout occurred
    BTFSC ErrorFlag,1
    RETURN

    ; Check if slave acknowledged byte
    BANKSEL SSPCON2
    BTFSS SSPCON2,6    ; ACKSTAT = 0 means ACK
    RETURN             ; Return if ACK received

    ; Record NACK error
    BSF ErrorFlag,0    ; ErrorFlag bit 0 = NACK

    BANKSEL PORTA
    BSF PORTA,0        ; RA0 HIGH, error indicator

    ; Attempt STOP after NACK
    CALL I2CStop
    RETURN


; I2C Receive One Byte
I2CReceive:
    ; Clear I2C interrupt flag
    BANKSEL PIR1
    BCF PIR1,3

    ; Enable I2C receive mode
    BANKSEL SSPCON2
    BSF SSPCON2,3      ; RCEN = 1, receive one byte

    ; Wait until byte is received
    CALL WaitSSPIF

    ; Return if timeout occurred
    BTFSC ErrorFlag,1
    RETURN

    ; Save received byte
    BANKSEL SSPBUF
    MOVF SSPBUF,W      ; Read received byte
    MOVWF RxByte       ; Save byte for later use
    RETURN

I2CAck:
    ; Clear I2C interrupt flag
    BANKSEL PIR1
    BCF PIR1,3

    ; Set ACK data bit LOW
    BANKSEL SSPCON2
    BCF SSPCON2,5      ; ACKDT = 0 means ACK

    ; Start ACK transmission
    BSF SSPCON2,4      ; ACKEN = 1

    ; Wait until ACK finishes
    CALL WaitSSPIF
    RETURN

I2CNack:
    ; Clear I2C interrupt flag
    BANKSEL PIR1
    BCF PIR1,3

    ; Set ACK data bit HIGH
    BANKSEL SSPCON2
    BSF SSPCON2,5      ; ACKDT = 1 means NACK

    ; Start NACK transmission
    BSF SSPCON2,4      ; ACKEN = 1

    ; Wait until NACK finishes
    CALL WaitSSPIF
    
    ; Indicate NACK on RA0
    BANKSEL PORTA
    BSF PORTA,0        ; RA0 HIGH on NACK
    RETURN

I2CStop:
    ; Clear I2C interrupt flag
    BANKSEL PIR1
    BCF PIR1,3

    ; Generate STOP condition
    BANKSEL SSPCON2
    BSF SSPCON2,2      ; PEN = 1, begin STOP

    ; Wait until STOP finishes
    CALL WaitSSPIF
    RETURN

WaitSSPIF:
    ; Load timeout counters
    MOVLW 0xFF
    MOVWF WaitCount
    MOVWF WaitOuter

WaitI2C:
    ; Check if I2C operation is finished
    BANKSEL PIR1
    BTFSC PIR1,3       ; SSPIF = 1 means finished
    GOTO I2CDone

    ; Count down while waiting
    DECFSZ WaitCount,F
    GOTO WaitI2C

    DECFSZ WaitOuter,F
    GOTO WaitI2C

    ; Record timeout error
    BSF ErrorFlag,1    ; ErrorFlag bit 1 = Timeout
    BANKSEL PORTA
    BSF PORTA,0        ; RA0 HIGH, error indicator
    RETURN

I2CDone:
    ; Clear I2C interrupt flag
    BANKSEL PIR1
    BCF PIR1,3
    RETURN

WaitTimer:
    ; Reset Timer0
    BANKSEL TMR0
    CLRF TMR0          ; Start timer at zero
    BCF INTCON,2       ; Clear overflow flag

    ; Load number of Timer0 overflows
    MOVLW TimerOverflows
    MOVWF TimerCount

TimerWait:
    ; Wait for Timer0 overflow
    BTFSS INTCON,2     ; T0IF = 1 when Timer0 overflows
    GOTO TimerWait

    ; Clear overflow flag
    BCF INTCON,2

    ; Decrease remaining overflow count
    DECFSZ TimerCount,F
    GOTO TimerWait
    RETURN             ; Delay finished

END