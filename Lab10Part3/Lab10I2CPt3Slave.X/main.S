// Hunter Clezie
// RCET3375
// Lab10I2CPt3Slave
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
    PointerByte  EQU 0x70   ; Selected register, retained after STOP
    RxByte       EQU 0x71   ; Received I2C data
    RxCount      EQU 0x72   ; 0 = pointer, 1 = following data
    TxCount      EQU 0x73   ; Number of bytes sent in this read
    DeviceStatus EQU 0x74   ; Bit 0 = SSPOV, 1 = WCOL, 2 = bad pointer
                            ; Bit 3 = extra write, 4 = ADC valid
    LastReceived EQU 0x75   ; Step 2: stores 0xA5
    DisplayByte  EQU 0x76   ; Character waiting for display
    DisplayReady EQU 0x77   ; Bit 0 = new character
    ADCHigh      EQU 0x78   ; Last completed 10-bit conversion
    ADCLow       EQU 0x79
    TxHigh       EQU 0x7A   ; Frozen ADC result for I2C transaction
    TxLow        EQU 0x7B
    ADCState     EQU 0x7C   ; 0 = idle, 1 = converting
    DisplayPort  EQU 0x7D   ; Temporary PORTC display bits
    DelayCount   EQU 0x7E
    DelayOuter   EQU 0x7F

    SlaveAddress EQU 0x40   ; 7-bit 0x20 shifted left one

    ; 1 = Step 1/2 fixed byte testing
    ; 2 = Step 3 pointer echo testing
    ; 3 = Steps 4/5/6 full register interface
    SlaveMode EQU 2

    ; PORTB stretch: 0=normal, 1=~100us, 2=~1ms, 3=~10ms
    StretchTest EQU 0

; Reset Vector
PSECT resetVect,class=CODE,delta=2
ResetVector:
    GOTO Setup

; Interrupt Vector
PSECT isrVect,class=CODE,delta=2

; Main Code
PSECT code,class=CODE,delta=2

Setup:
    ; Configure AN2 as the only analog input
    BANKSEL ANSEL
    MOVLW 0x04          ; Enable analog input AN2
    MOVWF ANSEL
    CLRF ANSELH         ; Disable remaining analog inputs

    ; Turn off comparators so pins can be used normally
    BANKSEL CM1CON0
    CLRF CM1CON0        ; Disable Comparator 1
    BANKSEL CM2CON0
    CLRF CM2CON0        ; Disable Comparator 2

    ; Set up PORTA for the display and ADC
    BANKSEL PORTA
    CLRF PORTA          ; Clear PORTA outputs
    BSF PORTA,0         ; WR starts HIGH because it is active LOW

    BANKSEL TRISA
    BCF TRISA,0         ; RA0 = Display Write output
    BCF TRISA,3         ; RA3 = Display data bit D6
    BSF TRISA,2         ; RA2 = AN2 potentiometer input

    ; Set up PORTC for display and I2C communication
    BANKSEL PORTC
    CLRF PORTC          ; Clear PORTC outputs

    BANKSEL TRISC
    MOVLW 0b00011000    ; RC3 and RC4 are inputs
    MOVWF TRISC         ; Other PORTC pins are outputs

    ; RC3 = I2C clock (SCL)
    ; RC4 = I2C data (SDA)
    ; Remaining PORTC pins control display data

    ; Set up PORTB for six DIP switches
    BANKSEL TRISB
    MOVLW 0xFF          ; Set all PORTB pins as inputs
    MOVWF TRISB

    ; Enable weak pull-up resistors on RB0 through RB5
    BANKSEL WPUB
    MOVLW 0x3F          ; Enable pull-ups for six switches
    MOVWF WPUB

    ; Set up Timer0 for periodic ADC readings
    BANKSEL OPTION_REG
    MOVLW 0x07          ; Internal clock with 1:256 prescaler
    MOVWF OPTION_REG    ; Also enables PORTB weak pull-ups

    BANKSEL TMR0
    CLRF TMR0           ; Start Timer0 at zero
    BCF INTCON,2        ; Clear Timer0 overflow flag

    ; Set up ADC for AN2
    BANKSEL ADCON1
    MOVLW 0x80          ; Right-justified, VDD/VSS references
    MOVWF ADCON1
    
    BANKSEL ADCON0
    MOVLW 0x89          ; Select AN2, Fosc/32, enable ADC
    MOVWF ADCON0

    ; Clear application variables
    CLRF PointerByte
    CLRF RxByte
    CLRF RxCount
    CLRF TxCount
    CLRF DeviceStatus
    CLRF LastReceived
    CLRF DisplayByte
    CLRF DisplayReady
    CLRF ADCHigh
    CLRF ADCLow
    CLRF TxHigh
    CLRF TxLow
    CLRF ADCState
    CLRF DisplayPort

    ; Set up MSSP for 7-bit I2C Slave Mode
    BANKSEL SSPCON
    CLRF SSPCON         ; Clear previous MSSP settings
    BANKSEL SSPCON2
    MOVLW 0x01          ; Enable slave clock stretching
    MOVWF SSPCON2
    BANKSEL SSPSTAT
    BSF SSPSTAT,7       ; Standard-speed I2C setting

    ; Load slave address
    BANKSEL SSPADD
    MOVLW SlaveAddress  ; Slave address = 0x20
    MOVWF SSPADD

    ; Clear I2C interrupt flag
    BANKSEL PIR1
    BCF PIR1,3          ; SSPIF = 0

    ; Enable MSSP in I2C Slave Mode
    BANKSEL SSPCON
    MOVLW 0x36          ; Enable MSSP, CKP = 1, 7-bit slave
    MOVWF SSPCON

