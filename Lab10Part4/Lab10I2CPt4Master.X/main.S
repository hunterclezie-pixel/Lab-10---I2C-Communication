// Hunter Clezie
// RCET3375
// Lab10I2CPt4Master
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
    RxBuffer      EQU 0x20         ; 24 received UART payload bytes: 0x20-0x37
    TxBuffer      EQU 0x38         ; 24 reply payload bytes: 0x38-0x4F
      
    RxState       EQU 0x50         ; 0=header, 1=command, 2=length, 3=data
    CommandByte   EQU 0x51         ; UART command from the PC
    RequestLength EQU 0x52         ; Number of payload bytes specified by PC
    RequestCount  EQU 0x53         ; Number of payload bytes received
    UARTByte      EQU 0x54         ; Most recent byte received through UART
    DeviceAddress EQU 0x55         ; 7-bit I2C address from PC
    AddressWrite  EQU 0x56         ; Shifted 8-bit write address
    AddressRead   EQU 0x57         ; Shifted 8-bit read address
    BytesLeft     EQU 0x58         ; Bytes still remaining in I2C/reply transfer
    ReplyLength   EQU 0x59         ; Number of bytes in UART reply payload
    I2CError      EQU 0x5A         ; 0=none, 1=NACK, 2=timeout, 3=bus LOW, 4=SCL LOW
    ErrorCategory EQU 0x5B         ; Category byte for UART error reply
    ErrorDetail   EQU 0x5C         ; Detail byte for UART error reply
    SendByte      EQU 0x5D         ; Byte currently being transmitted through UART
    RxByte        EQU 0x5E         ; Last byte received from I2C device
    WaitCount     EQU 0x5F         ; First I2C timeout counter
    WaitOuter     EQU 0x60         ; Second I2C timeout counter

; UART Command Settings
    StartByte     EQU 0x24         ; UART packet header (0x24)
    MaxPayload    EQU 24           ; Maximum accepted UART payload length
    MaxRead       EQU 23           ; Maximum number of I2C bytes read

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
    CLRF ANSEL                ; Disable analog inputs AN0-AN7
    CLRF ANSELH               ; Disable remaining analog inputs
    BANKSEL CM1CON0
    CLRF CM1CON0              ; Disable comparator 1
    BANKSEL CM2CON0
    CLRF CM2CON0              ; Disable comparator 2

    ; Set up PORTA diagnostic outputs
    BANKSEL PORTA
    CLRF PORTA                ; Start RA0 and RA1 LOW
    BANKSEL TRISA
    BCF TRISA,0               ; RA0 = I2C error indicator
    BCF TRISA,1               ; RA1 = I2C transaction indicator

    ; Set up I2C and UART communication pins
    BANKSEL TRISC
    BSF TRISC,3             ; RC3 = SCL
    BSF TRISC,4             ; RC4 = SDA
    BSF TRISC,6             ; RC6 = TX controlled by EUSART
    BSF TRISC,7             ; RC7 = RX input

    ; Set up MSSP for 100 kHz I2C Master Mode
    BANKSEL SSPCON
    CLRF SSPCON               ; Clear previous MSSP settings
    BANKSEL SSPCON2
    CLRF SSPCON2              ; Clear I2C control settings
    BANKSEL SSPSTAT
    MOVLW 0x80              ; SMP=1, standard speed
    MOVWF SSPSTAT             ; Set standard-speed I2C operation

    ; Set SCL frequency to 100 kHz with 4 MHz oscillator
    BANKSEL SSPADD
    MOVLW 0x09              ; 4 MHz / [4*(9+1)] = 100 kHz
    MOVWF SSPADD              ; Set the I2C clock speed
    BANKSEL SSPCON
    MOVLW 0x28              ; SSPEN=1, I2C Master mode
    MOVWF SSPCON
    BANKSEL PIR1
    BCF PIR1,3              ; Clear SSPIF

    ; Set up UART communication at 9600 baud (8N1)
    BANKSEL BAUDCTL
    CLRF BAUDCTL            ; BRG16=0, normal polarity
    BANKSEL SPBRG
    MOVLW 25                ; 4 MHz / [16*(25+1)] ~= 9615 baud
    MOVWF SPBRG
    BANKSEL SPBRGH
    CLRF SPBRGH
    BANKSEL TXSTA
    MOVLW 0x24              ; TXEN=1, BRGH=1, SYNC=0
    MOVWF TXSTA               ; Enable UART transmitter
    BANKSEL RCSTA
    MOVLW 0x90              ; SPEN=1, CREN=1, 8-bit receive
    MOVWF RCSTA               ; Enable UART receiver

    ; Set up Timer0 for incomplete UART packet timeout
    BANKSEL OPTION_REG
    MOVLW 0x07              ; Prescaler 1:256 on Timer0
    MOVWF OPTION_REG          ; Set Timer0 prescaler to 1:256
    BANKSEL TMR0
    CLRF TMR0                 ; Start Timer0 at zero
    BCF INTCON,2              ; Clear Timer0 overflow flag

    ; Clear variables before starting the program
    BANKSEL RxState
    CLRF RxState
    CLRF CommandByte
    CLRF RequestLength
    CLRF RequestCount
    CLRF UARTByte
    CLRF DeviceAddress
    CLRF AddressWrite
    CLRF AddressRead
    CLRF BytesLeft
    CLRF ReplyLength
    CLRF I2CError
    CLRF ErrorCategory
    CLRF ErrorDetail
    CLRF SendByte
    CLRF RxByte
    CLRF WaitCount
    CLRF WaitOuter
    BCF STATUS,7            ; IRP=0: indirect buffers are in Bank 0
    
