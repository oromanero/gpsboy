
;-----------------------------------------------------------------------------
; Rutinas de manejo de la comunicaci¢n serie.
;                                                            Enrique Sanchez
;                                                            junio 2001
;-----------------------------------------------------------------------------

SECTION "Serial",HOME


;-----------------------------------------------------------------------------
; SrWaitIdle
;
; Espera que la entrada serie est‚ desocupada, mirando que est‚ a uno durante
; un cierto periodo de tiempo (el equivalente a varios bytes a 9600bps).
;     salida: C a cero si tuvo ‚xito; a otro valor si se produce un time-out.
;-----------------------------------------------------------------------------

SrWaitIdle: ld de,$ffff     ; Time-out de un segundo y pico ($ffff*18=1.125s)
            ld b,242        ; Espera aprox. 242*18 ciclos = 40 bits a 1
            ld c,b

.loop       ldio a,[RP]     ; 3
            bit 4,a         ; 2
            jr nz,.read1    ; 2/3
            ld c,b          ; 1
.read1      dec c           ; 1
            ret z           ; 2/5       retorna con C = 0 (‚xito)

            dec de          ; 2
            ld a,d          ; 1
            or e            ; 1
            jr nz,.loop     ; 2/3
            ret             ;           retorna con C > 0 (time-out)


;-----------------------------------------------------------------------------
; SrReadPkts
;
; Lee una trama de datos consecutivos (uno o varios paquetes) de la entrada
; serie a memoria. Una vez le¡dos varios bytes, se da por terminada la
; comunicaci¢n si la l¡nea permanece a 1 durante un cierto periodo (la
; duraci¢n de varios bytes) o si hay alg£n error (paridad, etc).
;     entrada: HL = direcci¢n destino en memoria.
;     salida:  HL apuntando a la direcci¢n siguiente al £ltimo byte le¡do.
;              Flag de carry a uno si se produce un time-out sin detectar
;              ning£n paquete (1.75s aproximadamente).
;-----------------------------------------------------------------------------

SrReadPkts: ld bc,46811
            ld d,2          ; Time-out: (14*BC+3)+(14*65536+3)*(D-1)

.loop       ldio a,[RP]     ; 3      \
            bit 4,a         ; 2       |
            jr z,.read1st   ; 2/3     |
                            ;         | 14
            dec bc          ; 2       |         total: (14*65536+3)*D ciclos
            ld a,b          ; 1       |
            or c            ; 1       |
            jr nz,.loop     ; 2/3    /     |
            dec d           ; 1            | +3
            jr nz,.loop     ; 2/3         /
            scf
            ret             ; retorna con error

.read1st    call delay_103c ; 103 = 121-8-6-4
            call _rdbytens  ; 6             lee el primer byte
            jr c,.exit

.readnext   ld [hl+],a      ; bucle principal de lectura de bytes
            call SrReadByte
            jr nc,.readnext

.exit       or a            ; pone el carry a cero
            ret             ; retorna al final de trama


;-----------------------------------------------------------------------------
; SrSendPkt
;
; Env¡a un paquete por la salida serie.
;     entrada: HL = datos del paquete en memoria (el primer byte indica
;              la longitud del mismo).
;-----------------------------------------------------------------------------

SrSendPkt:  ld a,[hl+]
            ld c,a
.loop       ld a,[hl+]
            call SrSendByte
            dec c
            jr nz,.loop
            ret


;-----------------------------------------------------------------------------
; SrReadByte
;
; Recibe un byte por la entrada serie, a 9600bps - paridad impar - 1 bit stop.
;     salida: Carry a uno si no se pudo leer (timeout o error);
;             valor recibido en A si el carry es cero.
;-----------------------------------------------------------------------------

; 9600 bps ---> 104.16666667 æs por bit ---> 109.22666667 ciclos de cpu

SrReadByte: ld b,$ff            ; timeout de $ff*12 = 28 bits a 1

.waitst     scf                 ; 1    \
            dec b               ; 1     |
            ret z               ; 2/5   |
                                ;       | 12
            ldio a,[RP]         ; 3     |
            bit 4,a             ; 2     |
            jr nz,.waitst       ; 2/3  /

            call delay_109c     ; 109