GOTO Main

Main:
    ; Check if an I2C event has occurred
    BANKSEL PIR1
    BTFSC PIR1,3        ; SSPIF = 1 means I2C event occurred
    CALL ServiceI2C     ; Handle communication with master

    ; Check if ADC needs to be updated
    CALL ServiceADC

    ; Check if display needs to be updated
    CALL UpdateDisplay
    GOTO Main           
    
; Service I2C Communication
ServiceI2C:
    ; Check for MSSP receive overflow or write collision
    BANKSEL SSPCON

    ; Record receive overflow if it occurred
    BTFSC SSPCON,6      ; SSPOV = 1 means receive overflow
    BSF DeviceStatus,0

    ; Record write collision if it occurred
    BTFSC SSPCON,7      ; WCOL = 1 means write collision
    BSF DeviceStatus,1

    ; Clear MSSP error flags
    BCF SSPCON,6        ; Clear SSPOV
    BCF SSPCON,7        ; Clear WCOL

    ; Determine whether the master sent an address or data
    BANKSEL SSPSTAT
    BTFSS SSPSTAT,5     ; D/A = 0 means address received
    GOTO SlaveAddressEvent

    ; Check whether master is reading from slave
    BTFSC SSPSTAT,2     ; R/W = 1 means master is reading
    GOTO SlaveSendNext

    ; Check if received data is available
    BTFSS SSPSTAT,0     ; BF = 1 means buffer contains data
    GOTO SlaveFinish
    GOTO SlaveReceiveData

SlaveAddressEvent:
    ; Read matched address
    BANKSEL SSPBUF
    MOVF SSPBUF,W

    ; Check if master wants to read or write
    BANKSEL SSPSTAT
    BTFSC SSPSTAT,2
    GOTO SlaveReadStart

    ; Master is writing to slave
    CLRF RxCount
    GOTO SlaveFinish

; Start Slave Read Transaction
SlaveReadStart:
    CLRF TxCount        ; Start transmitted byte count at zero
    MOVF ADCHigh,W
    MOVWF TxHigh
    MOVF ADCLow,W
    MOVWF TxLow
    GOTO SlaveSendByte  ; Prepare first byte for master