GOTO Main

Main:
    ; Check for UART receive errors before reading RCREG
    BANKSEL RCSTA
    BTFSC RCSTA,1           ; OERR = overrun
    GOTO UARTOverrun

    ; Check if a UART byte has arrived
    BANKSEL PIR1
    BTFSS PIR1,5            ; RCIF = received character available
    GOTO CheckFrameTimeout
    BANKSEL RCSTA
    BTFSC RCSTA,2           ; FERR = framing error on next byte
    GOTO UARTFraming
    BANKSEL RCREG
    MOVF RCREG,W              ; Read received UART byte
    BANKSEL UARTByte
    MOVWF UARTByte            ; Save byte for packet processing
    CALL ProcessUARTByte      ; Process the received UART byte
    GOTO Main

CheckFrameTimeout:
    ; Reset the receiver if a partial UART packet takes too long
    BANKSEL RxState
    MOVF RxState,F
    BTFSC STATUS,2          ; No frame in progress
    GOTO Main
    BANKSEL INTCON
    BTFSS INTCON,2          ; Timer0 overflow after ~65 ms
    GOTO Main
    BANKSEL RxState
    CLRF RxState            ; Discard incomplete request
    MOVLW 0x05              ; Bridge validation error
    MOVWF ErrorCategory
    MOVLW 0x01              ; Invalid or incomplete length
    MOVWF ErrorDetail
    CALL SendErrorPacket
    GOTO Main

ProcessUARTByte:
    ; Reset Timer0 after each received UART byte
    BANKSEL TMR0
    CLRF TMR0
    BCF INTCON,2
    BANKSEL RxState
    MOVF RxState,W
    XORLW 0
    BTFSC STATUS,2
    GOTO ReceiveHeader
    MOVF RxState,W
    XORLW 1
    BTFSC STATUS,2
    GOTO ReceiveCommand
    MOVF RxState,W
    XORLW 2
    BTFSC STATUS,2
    GOTO ReceiveLength
    GOTO ReceivePayload

ReceiveHeader:
    ; Look for 0x24 at the start of a UART packet
    MOVF UARTByte,W
    XORLW StartByte           ; Check for UART header 0x24
    BTFSS STATUS,2
    RETURN                  ; Ignore bytes until 0x24 arrives
    MOVLW 1
    MOVWF RxState
    RETURN

ReceiveCommand:
    ; Save the command byte sent by the PC
    MOVF UARTByte,W
    MOVWF CommandByte         ; Save UART command code
    MOVLW 2
    MOVWF RxState
    RETURN

ReceiveLength:
    ; Save the number of following payload bytes
    MOVF UARTByte,W
    MOVWF RequestLength       ; Save payload length
    CLRF RequestCount         ; Reset received-byte counter
    MOVF RequestLength,F
    BTFSC STATUS,2
    GOTO PacketReady         ; Zero-length identity/unknown command
    MOVLW 3
    MOVWF RxState
    RETURN

