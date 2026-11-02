// Hunter Clezie
// RCET3375
// Lab10I2CPt2
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
    ErrorFlag   EQU 0x70    ; Bit 0 = NACK, Bit 1 = Timeout, Bit 2 = Bus LOW
    WaitCount   EQU 0x71    ; I2C timeout counter
    PointerByte EQU 0x72    ; ADS1115 register pointer
    DataHigh    EQU 0x73    ; Upper data byte
    DataLow     EQU 0x74    ; Lower data byte
    RxByte      EQU 0x75    ; Received I2C byte
    TimerCount  EQU 0x76    ; Counts Timer0 overflows
    WaitOuter   EQU 0x77    ; Second timeout counter
   
    ; ADS1115 Address
    ADSWrite	EQU 0x90      ; ADDR = GND, Write
    ADSRead	EQU 0x91      ; ADDR = GND, Read

    ; Timer0 Settings
    TimerOption EQU 0x07   ; 1:256  prescaler
    TimerOverflows EQU 15  ; 15 overflows
 
; Reset Vector at 0000h. Execution starts here after reset.
PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup

; Interrupt Vector
PSECT isrVect,class=CODE,delta=2

; Main code section starts at 0008h. User code goes here.
PSECT code,class=CODE,delta=2

Setup:
    ; Disable analog inputs
    BANKSEL ANSEL
    CLRF ANSEL
    CLRF ANSELH

    ; Set up PORTA diagnostic outputs
    BANKSEL PORTA
    CLRF PORTA         ; RA0 and RA1 start LOW

    BANKSEL TRISA
    BCF TRISA,0        ; RA0 = NACK indicator
    BCF TRISA,1        ; RA1 = Timer diagnostic

    ; Set up I2C pins
    BANKSEL TRISC
    BSF TRISC,3        ; RC3 = SCL
    BSF TRISC,4        ; RC4 = SDA

    ; Set up MSSP for I2C Master Mode
    BANKSEL SSPCON
    CLRF SSPCON
    BANKSEL SSPCON2
    CLRF SSPCON2
    BANKSEL SSPCON
    MOVLW 0x28         ; Enable MSSP, I2C Master Mode
    MOVWF SSPCON

    BANKSEL SSPSTAT
    BSF SSPSTAT,7      ; Standard Speed (100 kHz)

    ; Set I2C clock to 100 kHz
    BANKSEL SSPADD
    MOVLW 0x09         ; 4 MHz / (4 x (9 + 1))
    MOVWF SSPADD
    
    ; Set up Timer0
    BANKSEL OPTION_REG
    MOVLW TimerOption
    MOVWF OPTION_REG
    BANKSEL TMR0
    CLRF TMR0
    BCF INTCON,2       ; Clear Timer0 overflow flag

    ; Clear variables
    BANKSEL ErrorFlag
    CLRF ErrorFlag
    CLRF TimerCount
    CLRF PointerByte
    CLRF DataHigh
    CLRF DataLow
    CLRF RxByte
    CLRF WaitCount
    CLRF WaitOuter
    
GOTO Main

Main:
    ; GOTO AddressTest	    ; Test ADS1115 addresses for ACK or NACK
    ; GOTO ReadConfigTest   ; Read the original Config register (0x8583)
    ; GOTO WriteConfigTest  ; Write new ADC settings to Config (0x4083)
    ; GOTO VerifyConfigTest ; Read Config to verify the new settings
    GOTO ContinuousTest   ; Continuously read ADC values using Timer0
    ; GOTO ReadyTest	    ; Enable ALERT/RDY to measure conversion timing

AddressTest:
    ; Start one address test
    BANKSEL PORTA
    BCF PORTA,0        ; Clear NACK indicator
    BCF PORTA,1        ; Clear timer diagnostic
    BSF PORTA,1        ; RA1 HIGH
    CALL AddressProbe
    BANKSEL PORTA
    BCF PORTA,1        ; RA1 LOW
    GOTO Halt

ReadConfigTest:
    ; Read Config Register
    BANKSEL PORTA
    BCF PORTA,0
    BSF PORTA,1        ; RA1 HIGH

    ; Select Config register
    MOVLW 0x01
    MOVWF PointerByte
    CALL SelectRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Read Config MSB and LSB
    CALL ReadRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt
    BANKSEL PORTA
    BCF PORTA,1        ; RA1 LOW
    GOTO Halt

WriteConfigTest:
    ; Write Config Register
    BANKSEL PORTA
    BCF PORTA,0
    BSF PORTA,1        ; RA1 HIGH

    ; Select Config register
    MOVLW 0x01
    MOVWF PointerByte

    ; Config = 0x4083
    MOVLW 0x40
    MOVWF DataHigh
    MOVLW 0x83
    MOVWF DataLow
    CALL WriteRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt
    BANKSEL PORTA
    BCF PORTA,1        ; RA1 LOW
    GOTO Halt