; Receive Data from Master
SlaveReceiveData:
    ; Read incoming data byte
    BANKSEL SSPBUF
    MOVF SSPBUF,W
    MOVWF RxByte        ; Save received byte

    ; Check if using Step 2 fixed-byte mode
    MOVLW SlaveMode
    XORLW 1             ; Compare SlaveMode with 1
    BTFSC STATUS,2
    GOTO SimpleReceive

    ; Check if this is the first byte after the address
    MOVF RxCount,F
    BTFSS STATUS,2      ; RxCount = 0 means first byte
    GOTO ExtraWriteData

    ; First byte is the register pointer
    MOVF RxByte,W
    MOVWF PointerByte   ; Save selected pointer
    INCF RxCount,F      ; Increase received byte count

    ; Step 3 accepts any pointer value for echo testing
    MOVLW SlaveMode
    XORLW 2
    BTFSC STATUS,2
    GOTO SlaveFinish

    ; Check pointer 0x00 = DIP switches
    MOVF PointerByte,W
    XORLW 0x00
    BTFSC STATUS,2
    GOTO SlaveFinish

    ; Check pointer 0x01 = Display
    MOVF PointerByte,W
    XORLW 0x01
    BTFSC STATUS,2
    GOTO SlaveFinish

    ; Check pointer 0x02 = ADC
    MOVF PointerByte,W
    XORLW 0x02
    BTFSC STATUS,2
    GOTO SlaveFinish

    ; Check pointer 0x04 = Device status
    MOVF PointerByte,W
    XORLW 0x04
    BTFSC STATUS,2
    GOTO SlaveFinish

    ; Record invalid pointer error
    BSF DeviceStatus,2
    GOTO SlaveFinish

; Step 2 - Receive Fixed Test Byte
SimpleReceive:
    ; Save byte sent by the master
    MOVF RxByte,W
    MOVWF LastReceived  ; Expected test value = 0xA5
    GOTO SlaveFinish

; Receive Additional Data After Pointer
ExtraWriteData:
    ; Check if full register mode is selected
    MOVLW SlaveMode
    XORLW 3
    BTFSS STATUS,2
    GOTO SlaveFinish

    ; Check if display register 0x01 was selected
    MOVF PointerByte,W
    XORLW 0x01
    BTFSS STATUS,2
    GOTO ExtraWriteError

    ; Check if this is the first data byte after pointer
    MOVF RxCount,W
    XORLW 0x01
    BTFSS STATUS,2
    GOTO ExtraWriteError

    ; Save ASCII character for display
    MOVF RxByte,W
    ANDLW 0x7F          ; Keep only seven ASCII bits
    MOVWF DisplayByte
    BSF DisplayReady,0  ; Tell main loop to update display
    INCF RxCount,F      ; Increase received byte count
    GOTO SlaveFinish

; Handle Unsupported Write Data
ExtraWriteError:
    BSF DeviceStatus,3  ; Record extra or unsupported data
    GOTO SlaveFinish

; Send Next Byte to Master
SlaveSendNext:
    ; Continue preparing data for the master
    ; Used when the master requests additional bytes
    GOTO SlaveSendByte

; Select Data to Send to Master
SlaveSendByte:
    ; Check if using fixed-byte test mode
    MOVLW SlaveMode
    XORLW 1
    BTFSC STATUS,2
    GOTO FixedByte

    ; Check if using pointer echo mode
    MOVLW SlaveMode
    XORLW 2
    BTFSC STATUS,2
    GOTO EchoByte

    ; Pointer 0x00 = Switches
    MOVF PointerByte,W
    XORLW 0x00
    BTFSC STATUS,2
    GOTO SwitchByte

    ; Pointer 0x02 = ADC
    MOVF PointerByte,W
    XORLW 0x02
    BTFSC STATUS,2
    GOTO ADCByte

    ; Pointer 0x04 = Device status
    MOVF PointerByte,W
    XORLW 0x04
    BTFSC STATUS,2
    GOTO StatusByte

    ; Invalid or write-only register requested
    BSF DeviceStatus,2
    MOVLW 0xEE          ; Error response byte
    GOTO LoadSlaveByte