ReceivePayload:
    ; Save up to 24 payload bytes without overflowing the buffer
    ; Check that the next byte will fit in the input buffer
    MOVF RequestCount,W
    SUBLW 23                 ; Carry set when count <= 23
    BTFSS STATUS,0
    GOTO SkipStorage
    MOVF RequestCount,W
    ADDLW RxBuffer
    BANKSEL FSR
    MOVWF FSR
    BANKSEL UARTByte
    MOVF UARTByte,W
    BANKSEL INDF
    MOVWF INDF

SkipStorage:
    ; Count all received bytes even if the request is oversized
    BANKSEL RequestCount
    INCF RequestCount,F
    MOVF RequestLength,W
    XORWF RequestCount,W
    BTFSS STATUS,2
    RETURN

PacketReady:
    ; Process the packet after all declared bytes arrive
    BANKSEL RxState
    CLRF RxState
    CALL ProcessRequest       ; Run command after full packet arrives
    RETURN

UARTFraming:
    ; Read the bad byte and discard the damaged UART packet
    BANKSEL RCREG
    MOVF RCREG,W
    CALL FlushUART
    BANKSEL RxState
    CLRF RxState
    MOVLW 0x01              ; Lab 08 framing-error category
    MOVWF ErrorCategory
    CLRF ErrorDetail
    CALL SendErrorPacket
    GOTO Main

UARTOverrun:
    ; Report UART buffer overrun and reset the receiver
    CALL FlushUART
    BANKSEL RxState
    CLRF RxState
    MOVLW 0x02              ; Lab 08 overrun category
    MOVWF ErrorCategory
    CLRF ErrorDetail
    CALL SendErrorPacket
    GOTO Main

FlushUART:
    ; Reset the UART receiver and discard remaining bad bytes
    BANKSEL RCSTA
    BCF RCSTA,4
    BSF RCSTA,4
    BANKSEL TMR0
    CLRF TMR0
    BCF INTCON,2

FlushUARTLoop:
    ; Remove any bytes remaining in the UART buffer
    BANKSEL PIR1
    BTFSS PIR1,5
    GOTO FlushUARTWait
    BANKSEL RCREG
    MOVF RCREG,W
    BANKSEL TMR0
    CLRF TMR0
    BCF INTCON,2
    GOTO FlushUARTLoop

FlushUARTWait:
    ; Wait until no more bytes arrive
    BANKSEL INTCON
    BTFSS INTCON,2
    GOTO FlushUARTLoop
    RETURN

ProcessRequest:
    ; Reject any payload longer than 24 bytes before using I2C
    BANKSEL RequestLength
    MOVF RequestLength,W
    SUBLW MaxPayload
    BTFSS STATUS,0
    GOTO InvalidLength

    ; Compare command with Identity (0x49), Probe (0x50),
    MOVF CommandByte,W
    XORLW 0x49
    BTFSC STATUS,2
    GOTO IdentityCommand
    MOVF CommandByte,W
    XORLW 0x50
    BTFSC STATUS,2
    GOTO ProbeCommand
    MOVF CommandByte,W
    XORLW 0x57
    BTFSC STATUS,2
    GOTO WriteCommand
    MOVF CommandByte,W
    XORLW 0x52
    BTFSC STATUS,2
    GOTO ReadCommand

    ; Report an unknown UART command
    MOVLW 0x05
    MOVWF ErrorCategory
    MOVLW 0x02
    MOVWF ErrorDetail
    CALL SendErrorPacket
    RETURN

IdentityCommand:
    ; Identity request must have zero payload bytes
    MOVF RequestLength,F
    BTFSS STATUS,2
    GOTO InvalidLength
    MOVLW 0x33                ; First device ID byte
    MOVWF TxBuffer
    MOVLW 0x75                ; Second device ID byte
    MOVWF TxBuffer+1
    MOVLW 2                   ; Return two identity bytes
    MOVWF ReplyLength
    CALL SendReply
    RETURN

ProbeCommand:
    ; Probe command requires one address byte
    MOVF RequestLength,W
    XORLW 1
    BTFSS STATUS,2
    GOTO InvalidLength
    CALL CheckAddress
    MOVF ErrorCategory,F
    BTFSS STATUS,2
    GOTO SendValidationError
    CALL BeginI2C
    CALL I2CStart
    BANKSEL I2CError
    MOVF I2CError,F
    BTFSS STATUS,2
    GOTO ProbeStop
    MOVF AddressWrite,W
    CALL I2CSend