VerifyConfigTest:
    ; Verify Config Register
    BANKSEL PORTA
    BCF PORTA,0
    BSF PORTA,1        ; RA1 HIGH

    ; Select Config register
    MOVLW 0x01
    MOVWF PointerByte
    CALL SelectRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Read Config register
    CALL ReadRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt
    BANKSEL PORTA
    BCF PORTA,1
    GOTO Halt
 
ContinuousTest:
    ; Configure ADC once at startup
    ; MOVLW 0x01
    ; MOVWF PointerByte
    ; MOVLW 0x40
    ; MOVWF DataHigh
    ; MOVLW 0x83
    ; MOVWF DataLow
    ; CALL WriteRegister
    ; MOVF ErrorFlag,F
    ; BTFSS STATUS,2
    ; GOTO Halt
    
    ; This section is for testing step 6
    ; Set Lo_thresh = 0x0000
    MOVLW 0x02
    MOVWF PointerByte
    CLRF DataHigh
    CLRF DataLow
    CALL WriteRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Set Hi_thresh = 0x8000
    MOVLW 0x03
    MOVWF PointerByte
    MOVLW 0x80
    MOVWF DataHigh
    CLRF DataLow
    CALL WriteRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Enable ALERT/RDY
    ; Config = 0x4080
    MOVLW 0x01
    MOVWF PointerByte
    MOVLW 0x40
    MOVWF DataHigh
    MOVLW 0x80
    MOVWF DataLow
    CALL WriteRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

ADCMain:
    ; Wait for Timer0 interval
    CALL WaitTimer

    ; Start ADC transaction
    BANKSEL PORTA
    BCF PORTA,0
    BSF PORTA,1        ; RA1 HIGH

    ; Select Conversion register
    MOVLW 0x00
    MOVWF PointerByte
    CALL SelectRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Read two ADC bytes
    CALL ReadRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt
    BANKSEL PORTA
    BCF PORTA,1        ; RA1 LOW
    GOTO ADCMain

ReadyTest:
    ; Enable Conversion Ready
    BANKSEL PORTA
    BCF PORTA,0
    BSF PORTA,1        ; RA1 HIGH

    ; Set Lo_thresh = 0x0000
    MOVLW 0x02
    MOVWF PointerByte
    CLRF DataHigh
    CLRF DataLow
    CALL WriteRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Set Hi_thresh = 0x8000
    MOVLW 0x03
    MOVWF PointerByte
    MOVLW 0x80
    MOVWF DataHigh
    CLRF DataLow
    CALL WriteRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt

    ; Enable ALERT/RDY
    ; Config = 0x4080
    MOVLW 0x01
    MOVWF PointerByte
    MOVLW 0x40
    MOVWF DataHigh
    MOVLW 0x80
    MOVWF DataLow
    CALL WriteRegister
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    GOTO Halt
    BANKSEL PORTA
    BCF PORTA,1        ; RA1 LOW

    ; ADS1115 continues converting
    GOTO Halt

Halt:
    ; Do-Nothing Loop
    BANKSEL PORTA
    BCF PORTA,1        ; RA1 LOW
    GOTO Halt
    
AddressProbe:
    ; Clear NACK indicator before each probe
    BANKSEL PORTA
    BCF PORTA,0        ; RA0 LOW

    ; Generate START condition
    BANKSEL PIR1
    BCF PIR1,3         ; Clear SSPIF
    BANKSEL SSPCON2
    BSF SSPCON2,0      ; SEN = 1, start I2C

WaitStart:
    BTFSC SSPCON2,0    ; Wait until START finishes
    GOTO WaitStart

    ; Send 7-bit ADS1115 addresses with R/W = 0
    BANKSEL PIR1
    BCF PIR1,3         ; Clear SSPIF
    
    ; Commented out until needed for testing
    MOVLW 0x90         ; Address 0x48, Write = 0
    ; MOVLW 0x92       ; Address 0x49, Write = 0
    ; MOVLW 0x94       ; Address 0x4A, Write = 0
    ; MOVLW 0x96       ; Address 0x4B, Write = 0
    BANKSEL SSPBUF
    MOVWF SSPBUF       ; Send address byte

WaitAddress:
    BANKSEL PIR1
    BTFSS PIR1,3       ; Wait for transmission
    GOTO WaitAddress

    ; Check ACK or NACK
    BANKSEL SSPCON2
    BTFSS SSPCON2,6    ; ACKSTAT = 1 means NACK
    GOTO SendStop      ; ACK received
    BANKSEL PORTA
    BSF PORTA,0        ; NACK received, RA0 HIGH

SendStop:
    ; Generate STOP condition
    BANKSEL PIR1
    BCF PIR1,3
    BANKSEL SSPCON2
    BSF SSPCON2,2      ; PEN = 1, generate STOP

WaitStop:
    BTFSC SSPCON2,2    ; Wait until STOP finishes
    GOTO WaitStop
    RETURN
    
SelectRegister:
    ; Generate START
    CALL I2CStart
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send address + Write
    MOVLW ADSWrite
    CALL I2CSend
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send register pointer
    MOVF PointerByte,W
    CALL I2CSend
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Generate STOP
    CALL I2CStop
    RETURN