_rdbytens:  ld d,$80            ; 2
            ld e,0              ; 2

.nextdbit   ldio a,[RP]         ; 3    \
            swap a              ; 2     |
            ld b,a              ; 1     |
            xor e               ; 1     |
            ld e,a              ; 1     |
            srl b               ; 2     | 110
            rr d                ; 2     |
            jr c,.paritybit     ; 2/3   |
                                ;       |
            call delay_93c      ; 93    |
                                ;       |
            jr .nextdbit        ; 3    /

.paritybit  call delay_96c      ; 96
            ldio a,[RP]         ; 3
            swap a              ; 2
            xor e               ; 1
            bit 0,a             ; 2
            jr z,.prtyerror     ; 2/3

            ld a,d              ; 1
            or a                ; 1     carry a cero
            call delay_93c
            ret                 ; 4

.prtyerror  call SrWaitIdle
            scf
            ret


; ----------------------------------------------------------------------------
;  SrSendByte
;
;  Manda un byte por la salida serie, a 9600bps - paridad impar - 1 bit stop.
;      entrada: A = valor a enviar (se empieza por el bit m s bajo)
; ----------------------------------------------------------------------------

; 9600 bps ---> 104.16666667 æs por bit ---> 109.22666667 ciclos de cpu

SrSendByte: ld d,a
            ld b,8              ; bits restantes
            ld e,$FF            ; paridad (impar)

            ; bit de start

            xor a
            ldio [SB],a
            ld  a,$83
            ldio [SC],a         ;               <---

            call delay_93c      ; (109-16)

            ; bits de datos

.nextdbit   xor a               ; 1   \
            srl d               ; 2    |
            jr nc,.bitzero      ; 2/3  |
            cpl                 ; 1    |
.bitzero    ldio [SB],a         ; 3    | 16
            xor e               ; 1    |
            ld e,a              ; 1    |
            ld a,$83            ; 2    |
            ldio [SC],a         ; 3   /         <---

            dec b               ; 1
            jr z,.parity        ; 2/3
            call delay_87c      ; (109-6-16)
            jr .nextdbit        ; 3

            ; bit de paridad

.parity     call delay_96c      ; (109-4-9)
            ld a,e              ; 1  \
            ldio [SB],a         ; 3   | 9
            ld a,$83            ; 2   |
            ldio [SC],a         ; 3  /          <---

            ; bit de stop

            call delay_99c      ; (109-10)
            ld a,$FF            ; 2  \
            ldio [SB],a         ; 3   | 10
            ld a,$83            ; 2   |
            ldio [SC],a         ; 3  /          <---

            call delay_99c

            ret


; ----------------------------------------------------------------------------
;  Retardos.
; ----------------------------------------------------------------------------

delay_109c: jr @+2      ; 3 (109)
            jr @+2      ; 3 (106)
delay_103c: jr @+2      ; 3 (103)
            nop         ; 1 (100)
delay_99c:  jr @+2      ; 3 (99)
delay_96c:  jr @+2      ; 3 (96)
delay_93c:  jr @+2      ; 3 (93)
            jr @+2      ; 3 (90)
delay_87c:  nop         ; 1 (87)
            nop         ; 1 (86)
            jr @+2      ; 3 (85)
            jr @+2      ; 3 (82)
            jr @+2      ; 3 (79)
            jr @+2      ; 3 (76)
            jr @+2      ; 3 (73)
            jr @+2      ; 3 (70)
            jr @+2      ; 3 (67)
            jr @+2      ; 3 (64)
            jr @+2      ; 3 (61)
            jr @+2      ; 3 (58)
            jr @+2      ; 3 (55)
            jr @+2      ; 3 (52)
            jr @+2      ; 3 (49)
            jr @+2      ; 3 (46)
            jr @+2      ; 3 (43)
            jr @+2      ; 3 (40)
            jr @+2      ; 3 (37)
            jr @+2      ; 3 (34)
            jr @+2      ; 3 (31)
            jr @+2      ; 3 (28)
            jr @+2      ; 3 (25)
            jr @+2      ; 3 (22)
            jr @+2      ; 3 (19)
            jr @+2      ; 3 (16)
            jr @+2      ; 3 (13)
delay_10c:  ret         ; 4 (10)   (el call tarda 6 ciclos)