ProbeStop:
    CALL I2CStop
    GOTO FinishI2C

WriteCommand:
    ; Write request requires an address and at least one data byte
    MOVF RequestLength,W
    SUBLW 1                  ; Reject lengths 0 and 1
    BTFSC STATUS,0
    GOTO InvalidLength
    CALL CheckAddress
    MOVF ErrorCategory,F
    BTFSS STATUS,2
    GOTO SendValidationError
    CALL BeginI2C
    CALL I2CStart
    BANKSEL I2CError
    MOVF I2CError,F
    BTFSS STATUS,2
    GOTO WriteStop
    MOVF AddressWrite,W
    CALL I2CSend
    BANKSEL I2CError
    MOVF I2CError,F
    BTFSS STATUS,2
    GOTO WriteStop
    MOVF RequestLength,W
    ADDLW 0xFF              ; Subtract address byte
    MOVWF BytesLeft
    MOVLW RxBuffer+1
    BANKSEL FSR
    MOVWF FSR

WriteLoop:
    ; Send each data byte from the received UART payload
    BANKSEL INDF
    MOVF INDF,W
    CALL I2CSend              ; Send the next I2C data byte
    BANKSEL I2CError
    MOVF I2CError,F
    BTFSS STATUS,2
    GOTO WriteStop
    BANKSEL FSR
    INCF FSR,F
    BANKSEL BytesLeft
    DECFSZ BytesLeft,F
    GOTO WriteLoop

WriteStop:
    CALL I2CStop
    GOTO FinishI2C

ReadCommand:
    ; Read command requires an address and one read-count byte
    MOVF RequestLength,W
    XORLW 2
    BTFSS STATUS,2
    GOTO InvalidLength

    ; Do not allow a zero-byte read
    MOVF RxBuffer+1,F       ; Reject read count zero
    BTFSC STATUS,2
    GOTO InvalidLength

    ; Maximum read count is 23 bytes
    MOVF RxBuffer+1,W
    SUBLW MaxRead           ; Reject counts above 23
    BTFSS STATUS,0
    GOTO InvalidLength
    CALL CheckAddress
    MOVF ErrorCategory,F
    BTFSS STATUS,2
    GOTO SendValidationError

    CALL BeginI2C
    MOVF RxBuffer+1,W
    MOVWF BytesLeft
    ADDLW 1                 ; Reply payload = status + read bytes
    MOVWF ReplyLength
    CALL I2CStart
    BANKSEL I2CError
    MOVF I2CError,F
    BTFSS STATUS,2
    GOTO ReadStop
    MOVF AddressRead,W
    CALL I2CSend
    BANKSEL I2CError
    MOVF I2CError,F
    BTFSS STATUS,2
    GOTO ReadStop

    MOVLW TxBuffer+1
    BANKSEL FSR
    MOVWF FSR

ReadLoop:
    ; Read the next I2C data byte into the UART reply buffer
    CALL I2CReceive           ; Receive the next I2C data byte
    BANKSEL I2CError
    MOVF I2CError,F
    BTFSS STATUS,2
    GOTO ReadStop
    MOVF RxByte,W
    BANKSEL INDF
    MOVWF INDF
    INCF FSR,F
    BANKSEL BytesLeft
    DECFSZ BytesLeft,F
    GOTO ReadNextByte
    
    ; Last received byte gets master NACK
    CALL I2CNack              ; NACK after the final received byte
    GOTO ReadStop

ReadNextByte:
    ; ACK the received byte when more data is needed
    CALL I2CAck               ; ACK because more bytes are needed
    BANKSEL I2CError
    MOVF I2CError,F
    BTFSS STATUS,2
    GOTO ReadStop
    GOTO ReadLoop

ReadStop:
    CALL I2CStop
    GOTO FinishI2C

