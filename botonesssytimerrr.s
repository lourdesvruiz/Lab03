;Archivo: botonesytimer0.s 
; Dispositivo: PIC16F887
; Autor: Lourdes Ruiz 
; Compilador: pic-as (v2.30), MPLABX V5.50
; 
; Programa: contador hexadecimal en PORTB y 7SEG en PORTC
    ;incrementa y decrementa en RA0 y RA1
; Hardware: LEDs en el puerto B, 7SEG en PORTC y pushbuttons en PORTA
; 
; Creado: 8 de agosto, 2021
; Ultima modificación: 5 de agosto, 2021


; PIC16F887 Configuration Bit Settings

PROCESSOR 16F887
#include <xc.inc>
    
; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)
  
PSECT udata_bank0 ;common memory
  contador: DS 1 ;1 byte // variables 
  cont_big: DS 1
  cont_small: DS 1
   
    
PSECT resVect, class=CODE, abs, delta=2
;---------------------vector reset--------------------------------
ORG 00h
resetVec:
    PAGESEL setup 
    goto setup 
    
PSECT code, delta=2, abs
ORG 100h   ;posición para iniciar el código 

 ;configuración de tablas de 7 segmentos
seg_7_tablas:
    clrf   PCLATH
    bsf    PCLATH, 0   ; PCLATH = 01 PCL = 02
    andlw  0x0f        ; limitar a numero "f", me va a poner en 0 todo lo superior y lo inferior, lo deja pasar (cualquier numero < 16)
    addwf  PCL         ; PC = PCLATH + PCL + W (PCL apunta a linea 103) (PC apunta a la siguiente linea + el valor que se sumo)
    retlw  00111111B   ;return que tambien me devuelve una literal (cuando esta en 0, me debe de devolver ese valor)
    retlw  00000110B   ;1
    retlw  01011011B   ;2
    retlw  01001111B   ;3
    retlw  01100110B   ;4
    retlw  01101101B   ;5
    retlw  01111101B   ;6
    retlw  00000111B   ;7
    retlw  01111111B   ;8
    retlw  01101111B   ;9
    retlw  01110111B   ;A
    retlw  01111100B   ;B
    retlw  00111001B   ;C
    retlw  01011110B   ;D
    retlw  01111001B   ;E
    retlw  01110001B   ;F

;------------------------configuración------------------------------
setup: 
    call config_io2
    call config_clock2
    call config_timer0_2
    banksel PORTA 

loop: 
    btfss T0IF ;cuando la bandera esta en 1, ya salta a las instrucciones
    goto  $-1  
    call  reinicio_timer0_2
    call  contador_binario 
   
    btfsc PORTA, 0      ;bit test f, skip if clear; si se presiona el pushbutton, entonces se llama a la función de incrementar 
    call inc_contador
    
    btfsc PORTA, 1
    call  dec_contador  ;si se presiona el pushbutton, entonces se llama a la función de decrementar 
    
    movf  contador, W   ;mueve la variable al acumulador 
    call  seg_7_tablas  ;llama a la tabla de 7 segmentos 
    movwf PORTC         ;la tabla nos devuelve en w el valor que los 7 segmentos reconoce como el numero 
    
    call igualdad
    
    goto loop
    
;---------------------------sub rutinas------------------------------
config_timer0_2:
    banksel TRISA 
    bcf     T0CS   ;reloj interno (utlizar ciclo de reloj)
    bcf     PSA    ;asignar el Prescaler a TMR0
    bsf     PS2
    bsf     PS1 
    bsf     PS0    ;PS = 111 (1:256)
    banksel PORTA  ;regresar a banco 0 para poder llamar a subrutina de bandera del timer0
    call    reinicio_timer0_2
    return 
    
;--------calculos de temporizador--------
;temporizador = 4*TOSC*TMR0*Prescaler 
;TOSC = 1/FOSC 
;TMR0 = 256 - N (el cual indica el valor a cargar en TMR0)
;¿valor necesario para 0.1s? 
;(4*(1/500kHz))*TMR0*256 = 0.1s
;TMR0 = 49
;256-49 = 207 / N=207
reinicio_timer0_2: 
    movlw    207
    movwf    TMR0
    bcf      T0IF    ;se apaga la bandera luego del reinicio
    return 
    
config_clock2:
    banksel OSCCON 
    bcf     IRCF2   ;IRCF = 011 500kHz 
    bsf     IRCF1
    bsf     IRCF0
    bsf     SCS     ;configurar reloj interno
    return

config_io2:
    banksel ANSEL   ;nos lleva a banco 3 (11)
    clrf    ANSEL   ;configuración de pines digitales 
    clrf    ANSELH
    
    banksel TRISA    ;nos lleva a banco 1 (01) 
    clrf    TRISB    ;salida para LEDs (contador)
    clrf    TRISC    ;salida para 7SEG
    bsf     TRISA, 0 ; RA0 como entrada para pushbutton
    bsf     TRISA, 1 ; RA1 como entrada para pushbutton
    bcf     TRISA, 2 ; RA2 como salida para LED de alarma 
    clrf    TRISD 
    
    ;---------------------valores iniciales en banco 00--------------------------
    banksel PORTA   ;nos lleva a banco 0 (00)
    clrf    PORTA 
    clrf    PORTB 
    clrf    PORTC
    
    return 
    
inc_contador:           ;incrementar el puerto B
    btfss PORTA, 0
    goto $-1 
    btfsc PORTA, 0      ;vuelve a revisar si está presionada (valor de 1)
    goto $-1            ;hasta que suelte (valor de 0) ya salta y ejecuta el resto del código 
    incf   contador, F  ;incrementa la variable
    btfsc  contador, 4  ;limita a contador de 4 bits 
    clrf   contador
    return
    
dec_contador:              ;derementar el puerto B
   btfss PORTA, 1
   goto $-1
   btfsc PORTA, 1 
   goto $-1
   decf  contador, F    
   btfsc contador, 7      ;limita a contador descendiente de 4 bits 
   call four 
   return 

four:                   ;se hace un clear en los 4 bits más signifactivos 
    bcf    contador, 4
    bcf    contador, 5
    bcf    contador, 6
    bcf    contador, 7
    return
    
contador_binario:       
    incf   PORTD  
    btfsc  PORTD, 4
    clrf   PORTD
    movlw  10
    subwf  PORTD, 0 
    btfsc  STATUS, 2 
    call  timer_segundos
    
    return
    
timer_segundos:
    clrf   PORTD 
    incf   PORTB  
    btfsc  PORTB, 4
    clrf   PORTB
    return
    
igualdad:  
    movf PORTB, W
    subwf contador, 0
    btfsc STATUS, 2
    call alarma 
    return  
    
alarma: 
    clrf PORTB 
    bsf  PORTA, 2 
    call delay_big
    bcf  PORTA, 2
    return 
 
delay_big:
    movlw 1000   ;valor inicial del contador (200*0.5mS = 100mS)
    movwf cont_big 
    call delay_small ;rutina de delay
    decfsz cont_big, 1 ;decrementar el contador 
    goto   $-2   ;ejecutar dos líneas atrás
    return
    
delay_small: ;(0.5 mS)
    movlw 165   ;valor inicial del contador 
    movwf cont_small 
    decfsz cont_small, 1 
    goto $-1
    return
    
end 
 