; Step 2 - Send Fixed Byte
FixedByte:
    MOVLW 0x5A          ; Fixed response required for Step 2
    GOTO LoadSlaveByte

; Step 3 - Echo Register Pointer
EchoByte:
    MOVF PointerByte,W  ; Send the last pointer received
    GOTO LoadSlaveByte

; Step 4 - Read DIP Switches
SwitchByte:
    ; Check if this is the first byte being sent
    MOVF TxCount,F
    BTFSS STATUS,2
    GOTO ExtraReadError

    ; Apply optional clock-stretching delay
    CALL StretchDelay

    ; Read PORTB switch positions
    BANKSEL PORTB
    MOVF PORTB,W        ; Read all PORTB pins
    ANDLW 0x3F          ; Keep only RB5 through RB0
    GOTO LoadSlaveByte

; Step 4 - Send Device Status
StatusByte:
    ; Check if this is the first byte being sent
    MOVF TxCount,F
    BTFSS STATUS,2
    GOTO ExtraReadError

    ; Load device status flags
    MOVF DeviceStatus,W
    GOTO LoadSlaveByte

; Step 6 - Send ADC Data
ADCByte:
    ; Check which ADC byte the master is requesting
    MOVF TxCount,F
    BTFSS STATUS,2
    GOTO ADCLowByte

    ; Send upper ADC byte first
    MOVF TxHigh,W       ; Upper two bits of ADC result
    GOTO LoadSlaveByte

ADCLowByte:
    ; Check if master is requesting second byte
    MOVF TxCount,W
    XORLW 0x01
    BTFSS STATUS,2
    GOTO ExtraReadError

    ; Send lower ADC byte
    MOVF TxLow,W        ; Lower eight bits of ADC result
    GOTO LoadSlaveByte

; Handle Extra Read Request
ExtraReadError:
    ; Record that master requested too many bytes
    BSF DeviceStatus,3
    MOVLW 0xEE          ; Send error response byte

; Load Byte into I2C Buffer
LoadSlaveByte:
    ; Load selected data into MSSP transmit buffer
    BANKSEL SSPBUF
    MOVWF SSPBUF        ; Hardware sends byte to master
    INCF TxCount,F      ; Increase transmitted byte counter

    ; Check for write collision
    BANKSEL SSPCON
    BTFSC SSPCON,7      ; WCOL = 1 means write collision
    BSF DeviceStatus,1
    BCF SSPCON,7        ; Clear write collision flag
    GOTO SlaveFinish

SlaveFinish:
    ; Clear I2C interrupt flag
    BANKSEL PIR1
    BCF PIR1,3          ; SSPIF = 0

    ; Release I2C clock line
    BANKSEL SSPCON
    BSF SSPCON,4        ; CKP = 1, release SCL
    RETURN              ; Return to main loop

StretchDelay:
    ; Check selected clock-stretching test
    ; Test 1 = Short delay
    MOVLW StretchTest
    XORLW 1
    BTFSC STATUS,2
    GOTO Stretch100us

    ; Test 2 = Medium delay
    MOVLW StretchTest
    XORLW 2
    BTFSC STATUS,2
    GOTO Stretch1ms

    ; Test 3 = Long delay
    MOVLW StretchTest
    XORLW 3
    BTFSC STATUS,2
    GOTO Stretch10ms
    RETURN              ; No extra delay selected

Stretch100us:
    MOVLW 25           ; Load short delay count
    MOVWF DelayCount

Delay100Loop:
    NOP                 ; Small instruction delay
    DECFSZ DelayCount,F ; Decrease delay counter
    GOTO Delay100Loop   ; Repeat until counter reaches zero
    RETURN