CheckAddress:
    ; Check Address and Request Lengths
    BANKSEL ErrorCategory
    CLRF ErrorCategory
    MOVF RxBuffer,W
    MOVWF DeviceAddress
    
    ; Only allow ordinary 7-bit I2C addresses from 0x08 to 0x77
    ; Reject reserved addresses below 0x08
    MOVLW 0x08
    SUBWF DeviceAddress,W   ; C=1 if device address >= 0x08
    BTFSS STATUS,0
    GOTO InvalidAddress

    ; Reject reserved addresses above 0x77
    MOVF DeviceAddress,W
    SUBLW 0x77              ; C=1 if address <= 0x77
    BTFSS STATUS,0
    GOTO InvalidAddress
    
    ; Shift address left and add R/W bit for I2C
    MOVF DeviceAddress,W
    MOVWF AddressWrite
    BCF STATUS,0
    RLF AddressWrite,F
    MOVF AddressWrite,W
    MOVWF AddressRead
    BSF AddressRead,0
    RETURN

; Return bridge validation error for invalid address
InvalidAddress:
    MOVLW 0x05
    MOVWF ErrorCategory
    MOVLW 0x03
    MOVWF ErrorDetail
    RETURN

; Return bridge validation error for invalid packet length
InvalidLength:
    BANKSEL ErrorCategory
    MOVLW 0x05
    MOVWF ErrorCategory
    MOVLW 0x01
    MOVWF ErrorDetail

; Send the error packet without starting I2C
SendValidationError:
    CALL SendErrorPacket
    RETURN

BeginI2C:
    ; Set the default response to a successful one-byte status
    BANKSEL I2CError
    CLRF I2CError
    MOVLW 1
    MOVWF ReplyLength       ; Default success reply: status only
    CLRF TxBuffer           ; Success status = 00
    BANKSEL PORTA
    BCF PORTA,0             ; Clear previous error LED
    BSF PORTA,1             ; Transaction active
    RETURN

FinishI2C:
    ; Finish the transaction and choose success or error reply
    BANKSEL PORTA
    BCF PORTA,1             ; Transaction finished
    BANKSEL I2CError
    MOVF I2CError,F
    BTFSS STATUS,2
    GOTO I2CFailure
    
    ; Read replies keep their status byte and returned data bytes
    CALL SendReply
    RETURN

I2CFailure:
    ; Save the I2C error and reset MSSP for the next command
    MOVF I2CError,W
    MOVWF ErrorDetail
    MOVLW 0x04
    MOVWF ErrorCategory
    CALL ResetMSSP
    CALL SendErrorPacket
    RETURN

ResetMSSP:
    ; Reset the I2C hardware after a failed transaction
    BANKSEL SSPCON
    CLRF SSPCON
    BANKSEL SSPCON2
    CLRF SSPCON2
    BANKSEL PIR1
    BCF PIR1,3
    BANKSEL SSPCON
    MOVLW 0x28
    MOVWF SSPCON
    RETURN

I2CStart:
    ; I2C Hardware Routines, generate an I2C START condition
    BANKSEL PORTC
    BTFSS PORTC,3
    GOTO SCLHeldLow
    BTFSS PORTC,4
    GOTO BusLow
    BANKSEL PIR1
    BCF PIR1,3
    BANKSEL SSPCON2
    BSF SSPCON2,0           ; SEN=1
    CALL WaitSSPIF
    RETURN

SCLHeldLow:
    ; Report error if SCL cannot return HIGH
    BANKSEL I2CError
    MOVLW 4
    MOVWF I2CError
    BANKSEL PORTA
    BSF PORTA,0
    RETURN

BusLow:
    ; Report error if the I2C bus is not idle
    BANKSEL I2CError
    MOVLW 3
    MOVWF I2CError
    BANKSEL PORTA
    BSF PORTA,0
    RETURN

I2CSend:
    ; Clear the I2C event flag
    BANKSEL PIR1
    BCF PIR1,3

    ; Send the byte currently stored in W
    BANKSEL SSPBUF
    MOVWF SSPBUF
    CALL WaitSSPIF
    BANKSEL I2CError
    MOVF I2CError,F
    BTFSS STATUS,2
    RETURN

    ; Check whether the slave acknowledged the byte
    BANKSEL SSPCON2
    BTFSS SSPCON2,6        ; ACKSTAT=0 means slave ACK
    RETURN
    BANKSEL I2CError
    MOVLW 1                 ; Address/data NACK
    MOVWF I2CError
    BANKSEL PORTA
    BSF PORTA,0
    RETURN

