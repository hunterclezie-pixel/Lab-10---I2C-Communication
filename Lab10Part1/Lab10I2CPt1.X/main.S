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
    TimerCount EQU 0x20   ; Counts Timer0 overflows
 
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
    MOVLW 0x28         ; SSPEN = 1, Master Mode = 1000
    MOVWF SSPCON

    BANKSEL SSPSTAT
    BSF SSPSTAT,7      ; Standard Speed (100 kHz)

    ; Set I2C clock to 100 kHz
    BANKSEL SSPADD
    MOVLW 0x09         ; 4 MHz / (4 x (9 + 1))
    MOVWF SSPADD

    ; Set up Timer0
    BANKSEL OPTION_REG
    MOVLW 0x07         ; Internal clock, 1:256 prescaler
    MOVWF OPTION_REG

    BANKSEL TMR0
    CLRF TMR0
    CLRF TimerCount
    BCF INTCON,2       ; Clear TMR0 overflow flag
    
GOTO Main

Main:
; Start a new timer interval
    BANKSEL TMR0
    CLRF TMR0
    CLRF TimerCount
    BCF INTCON,2

TimerWait:
    ; Wait for a Timer0 overflow
    BTFSS INTCON,2
    GOTO TimerWait
    BCF INTCON,2       ; Clear overflow flag
    INCF TimerCount,F

    ; Wait for 15 overflows
    MOVLW 0x0F
    XORWF TimerCount,W
    BTFSS STATUS,2
    GOTO TimerWait

    ; Timer event starts new I2C transaction
    BANKSEL PORTA
    BSF PORTA,1        ; RA1 HIGH
    CALL AddressProbe
    BANKSEL PORTA
    BCF PORTA,1        ; RA1 LOW after STOP
    GOTO Main


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

    ; Send 7-bit address 0x20 with R/W = 0
    BANKSEL PIR1
    BCF PIR1,3         ; Clear SSPIF
    MOVLW 0x40         ; Address = 0x20, Write = 0
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

END