WriteRegister:
    ; Write Two Bytes to ADS1115
    ; Generate START
    CALL I2CStart
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send address + Write
    MOVLW ADSWrite
    CALL I2CSend
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send register pointer
    MOVF PointerByte,W
    CALL I2CSend
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send upper data byte
    MOVF DataHigh,W
    CALL I2CSend
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send lower data byte
    MOVF DataLow,W
    CALL I2CSend
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Generate STOP
    CALL I2CStop
    RETURN

ReadRegister:
    ; Read Two Bytes from ADS1115
    ; Generate START
    CALL I2CStart
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Send address + Read
    MOVLW ADSRead
    CALL I2CSend
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Receive upper data byte
    CALL I2CReceive
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    MOVF RxByte,W
    MOVWF DataHigh

    ; PIC sends ACK
    CALL I2CAck
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Receive lower data byte
    CALL I2CReceive
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN
    MOVF RxByte,W
    MOVWF DataLow

    ; PIC sends NACK
    CALL I2CNack
    MOVF ErrorFlag,F
    BTFSS STATUS,2
    RETURN

    ; Generate STOP
    CALL I2CStop
    RETURN

I2CStart:
    ; Generate I2C START
    ; Check that SCL and SDA are HIGH
    BANKSEL PORTC
    BTFSS PORTC,3
    GOTO BusLow

    BTFSS PORTC,4
    GOTO BusLow

    ; Clear SSPIF
    BANKSEL PIR1
    BCF PIR1,3

    ; Generate START
    BANKSEL SSPCON2
    BSF SSPCON2,0      ; SEN = 1
    CALL WaitSSPIF
    RETURN

BusLow:
    ; Bus LOW error
    BANKSEL ErrorFlag
    BSF ErrorFlag,2
    BANKSEL PORTA
    BSF PORTA,0        ; RA0 HIGH
    RETURN

I2CSend:
    ; Send One I2C Byte
    ; Clear SSPIF
    BANKSEL PIR1
    BCF PIR1,3

    ; Send byte
    BANKSEL SSPBUF
    MOVWF SSPBUF
    CALL WaitSSPIF

    ; Check for timeout
    BTFSC ErrorFlag,1
    RETURN

    ; Check ACK or NACK
    BANKSEL SSPCON2
    BTFSS SSPCON2,6
    RETURN             ; ACK received

    ; NACK received
    BANKSEL ErrorFlag
    BSF ErrorFlag,0
    BANKSEL PORTA
    BSF PORTA,0        ; RA0 HIGH

    ; Attempt STOP after NACK
    CALL I2CStop
    RETURN 

I2CReceive:
    ; Receive One I2C Byte
    ; Clear SSPIF
    BANKSEL PIR1
    BCF PIR1,3

    ; Enable receive
    BANKSEL SSPCON2
    BSF SSPCON2,3      ; RCEN = 1
    CALL WaitSSPIF

    ; Do not use data after timeout
    BTFSC ErrorFlag,1
    RETURN

    ; Save received byte
    BANKSEL SSPBUF
    MOVF SSPBUF,W
    MOVWF RxByte
    RETURN
    
I2CAck:
    ; PIC Sends ACK
    BANKSEL PIR1
    BCF PIR1,3
    BANKSEL SSPCON2
    BCF SSPCON2,5      ; ACKDT = 0
    BSF SSPCON2,4      ; ACKEN = 1
    CALL WaitSSPIF
    RETURN

I2CNack:
    ; PIC Sends NACK 
    BANKSEL PIR1
    BCF PIR1,3
    BANKSEL SSPCON2
    BSF SSPCON2,5      ; ACKDT = 1
    BSF SSPCON2,4      ; ACKEN = 1
    CALL WaitSSPIF
    RETURN

I2CStop:
    ; Generate I2C STOP 
    BANKSEL PIR1
    BCF PIR1,3
    BANKSEL SSPCON2
    BSF SSPCON2,2      ; PEN = 1
    CALL WaitSSPIF
    RETURN

WaitSSPIF:
    ; Wait for I2C Operation
    ; Set timeout counters
    MOVLW 0xFF
    MOVWF WaitCount
    MOVWF WaitOuter

WaitI2C:
    BANKSEL PIR1
    BTFSC PIR1,3
    GOTO I2CDone
    DECFSZ WaitCount,F
    GOTO WaitI2C
    DECFSZ WaitOuter,F
    GOTO WaitI2C

    ; I2C timeout
    BSF ErrorFlag,1
    BANKSEL PORTA
    BSF PORTA,0        ; RA0 HIGH
    RETURN

I2CDone:
    BANKSEL PIR1
    BCF PIR1,3         ; Clear SSPIF
    RETURN

WaitTimer:
    ; Reset Timer0
    BANKSEL TMR0
    CLRF TMR0
    BCF INTCON,2       ; Clear overflow flag

    ; Set overflow count
    MOVLW TimerOverflows
    MOVWF TimerCount

TimerWait:
    BTFSS INTCON,2
    GOTO TimerWait
    BCF INTCON,2       ; Clear overflow flag
    DECFSZ TimerCount,F
    GOTO TimerWait
    RETURN

END