I2CReceive:
    BANKSEL PIR1
    BCF PIR1,3

    ; Enable hardware receiver
    BANKSEL SSPCON2
    BSF SSPCON2,3           ; RCEN=1, receive one byte
    CALL WaitSSPIF
    BANKSEL I2CError
    MOVF I2CError,F
    BTFSS STATUS,2
    RETURN
    BANKSEL SSPBUF
    MOVF SSPBUF,W
    BANKSEL RxByte
    MOVWF RxByte
    RETURN

I2CAck:
    BANKSEL PIR1
    BCF PIR1,3

    ; Set ACKDT LOW and begin the ACK cycle
    BANKSEL SSPCON2
    BCF SSPCON2,5           ; ACKDT=0
    BSF SSPCON2,4           ; ACKEN=1
    CALL WaitSSPIF
    RETURN

I2CNack:
    BANKSEL PIR1
    BCF PIR1,3

    ; Set ACKDT HIGH and begin the NACK cycle
    BANKSEL SSPCON2
    BSF SSPCON2,5           ; ACKDT=1 (normal last-byte NACK)
    BSF SSPCON2,4           ; ACKEN=1
    CALL WaitSSPIF
    RETURN

I2CStop:
    BANKSEL PIR1
    BCF PIR1,3

    ; Ask the MSSP to generate STOP
    BANKSEL SSPCON2
    BSF SSPCON2,2           ; PEN=1
    CALL WaitSSPIF
    RETURN

WaitSSPIF:
    ; Wait for I2C hardware with a limited timeout
    ; Load the two timeout counters
    BANKSEL WaitCount
    MOVLW 0xFF
    MOVWF WaitCount
    MOVWF WaitOuter

WaitI2C:
    ; Check SSPIF and decrease timeout counters
    BANKSEL PIR1
    BTFSC PIR1,3
    GOTO I2CDone
    BANKSEL WaitCount
    DECFSZ WaitCount,F
    GOTO WaitI2C
    DECFSZ WaitOuter,F
    GOTO WaitI2C
    
    ; Do not replace an error that was already detected
    MOVF I2CError,F
    BTFSS STATUS,2
    RETURN
    BANKSEL PORTC
    BTFSS PORTC,3
    GOTO SCLHeldLow
    BANKSEL I2CError
    MOVLW 2                 ; I2C operation timeout
    MOVWF I2CError
    BANKSEL PORTA
    BSF PORTA,0
    RETURN

I2CDone:
    ; Clear I2C interrupt flag after successful operation
    BANKSEL PIR1
    BCF PIR1,3
    RETURN

UARTSend:
    ; Send the byte in W through UART to the PC
    ; Keep the byte while checking TXIF
    BANKSEL SendByte
    MOVWF SendByte            ; Save UART transmit byte

WaitTX:
    ; Wait for UART transmit buffer to be available
    BANKSEL PIR1
    BTFSS PIR1,4            ; TXIF=1 when TXREG is available
    GOTO WaitTX
    BANKSEL SendByte
    MOVF SendByte,W
    BANKSEL TXREG
    MOVWF TXREG
    RETURN

SendReply:
    ; Send header, command, length, and reply payload
    ; Send 0x24, command, and length first
    MOVLW StartByte
    CALL UARTSend
    BANKSEL CommandByte
    MOVF CommandByte,W
    CALL UARTSend
    BANKSEL ReplyLength
    MOVF ReplyLength,W
    CALL UARTSend
    BANKSEL BytesLeft
    MOVF ReplyLength,W
    MOVWF BytesLeft
    MOVLW TxBuffer
    BANKSEL FSR
    MOVWF FSR

SendReplyLoop:
    ; Send each byte from the reply buffer
    BANKSEL BytesLeft
    MOVF BytesLeft,F
    BTFSC STATUS,2
    RETURN
    BANKSEL INDF
    MOVF INDF,W
    CALL UARTSend
    BANKSEL FSR
    INCF FSR,F
    BANKSEL BytesLeft
    DECFSZ BytesLeft,F
    GOTO SendReplyLoop
    RETURN

SendErrorPacket:
    ; Send UART/I2C/validation error information to the GUI
    MOVLW StartByte
    CALL UARTSend
    MOVLW 0x45
    CALL UARTSend
    MOVLW 0x02
    CALL UARTSend
    BANKSEL ErrorCategory
    MOVF ErrorCategory,W
    CALL UARTSend
    BANKSEL ErrorDetail
    MOVF ErrorDetail,W
    CALL UARTSend
    RETURN

END