Stretch1ms:
    MOVLW 10           ; Repeat short delay ten times
    MOVWF DelayOuter

Delay1msLoop:
    CALL Stretch100us   ; Run short delay
    DECFSZ DelayOuter,F ; Decrease outer counter
    GOTO Delay1msLoop   ; Repeat until finished
    RETURN

Stretch10ms:
    MOVLW 100          ; Repeat short delay 100 times
    MOVWF DelayOuter

Delay10msLoop:
    CALL Stretch100us   ; Run short delay
    DECFSZ DelayOuter,F ; Decrease outer counter
    GOTO Delay10msLoop  ; Repeat until finished
    RETURN

ServiceADC:
    ; Check whether ADC is currently converting
    MOVF ADCState,F
    BTFSC STATUS,2      ; ADCState = 0 means idle
    GOTO ADCCheckTimer

    ; Check if current ADC conversion has finished
    BANKSEL ADCON0
    BTFSC ADCON0,1      ; GO/DONE = 1 means still converting
    RETURN

    ; Read upper ADC result
    BANKSEL ADRESH
    MOVF ADRESH,W
    MOVWF ADCHigh

    ; Read lower ADC result
    BANKSEL ADRESL
    MOVF ADRESL,W
    MOVWF ADCLow

    ; Mark ADC as idle
    CLRF ADCState

    ; Indicate that a valid ADC result is available
    BSF DeviceStatus,4

; Check Timer0 for Next ADC Conversion
ADCCheckTimer:
    ; Check whether Timer0 has overflowed
    BANKSEL INTCON
    BTFSS INTCON,2      ; T0IF = 1 means overflow occurred
    RETURN

    ; Clear Timer0 overflow flag
    BCF INTCON,2

    ; Do not start another conversion if ADC is busy
    MOVF ADCState,F
    BTFSS STATUS,2
    RETURN
    
    ; Start a new ADC conversion on AN2
    BANKSEL ADCON0
    BSF ADCON0,1        ; GO/DONE = 1 starts conversion

    ; Mark ADC as converting
    MOVLW 1
    MOVWF ADCState
    RETURN

; Update DLG7137 Display
UpdateDisplay:
    ; Check if a new character is waiting
    BTFSS DisplayReady,0
    RETURN              ; Return if no update needed

    ; Clear display update flag
    BCF DisplayReady,0

    ; Prepare display data bits D0 through D2
    ; These connect to RC0, RC1, and RC2

    MOVF DisplayByte,W
    ANDLW 0x07          ; Keep lower three ASCII bits
    MOVWF DisplayPort

    ; Prepare display data bits D3 through D5
    ; These connect to RC5, RC6, and RC7
    MOVF DisplayByte,W
    ANDLW 0x38          ; Keep ASCII bits 3 through 5
    MOVWF RxByte        ; Temporarily store these bits

    ; Shift bits left twice to match PORTC connections
    BCF STATUS,0        ; Clear Carry before shifting
    RLF RxByte,F        ; Shift left once
    BCF STATUS,0
    RLF RxByte,F        ; Shift left again

    ; Combine lower and upper display bits
    MOVF RxByte,W
    IORWF DisplayPort,W ; Combine into one PORTC value

    ; Output display data on PORTC
    BANKSEL PORTC
    MOVWF PORTC

    ; Set display data bit D6 using RA3
    BANKSEL PORTA
    BCF PORTA,3         ; Clear D6 first
    BTFSC DisplayByte,6 ; Check ASCII bit 6
    BSF PORTA,3         ; Set D6 if bit 6 is HIGH

    ; Send active-LOW Write pulse to display
    ; The display reads the character when WR is pulsed LOW
    NOP                 ; Short setup delay
    BCF PORTA,0         ; WR LOW, write character
    NOP
    NOP
    BSF PORTA,0         ; WR HIGH, finish write
    RETURN

END