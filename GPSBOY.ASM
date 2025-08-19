
;-----------------------------------------------------------------------------
; GPS-BOY
;                                                            Enrique Sanchez
;                                                            junio 2001
;-----------------------------------------------------------------------------


INCLUDE "hw.inc"
INCLUDE "header.asm"
INCLUDE "basic.asm"
INCLUDE "serial.asm"

MapIniBank = 3


;-----------------------------------------------------------------------------
; Programa principal.
;-----------------------------------------------------------------------------

SECTION "Fixed",HOME


;-----------------------------------------------------------------------------
; Arranque.
;-----------------------------------------------------------------------------

Start:      ld sp,$FFFE         ; inicializa el puntero de pila

            call HWInit         ; inicializa el hardware

            call SrWaitIdle     ; espera el env¡o de dos series de paquetes
            ld hl,Buffer        ; peri¢dicos antes de hacer nada
            call SrReadPkts
            ld hl,Buffer
            push hl
            call SrReadPkts
            pop de
            ld a,l
            cp e
            jr nz,.rcvok
            ld hl,ErrorMsg0
            call ShowErrMsg
            jp Start

.rcvok      ld a,$FF            ; salida serie inicialmente a 1
            ldio [SB],a
            ld  a,$83
            ldio [SC],a

            call SrWaitIdle     ; configura puerto 1 entrada/salida TAIP
            ld hl,Pkt_SetTAIP
            call SrSendPkt
            call SrWaitIdle

            ld hl,Pkt_NoRPV     ; desconfigura paquete peri¢dico PV
            call SrSendPkt
            call SrWaitIdle
            ld hl,Pkt_GetVR     ; pide la versi¢n al protocolo TAIP
            call SrSendPkt
            ld hl,Buffer
            push hl
            call SrReadPkts
            pop de
            ld a,l
            cp e
            jr nz,.taipok
            ld hl,ErrorMsg1
            call ShowErrMsg
            jp Start

.taipok     call SendIPos       ; env¡a datos de posici¢n inicial al sensor

            xor a               ; estado inicial no v lido de los datos
            ld [Age_AL],a
            ld [Age_PV],a
            inc a
            ld [TrackingStat],a
            ld [AntennaStat],a
            ld a,6
            ld [Source_PV],a

            xor a               ; activa inicialmente la pantalla de navegaci¢n
            ld [ScreenMode],a
            call InitNavScr

            ld [RxCntr],a       ; inicia contador de recepciones

.mainloop   xor a               ; sin errores de recepci¢n inicialmente
            ld [RpErrCnt],a

            ld hl,Pkt_GetST     ; recibe paquete ST actual
            ld de,Buf_ST
            ld b,19
            call GetReport
            call ChkKeys

            ld hl,Pkt_GetAL     ; recibe paquete AL actual
            ld de,Buf_AL
            ld b,26
            call GetReport
            call ChkKeys

            ld hl,Pkt_GetPV     ; recibe paquete PV actual
            ld de,Buf_PV
            ld b,39
            call GetReport
            call ChkKeys

            ld hl,Pkt_GetTM     ; recibe paquete TM actual
            ld de,Buf_TM
            ld b,37
            call GetReport
            call ChkKeys

            ld a,[RpErrCnt]     ; comprueba si hay error
            or a
            jr z,.upd
.callrcvr   call CommRecovr     ; secuencia de recuperaci¢n si lo hay
            jr nc,.mainloop
            ld hl,ErrorMsg2
            call ShowErrMsg
            ld a,[ScreenMode]
            or a
            jr nz,.ismap
            call InitNavScr
            jr .callrcvr
.ismap      call InitMap
            jr .callrcvr

.upd        call UpdGPSData     ; actualizaci¢n de variables de datos GPS

            ld a,[ScreenMode]   ; actualiza datos de pantalla
            or a
            jr nz,.map
            call UpdNavScr      ;       navegaci¢n
            jr .nomap
.map        call UpdateMap      ;       mapa
.nomap

            ld c,50             ; retardo hasta la siguiente comunicaci¢n

.delay      ei                  ; espera vertical blank con HALT
            halt
            di
            push bc
            call ChkKeys
            pop bc
            dec c
            jr nz,.delay

            ld a,[RxCntr]       ; guarda en SRAM la posici¢n actual cada
            inc a               ; cierto n£mero de transferencias
            and $0F
            ld [RxCntr],a
            or a
            call z,UpdIPos

            jp .mainloop


;-----------------------------------------------------------------------------
; Env¡a un paquete de petici¢n de datos y recibe la respuesta.
;   entrada: HL apuntando al paquete a enviar
;            DE apuntando al buffer donde se recibe la respuesta
;            B longitud esperada del paquete respuesta
;   salida:  Incrementa la variable global RpErrCnt en caso de error.
;-----------------------------------------------------------------------------

GetReport:  push bc
            push de
            call SrSendPkt
            pop hl
            push hl
            call SrReadPkts
            pop de
            pop bc
            jr c,.rxerr
            ld a,l
            sub e
            cp b
            ret z
.rxerr      ld hl,RpErrCnt
            inc [hl]
            ret


;-----------------------------------------------------------------------------
; Intenta recuperar la comunicaci¢n con el receptor GPS en caso de haberse
; perdido o haberse producido un error.
;   salida: Carry a cero si se tuvo ‚xito; a uno si no se pudo recuperar.
;-----------------------------------------------------------------------------

CommRecovr: call SrWaitIdle     ; espera si hay paquetes peri¢dicos
            ld hl,Buffer
            call SrReadPkts
            ld hl,Buffer
            push hl
            call SrReadPkts
            pop de
            ld a,l
            cp e
            jr z,.chktaip
            ld a,[Buffer]
            cp ">"
            jr z,.isprtaip

.istsip     ld hl,Pkt_SetTAIP   ; trata de configurar el protocolo TAIP
            call SrSendPkt
            call SrWaitIdle

.isprtaip   ld hl,Pkt_NoRPV     ; desconfigura paquete peri¢dico PV
            call SrSendPkt
            call SrWaitIdle

            ld hl,Pkt_GetVR     ; pide la versi¢n del protocolo TAIP
            call SrSendPkt
            ld hl,Buffer
            push hl
            call SrReadPkts
            pop de
            ld a,l
            cp e
            jr z,.norecovr
            ld a,[Buffer]
            cp ">"
            jr nz,.norecovr
            cp a
            ret

.chktaip    ld hl,Pkt_GetVR     ; pide la versi¢n del protocolo TAIP
            call SrSendPkt
            ld hl,Buffer
            push hl
            call SrReadPkts
            pop de
            ld a,l
            cp e
            jr z,.istsip
            ld a,[Buffer]
            cp ">"
            jr nz,.istsip
            cp a
            ret

.norecovr   scf                 ; comunicaci¢n no recuperable
            ret


;-----------------------------------------------------------------------------
; Actualiza todas las variables de datos GPS actuales seg£n los £ltimos
; paquetes recibidos del sensor.
;-----------------------------------------------------------------------------

UpdGPSData: ld hl,Buf_ST + 5    ; estado de rastreo
            ld b,[hl]
            ld c,0
            ld de,TrkIcons
.tkloop     ld a,[de]
            inc de
            or a
            jr z,.tkend
            cp b
            jr z,.tkend
            inc c
            jr .tkloop
.tkend      ld a,c
            ld [TrackingStat],a
            inc hl

            ld a,[hl]           ; estado de la antena
            sub "0"
            ld [AntennaStat],a

            ld hl,Buf_AL + 9    ; altitud
            ld de,Altitude
            ld bc,6
            call MemCopy

            ld de,VSpeed        ; velocidad vertical
            ld bc,4
            call MemCopy

            inc hl              ; validez del paquete AL
            ld a,[hl]
            sub "0"
            ld [Age_AL],a

            ld hl,Buf_PV + 9    ; latitud
            ld de,Latitude
            ld a,[hl+]
            ld [de],a
            inc de
            ld a,"0"
            ld [de],a
            inc de
            ld bc,7
            call MemCopy
            ld hl,Buf_PV + 9
            ld de,DecimLat
            ld bc,8
            call MemCopy

            ld de,Longitude     ; longitud
            ld bc,9
            call MemCopy
            push hl
            ld hl,Longitude
            ld de,DecimLng
            ld bc,9
            call MemCopy
            pop hl

            ld de,Velocity      ; velocidad
            ld bc,3
            call MemCopy

            ld de,Heading       ; heading
            ld bc,3
            call MemCopy

            ld b,[hl]           ; source del paquete PV
            ld c,0
            ld de,SrcVals
.srcloop    ld a,[de]
            inc de
            or a
            jr z,.srcend
            cp b
            jr z,.srcend
            inc c
            jr .srcloop
.srcend     ld a,c
            ld [Source_PV],a
            cp 3
            jr nc,.alvl
            bit 0,a
            jr nz,.alvl
            xor a
            ld [Age_AL],a
.alvl       inc hl

            ld a,[hl]           ; validez del paquete PV
            sub "0"
            ld [Age_PV],a

            ld hl,Buf_TM + 4    ; hora GPS
            ld de,GPSTime
            ld bc,6
            call MemCopy
            inc hl
            inc hl
            inc hl

            ld de,GPSDate       ; fecha GPS
            ld bc,4
            call MemCopy
            inc hl
            inc hl
            ld bc,2
            call MemCopy

            ld hl,Latitude + 8  ; convierte decimales de latitud a minutos
            ld c,5
            call MinutConv

            ld hl,Longitude + 8 ; convierte decimales de longitud a minutos
            ld c,5
            call MinutConv

            ld hl,Velocity      ; convierte la velocidad a km/h
            call MilesToKm

            ld hl,VSpeed + 1    ; convierte la velocidad vertical a km/h
            call MilesToKm

            ret


;-----------------------------------------------------------------------------
; Env¡a al sensor las coordenadas de la £ltima posici¢n almacenada, si
; ‚sta se encuentra disponible en la SRAM.
;-----------------------------------------------------------------------------

SendIPos:   ld hl,IP_Data       ; comprueba la cabecera de los datos en SRAM
            ld de,$A000
            ld c,5
            ld a,$0A
            ld [$0000],a
            call .cmpstr
            jr nz,.novl

            ld hl,$A005         ; manda el paquete de datos y recibe respuesta
            call SrSendPkt
            ld hl,Buffer
            call SrReadPkts

.novl       xor a
            ld [$0000],a
            ret

.cmpstr     ld a,[hl+]          ; auxiliar para comparar cadenas:
            ld b,a              ;     hl=origen   de=destino  c=longitud
            ld a,[de]           ; salida: flag z a cero si son iguales
            inc de
            cp b
            ret nz
            dec c
            jr nz,.cmpstr
            ret


;-----------------------------------------------------------------------------
; Actualiza en la SRAM la posici¢n actual durante la navegaci¢n, si existen
; datos v lidos.
;-----------------------------------------------------------------------------

UpdIPos:    ld a,[Age_PV]       ; datos de posici¢n v lidos?
            or a
            ret z
            ld hl,IP_Data
            ld de,Buffer
            ld bc,23
            call MemCopy
            ld hl,Latitude
            ld de,Buffer+10
            ld a,[hl+]
            ld [de],a
            inc de
            inc hl
            ld bc,2
            call MemCopy
            ld hl,Longitude
            ld bc,4
            call MemCopy
            ld a,[Age_AL]       ; datos de altitud v lidos
            or a
            jr z,.noalv
            ld hl,Altitude
            ld bc,5
            call MemCopy

.noalv      xor a               ; copia datos como paquete en SRAM
            ld [Buffer],a
            ld hl,Buffer
            ld de,$A000
            ld bc,23
            ld a,$0A
            ld [$0000],a
            call MemCopy
            ld a,"G"
            ld [$A000],a
            xor a
            ld [$0000],a
            ret


;-----------------------------------------------------------------------------
; Inicializa la pantalla de navegaci¢n.
;-----------------------------------------------------------------------------

InitNavScr: call LCDOff

            ld hl,CharSet       ; carga tabla de caracteres
            ld de,$8000+$20*16
            ld bc,$B7*16
            call MemCopy

            ld hl,$9800         ; atributos
            ld bc,$400
            ld d,$20
            call MemFill
            ld a,1
            ldio [VBK],a
            ld hl,$9800
            ld bc,$400
            ld d,0
            call MemFill

            ld hl,NavPalettes   ; carga las paletas
            xor a
            ld b,6
            call LoadPalBG

            ld hl,NavScrAtts    ; r¢tulos y componentes varios
.navloop    xor a
            ldio [VBK],a
            ld a,[hl+]
            or a
            jr z,.navend
            ld c,a
            ld d,0
            ld a,[hl+]
            sla a
            sla a
            sla a
            sla a
            rl d
            sla a
            rl d
            add a,[hl]
            inc hl
            ld e,a
            ld a,d
            add $98
            ld d,a
            ld b,0
            push de
            push bc
            call MemCopy
            pop bc
            pop de
            ld a,[hl+]
            push hl
            ld h,d
            ld l,e
            ld d,a
            ld a,1
            ldio [VBK],a
            call MemFill
            pop hl
            jr .navloop

.navend     xor a               ; valores iniciales
            ld [HdnSetFlag],a

            ldio [SCX],a
            ldio [SCY],a

            ld a,$91            ; LCD activo
            ldio [LCDC],a

            ret


;-----------------------------------------------------------------------------
; Dibuja todos los componentes de la pantalla de navegaci¢n seg£n los
; datos disponibles actualmente.
;-----------------------------------------------------------------------------

UpdNavScr:  call WaitVB

            ld hl,InvBigStr     ; latitud
            ld bc,$0120
            ld a,[Age_PV]
            or a
            jr z,.lt1
            cp 2
            jr nz,.ltnf
            dec b
.ltnf       ld hl,Latitude
            ld c,"N"
            ld a,[hl+]
            cp "+"
            jr z,.lt1
            ld c,"S"
.lt1        ld de,$9800+ 32*1+7
            call .prncrds

            ld hl,InvBigStr     ; longitud
            ld bc,$0120
            ld a,[Age_PV]
            or a
            jr z,.lg1
            cp 2
            jr nz,.lgnf
            dec b
.lgnf       ld hl,Longitude
            ld c,"E"
            ld a,[hl+]
            cp "+"
            jr z,.lg1
            ld c,"W"
.lg1        ld de,$9800+ 32*4+7
            call .prncrds

            call WaitVB

            ld a,[AntennaStat]  ; icono de funcionamiento de la antena
            add 3
            ld b,a
            ld a,$D0
            ld hl,$9800+ 32*4+1
            call .drwicon

            ld a,[TrackingStat] ; icono de estado del rastreo
            ld b,3
            or a
            jr z,.tkgreen
            inc b
.tkgreen    add a
            add a
            add $B0
            ld hl,$9800+ 32*4+4
            call .drwicon

            ld hl,Heading       ; heading
            ld de,$9800+ 32*9+5
            ld bc,$0103
            ld a,[Age_PV]
            or a
            jr nz,.hdvl
            ld hl,InvalidStr
.hdvl       cp 2
            jr nz,.hdnf
            dec b
.hdnf       call .prnstr

            ld hl,Velocity      ; velocidad
            ld de,$9800+ 32*11+5
            ld bc,$0103
            ld a,[Age_PV]
            or a
            jr nz,.vlvl
            ld hl,InvalidStr
.vlvl       cp 2
            jr nz,.vlnf
            dec b
.vlnf       call .prnstr

            ld hl,Altitude      ; altitud
            ld de,$9800+ 32*9+12
            ld bc,$0106
            ld a,[Age_AL]
            or a
            jr nz,.atvl
            ld hl,InvalidStr
.atvl       cp 2
            jr nz,.atnf
            dec b
.atnf       call .prnstr

            ld hl,VSpeed        ; velocidad vertical
            ld de,$9800+ 32*12+12
            ld bc,$0104
            ld a,[Age_AL]
            or a
            jr nz,.vsvl
            ld hl,InvalidStr
.vsvl       cp 2
            jr nz,.vsnf
            dec b
.vsnf       call .prnstr

            ld hl,GPSTime       ; hora GPS
            ld de,$9800+ 32*14+2
            ld b,0
            ld a,[TrackingStat]
            cp 1
            jr nz,.tmvl
            ld hl,InvalidStr
            inc b
.tmvl       call .prn3fl

            ld hl,GPSDate       ; fecha GPS
            ld de,$9800+ 32*16+2
            ld b,0
            ld a,[TrackingStat]
            cp 1
            jr nz,.dtvl
            ld hl,InvalidStr
            inc b
.dtvl       call .prn3fl

            ld hl,SrcMsgs       ; mensaje de source
            ld a,[Source_PV]
            sla a
            sla a
            sla a
            ld e,a
            ld d,0
            add hl,de
            ld de,$9800+ 32*16+12
            ld bc,$0007
            call .prnstr

            ld hl,Heading       ; marcador de heading
            call DrwHdnPic

            ret

.prncrds    push de             ; auxiliar de dibujo de coordenadas con
            push hl             ; doble altura
            push bc             ; hl=cadena origen  de=destino  b=paleta
            ld c,$80            ; c="N"|"S"|"E"|"W"
            inc de
            ld a,1
            ld [Crd0Flag],a
            call .pcpi
            call .pcpi
            call .pcp
            inc de
            call .pcp
            call .pcp
            inc de
            call .pcp
            call .pcp
            call .pcp
            ld a,e
            add a,32-11
            ld e,a
            ld a,d
            adc 0
            ld d,a
            pop bc
            pop hl
            ld a,c
            ld [de],a
            inc de
            ld c,$81
            ld a,1
            ld [Crd0Flag],a
            call .pcpi
            call .pcpi
            call .pcp
            inc de
            call .pcp
            call .pcp
            inc de
            call .pcp
            call .pcp
            call .pcp
            ld a,1
            ldio [VBK],a
            pop hl
            ld a,b
            ld [hl+],a
            ld [hl+],a
            ld [hl+],a
            ld [hl+],a
            inc hl
            ld [hl+],a
            ld [hl+],a
            inc hl
            ld [hl+],a
            ld [hl+],a
            ld [hl+],a
            ld a,l
            add a,32-11
            ld l,a
            ld a,h
            adc 0
            ld h,a
            ld a,b
            ld [hl+],a
            ld [hl+],a
            ld [hl+],a
            ld [hl+],a
            inc hl
            ld [hl+],a
            ld [hl+],a
            inc hl
            ld [hl+],a
            ld [hl+],a
            ld [hl+],a
            xor a
            ldio [VBK],a
            ret
.pcp        ld a,[hl+]          ; hl=origen  de=destino  c=car cter offset
            sub $30
            add a
            add c
            ld [de],a
            inc de
            ret
.pcpi       ld a,[hl+]          ; como anterior pero ignorando ceros iniciales
            cp "0"
            jr z,.czero
            sub $30
            add a
            add c
            ld [de],a
            xor a
            ld [Crd0Flag],a
            inc de
            ret
.czero      ld a,[Crd0Flag]
            or a
            ld a," "
            jr nz,.csp
            ld a,c
.csp        ld [de],a
            inc de
            ret

.drwicon    push hl             ; auxiliar de dibujo de iconos:
            ld de,30            ; hl=destino  a=car cter inicial de icono
            ld [hl+],a          ; b=paleta
            inc a
            ld [hl+],a
            inc a
            add hl,de
            ld [hl+],a
            inc a
            ld [hl],a
            pop hl
            ld a,1
            ldio [VBK],a
            ld a,b
            ld [hl+],a
            ld [hl+],a
            add hl,de
            ld [hl+],a
            ld [hl],a
            xor a
            ldio [VBK],a
            ret

.prnstr     push de             ; auxiliar de escritura de cadenas
            push bc             ; hl=origen  de=destino  c=longitud
            ld b,0              ; b=atributos (paleta)
            call MemCopy
            pop bc
            pop hl
            ld a,1
            ldio [VBK],a
            ld a,b
.psl        ld [hl+],a
            dec c
            jr nz,.psl
            xor a
            ldio [VBK],a
            ret

.prn3fl     push de             ; como anterior pero longitud fija de 6
            ld a,[hl+]          ; separados cada dos
            ld [de],a
            inc de
            ld a,[hl+]
            ld [de],a
            inc de
            inc de
            ld a,[hl+]
            ld [de],a
            inc de
            ld a,[hl+]
            ld [de],a
            inc de
            inc de
            ld a,[hl+]
            ld [de],a
            inc de
            ld a,[hl+]
            ld [de],a
            pop hl
            ld a,1
            ldio [VBK],a
            ld a,b
            ld [hl+],a
            ld [hl+],a
            inc hl
            ld [hl+],a
            ld [hl+],a
            inc hl
            ld [hl+],a
            ld [hl],a
            xor a
            ldio [VBK],a
            ret


;-----------------------------------------------------------------------------
; Dibuja la flecha indicadora de heading en su sitio.
;   entrada: HL apuntando a una cadena ASCII con el  ngulo de tres cifras.
;-----------------------------------------------------------------------------

DrwHdnPic:  ld a,[hl+]          ; calcula el  ngulo entre dos como entero
            sub $30
            ld de,Mult50Tbl
            add e
            ld e,a
            ld a,d
            adc 0
            ld d,a
            ld a,[de]
            ld e,a
            ld a,[hl+]
            sub $30
            ld d,a
            sla a
            sla a
            add d
            add e
            ld e,a
            ld a,[hl]
            sub $30
            srl a
            add e

            cp 136              ; calcula en qu‚ cuadrante est 
            jr nc,.q4
            cp 91
            jr nc,.q3
            cp 46
            jr nc,.q2

            ld b,$05            ; primer cuadrante
            ld hl,HdnAttrs1
            jr .qend

.q2         ld b,a              ; segundo cuadrante
            ld a,90
            sub b
            ld b,$45
            ld hl,HdnAttrs2
            jr .qend

.q3         sub 90              ; tercer cuadrante
            ld b,$65
            ld hl,HdnAttrs3
            jr .qend

.q4         ld b,a              ; cuarto cuadrante
            ld a,180
            sub b
            ld b,$25
            ld hl,HdnAttrs4

.qend       push hl
            push bc

            ld hl,HdnChrPts     ; carga patrones en juego de caracteres
            add a
            ld e,a
            ld d,0
            add hl,de
            ld a,[hl+]
            ld h,[hl]
            ld l,a
            ld de,HdnPics
            add hl,de
            ld de,$8000+$D7*16
            ld a,[HdnSetFlag]
            xor 1
            ld [HdnSetFlag],a
            jr z,.chset0
            ld de,$8000+$E0*16
.chset0     ld c,8
            call DMATransHB
.wtdma      ldio a,[HDMA5]
            bit 7,a
            jr z,.wtdma

            pop bc
            pop hl

            ld c,$D7            ; escribe los atributos
            ld a,[HdnSetFlag]
            or a
            jr z,.set0
            ld c,$E0

.set0       ld de,$9800+32*9+1
        REPT 3
            call WaitHB
            ld a,[hl+]
            add c
            ld [de],a
            inc de
            ld a,[hl+]
            add c
            ld [de],a
            inc de
            ld a,[hl+]
            add c
            ld [de],a
            ld a,e
            add 30
            ld e,a
            ld a,d
            adc 0
            ld d,a
        ENDR
            ld a,1
            ldio [VBK],a

            ld hl,$9800+32*9+1
            ld de,30
        REPT 3
            call WaitHB
            ld a,b
            ld [hl+],a
            ld [hl+],a
            ld [hl],a
            add hl,de
        ENDR
            xor a
            ldio [VBK],a

            ret


;-----------------------------------------------------------------------------
; Inicializa la memoria y el modo de v¡deo para la pantalla del mapa
;-----------------------------------------------------------------------------

InitMap:    call LCDOff

            ld hl,$8000         ; patrones todos a cero
            ld bc,256*16
            ld d,0
            call MemFill
            ld a,1
            ldio [VBK],a
            ld hl,$8000
            ld bc,(21*19-256)*16
            ld d,0
            call MemFill
            xor a
            ldio [VBK],a

            ld hl,$9800         ; atributos: consecutivos de 0 a 21*19-1
            xor a
            ld de,32-21
            ld b,19
.outloop1   ld c,21
.inloop1    ld [hl+],a
            inc a
            dec c
            jr nz,.inloop1
            add hl,de
            dec b
            jr nz,.outloop1

            ld a,1
            ldio [VBK],a

            ld hl,$9800
            ld de,$0000
            ld b,19
.outloop2   ld c,21
.inloop2    ld a,d
            ld [hl+],a
            dec e
            jr nz,.nochbk
            ld d,$08
.nochbk     dec c
            jr nz,.inloop2
            ld a,l
            add 32-21
            ld l,a
            ld a,h
            adc 0
            ld h,a
            dec b
            jr nz,.outloop2

            ld hl,MapSprPtn     ; carga el patr¢n del sprite del cursor
            ld de,$8000+255*16
            ld bc,16
            call MemCopy

            xor a
            ldio [VBK],a

            ld hl,MapPalette    ; carga paleta del fondo
            xor a
            ld b,1
            call LoadPalBG

            ld hl,MapSprPalette ; carga paleta del cursor
            xor a
            ld b,1
            call LoadPalSp

            ld a,84             ; limpia la OAM y coloca el sprite del cursor
            ld [$FE00],a
            ld a,84
            ld [$FE01],a
            ld a,$FF
            ld [$FE02],a
            ld a,$08
            ld [$FE03],a
            ld hl,$FE04
            ld bc,39*4
            ld d,0
            call MemFill

            xor a
            ldio [SCX],a
            ldio [SCY],a

            ld a,$93
            ldio [LCDC],a

            ret


;-----------------------------------------------------------------------------
; Actualiza la pantalla del mapa.
;-----------------------------------------------------------------------------

UpdateMap:  ld a,[Age_PV]       ; hay coordenadas v lidas actualmente?
            or a
            jp z,.nomap

            ld hl,DecimLat      ; latitud mayor o igual que m¡nima del mapa?
            ld de,MapMinLat
            ld c,7
            call CmpAscii
            jp c,.nomap

            ld hl,MapMaxLat     ; latitud menor o igual que m xima del mapa?
            ld de,DecimLat
            ld c,7
            call CmpAscii
            jp c,.nomap

            ld hl,DecimLng      ; longitud menor o igual que m xima del mapa?
            ld de,MapMinLng
            ld c,8
            call CmpAscii
            jp c,.nomap

            ld hl,MapMaxLng     ; longitud menor o igual que m xima del mapa?
            ld de,DecimLng
            ld c,8
            call CmpAscii
            jp c,.nomap

            ld hl,MapMaxLat+1   ; calcula coordenada correspondiente Y en mapa
            ld de,DecimLat+1
            ld c,7
            call SubAscii
            ld hl,DecimLat+4
            call AsciTo16
            ld a,BANK(YCrd2Map)
            call SetROMBank
            ld hl,YCrd2Map
            srl c
            sla c
            add hl,bc
            ld a,[hl+]
            ld d,[hl]
            ld e,a
            push de
            ld a,1
            call SetROMBank

            ld hl,MapMinLng+1   ; calcula coordenada correspondiente X en mapa
            ld de,DecimLng+1
            ld c,8
            call SubAscii

            ld hl,DecimLng+5
            call AsciTo16
            ld a,BANK(XCrd2Map)
            call SetROMBank
            ld hl,XCrd2Map
            srl c
            sla c
            add hl,bc
            ld a,[hl+]
            ld h,[hl]
            ld l,a
            ld a,1
            call SetROMBank

            pop de
            call DrawMap

            ret

.nomap      ld hl,ErrorMsg3     ; muestra mensaje de mapa no disponible
            call ShowErrMsg
            xor a
            ld [ScreenMode],a
            call InitNavScr
            ret


;-----------------------------------------------------------------------------
; Dibuja la posici¢n de mapa indicada (esquina superior izquierda).
;   entrada:    HL = coordenada x (0-2047)
;               DE = coordenada y (0-2943)
;-----------------------------------------------------------------------------

DrawMap:    ld a,l              ; desglosa coordenadas
            and $7
            ld [MapScX],a       ; scrolles
            ld a,e
            and $7
            ld [MapScY],a

            sla l
            rl h
            ld a,l
            and $F0
            ld [MapTlOff],a     ; offset de primera loseta de fila en banco
            ld a,h
            ld [MapTlOff+1],a

            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            ld a,e
            and $07
            ld [MapPgRow],a     ; fila de 0 a 3 de patrones en banco

            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            ld a,e
            add MapIniBank
            ld [MapPage],a      ; banco de ROM

            call SetROMBank

            ld de,$8000
            ld c,19

.mnloop     push bc             ; bucle principal de carga de patrones a VRAM
            ld a,[MapTlOff]
            ld l,a
            ld a,[MapTlOff+1]
            ld b,a
            ld a,[MapPgRow]
            swap a
            sra a
            or $40
            or b
            ld h,a

            ld a,c
            ld c,20
            cp 7                    ; salto de banco en la fila 12
            jr nz,.nopwp

            ld c,3                  ; caso especial de salto de banco VRAM
            call DMATransHB
.wtdma1     ldio a,[HDMA5]
            bit 7,a
            jr z,.wtdma1
            ld a,1
            ldio [VBK],a
            ld de,4*16
            add hl,de
            ld de,$8000
            ld c,16
            call DMATransHB
            ld de,$8000+17*16
            jr .wtdma2

.nopwp      call DMATransHB
            ld hl,21*16
            add hl,de
            ld d,h
            ld e,l

.wtdma2     ldio a,[HDMA5]
            bit 7,a
            jr z,.wtdma2

            ld a,[MapPgRow]
            inc a
            cp 8
            jr c,.nochpg
            ld a,[MapPage]
            inc a
            ld [MapPage],a
            call SetROMBank
            xor a
.nochpg     ld [MapPgRow],a

            pop bc
            dec c
            jr nz,.mnloop

            xor a
            ldio [VBK],a
            inc a
            call SetROMBank

            call WaitHB
            ld a,[MapScX]
            ldio [SCX],a
            ld a,[MapScY]
            ldio [SCY],a

            ret


;-----------------------------------------------------------------------------
; Comprueba si se est  pulsando alg£n bot¢n y act£a en consecuencia.
;-----------------------------------------------------------------------------

ChkKeys:    call ReadPad
            bit 6,a
            ret z
            ld a,[ScreenMode]
            xor 1
            ld [ScreenMode],a
.wtrel      call ReadPad
            bit 6,a
            jr nz,.wtrel
            ld a,[ScreenMode]
            or a
            jr nz,.tomap
            call InitNavScr
            ret
.tomap      call InitMap
            ret


;-----------------------------------------------------------------------------
; Muestra un mensaje de error en pantalla.
;   entrada: HL apuntando la estructura del mensaje
;-----------------------------------------------------------------------------

ShowErrMsg: push hl

            call LCDOff

            ld hl,CharSet       ; carga tabla de caracteres
            ld de,$8000+$20*16
            ld bc,$B7*16
            call MemCopy

            ld hl,$9800         ; atributos
            ld bc,$400
            ld d,$20
            call MemFill
            ld a,1
            ldio [VBK],a
            ld hl,$9800
            ld bc,$400
            ld d,0
            call MemFill
            xor a
            ldio [VBK],a

            ld hl,NavPalettes   ; carga la primera paleta de navegaci¢n s¢lo
            xor a
            ld b,1
            call LoadPalBG

            pop hl

.oloop      ld a,[hl+]          ; copia las l¡neas del mensaje en la
            cp $FF              ; posici¢n x,y indicada
            jr z,.msgend
            ld e,a
            ld d,$98>>1
            ld a,[hl+]
            swap a
            sla a
            rl d
            or e
            ld e,a
.iloop      ld a,[hl+]
            or a
            jr z,.oloop
            ld [de],a
            inc de
            jr .iloop

.msgend     xor a
            ldio [SCX],a
            ldio [SCY],a

            ld a,$91            ; activa el LCD
            ldio [LCDC],a

.wtkey      call ReadPad        ; espera la pulsaci¢n de alg£n bot¢n
            or a
            jr z,.wtkey
.wtnokey    call ReadPad
            or a
            jr nz,.wtnokey

            ret


;-----------------------------------------------------------------------------
; Convierte una cadena de varios decimales de grado en ASCII a minutos.
;   entrada: HL apuntando a la £ltima de las cifras
;            C: n£mero de cifras
;   salida:  Cadena convertida en el lugar de la antigua.
;-----------------------------------------------------------------------------

MinutConv:  ld d,0
            ld a,[hl-]
            sub $30
            ld e,a
            push hl
            ld hl,Mult6TblBCD
            add hl,de
            ld a,[hl]
            pop hl
            swap a
            cp $50
            jr c,.noround
            inc a
.noround    and $0F
            ld b,a
            dec c

.loop       ld a,[hl]           ; b=acarreo BCD
            sub $30
            ld e,a
            push hl
            ld hl,Mult6TblBCD
            add hl,de
            ld a,[hl]
            pop hl
            add b
            daa
            ld b,a
            and $0F
            add $30
            inc hl
            ld [hl-],a
            ld a,b
            swap a
            and $0F
            ld b,a
            dec hl
            dec c
            jr nz,.loop
            inc hl
            ld a,b
            add $30
            ld [hl],a
            ret


;-----------------------------------------------------------------------------
; Convierte una cadena ASCII de tres cifras de millas a kil¢metros.
;   entrada: HL apuntando al inicio de la cadena.
;-----------------------------------------------------------------------------

MilesToKm:  push hl
            ld hl,M2KmBuf
            ld bc,10
            ld d,"0"
            call MemFill
            pop hl
            push hl
            ld de,M2KmBuf
            ld bc,3
            call MemCopy
            ld hl,M2KmBuf+3
            ld c,4
            call MinutConv
            pop hl
            push hl
            ld de,M2KmBuf+7
            ld bc,3
            call MemCopy
            call .addasc
            pop hl
            push hl
            ld de,M2KmBuf+5
            ld bc,3
            call MemCopy
            ld a,"5"
            ld [de],a
            inc de
            ld a,"0"
            ld [de],a
            call .addasc
            ld hl,M2KmBuf
            pop de
            ld bc,3
            call MemCopy
            ret

.addasc     ld hl,M2KmBuf+4
            ld de,M2KmBuf+9
            ld bc,$0005
.addaloop   ld a,[de]           ; b=acarreo BCD
            sub $30
            add b
            daa
            ld b,a
            ld a,[hl]
            sub $30
            add b
            daa
            ld b,a
            and $0F
            add $30
            ld [hl-],a
            dec de
            ld a,b
            swap a
            and $0F
            ld b,a
            dec c
            jr nz,.addaloop
            ret


;-----------------------------------------------------------------------------
; Compara dos n£meros ASCII de igual n£mero de cifras, ambos con signo.
;   entrada: HL apuntando a la cadena ASCII del primero
;            DE apuntando a la cadena ASCII del segundo
;            C = n£mero de cifras (ojo: sin contar el signo del principio)
;   salida: Carry a uno si el primero es menor que el segundo
;-----------------------------------------------------------------------------

CmpAscii:   ld a,[de]
            cp [hl]
            jr nz,.sgne
            ld b,a
.loop       inc hl
            inc de
            ld a,[de]
            cp [hl]
            jr nz,.neq
            dec c
            jr nz,.loop
            or a
            ret

.neq        push af
            ld a,b
            cp "+"
            jr z,.inv
            pop af
            ret

.inv        pop af
            ccf
            ret

.sgne       cp "+"
            jr z,.ls
            or a
            ret
.ls         scf
            ret


;-----------------------------------------------------------------------------
; Resta dos n£meros ASCII de igual n£mero de cifras sin mirar el signo.
;   entrada: HL apuntando a la cadena ASCII del minuendo
;            DE apuntando a la cadena ASCII del substraendo
;            C = n£mero de cifras
;   salida: resultado en el lugar que ocupaba el substraendo
;-----------------------------------------------------------------------------

SubAscii:   ld b,0
            add hl,bc
            ld a,e
            add c
            ld e,a
            ld a,d
            adc b
            ld d,a
            ld b,0

.loop       dec hl              ; b=acarreo BCD
            dec de
            ld a,[de]
            sub "0"
            add b
            ld b,a
            ld a,[hl]
            sub "0"
            sub b
            daa
            ld b,a
            and $0F
            add "0"
            ld [de],a
            ld a,b
            swap a
            and $01
            ld b,a
            dec c
            jr nz,.loop
            ret


;-----------------------------------------------------------------------------
; Convierte una cadena con un n£mero en ASCII a su valor en 16 bits.
;   entrada: HL apuntando a una cadena de cuatro cifras
;   salida:  BC con el valor correspondiente
;-----------------------------------------------------------------------------

AsciTo16:   ld de,AscTb1000     ; millares
            ld a,[hl+]
            sub "0"
            add a
            add e
            ld e,a
            ld a,d
            adc 0
            ld d,a
            ld a,[de]
            ld c,a
            inc de
            ld a,[de]
            ld b,a

            ld de,AscTb100      ; centenas
            ld a,[hl+]
            sub "0"
            add a
            add e
            ld e,a
            ld a,d
            adc 0
            ld d,a
            ld a,[de]
            add c
            ld c,a
            inc de
            ld a,[de]
            adc b
            ld b,a

            ld a,[hl+]          ; decenas
            sub "0"
            add a
            ld e,a
            sla a
            sla a
            add e
            add c
            ld c,a
            ld a,b
            adc 0
            ld b,a

            ld a,[hl]           ; unidades
            sub "0"
            add c
            ld c,a
            ld a,b
            adc 0
            ld b,a

            ret


;-----------------------------------------------------------------------------
; Datos en ROM.
;-----------------------------------------------------------------------------

SECTION "ROMData",DATA

CharSet:        incbin "charset.bin"
HdnPics:        incbin "hdnpics.bin"

MapSprPtn:      db $10,$28,$10,$28,$10,$EE,$FE,$00
                db $10,$EE,$10,$28,$10,$28,$00,$00

NavPalettes:    PltColor 8,8,31     ; paleta 0: letras blancas sobre fondo
                PltColor 0,0,24
                PltColor 0,0,4
                PltColor 31,31,31

                PltColor 8,8,31     ; paleta 1: letras grises sobre fondo
                PltColor 16,16,31
                PltColor 0,0,4
                PltColor 15,15,15

                PltColor 8,8,31     ; paleta 2: letras amarillas sobre fondo
                PltColor 0,0,0
                PltColor 0,0,4
                PltColor 31,31,15

                PltColor 8,8,31     ; paleta 3: iconos en verde
                PltColor 0,16,0
                PltColor 0,0,4
                PltColor 10,31,10

                PltColor 8,8,31     ; paleta 4: iconos en rojo
                PltColor 16,0,0
                PltColor 0,0,4
                PltColor 31,10,10

                PltColor 8,8,31     ; paleta 5: marcador de heading
                PltColor 0,0,0
                PltColor 20,0,0
                PltColor 31,31,31

MapPalette:     PltColor 31,31,31   ; paleta de los gr ficos del mapa
                PltColor 0,20,31
                PltColor 7,28,0
                PltColor 14,3,0

MapSprPalette:  PltColor 0,0,0      ; paleta del sprite del mapa
                PltColor 0,0,0
                PltColor 31,31,31
                PltColor 0,0,0

NavScrAtts:     db 5,1,1,$96,$97,$98,$99,$9A,0  ; logotipo GPS BOY
                db 5,2,1,$9B,$9C,$9D,$9E,$9F,0

                db 1,1,11,"`",0                 ; "§.'" de la latitud
                db 1,2,14,".",0
                db 1,1,18,"'",0

                db 1,4,11,"`",0                 ; "§.'" de la longitud
                db 1,5,14,".",0
                db 1,4,18,"'",0

                db 4,8,5,$A4,$A5,$A6,$A7,2      ; "HEADING"
                db 1,9,8,"^",0                  ; "§"
                db 2,11,8,$7B,$7D,0             ; "Km/h"
                db 1,8,2,$AF,0                  ; "N"

                db 4,8,12,$A0,$A1,$A2,$A3,2     ; "ALTITUDE"
                db 1,9,18,"~",0                 ; "m"

                db 4,11,12,$AB,$AC,$AD,$AE,2    ; "V.SPEED"
                db 2,12,16,$7B,$7D,0             ; "Km/h"

                db 3,15,12,$A8,$A9,$AA,2        ; "SOURCE"

                db 1,14,4,":",0                 ; ":" de la hora
                db 1,14,7,":",0

                db 1,16,4,"/",0                 ; "/" de la fecha
                db 1,16,7,"/",0

                db 18,6,1,$D4,$D4,$D4,$D4,$D4   ; l¡neas separadoras
                db   $D4,$D4,$D4,$D4,$D4,$D4,$D4
                db   $D4,$D4,$D4,$D4,$D4,$D4,1
                db 10,12,1,$D4,$D4,$D4,$D4,$D4,$D4,$D4,$D4,$D4,$D6,1
                db 8,13,11,$D4,$D4,$D4,$D4,$D4,$D4,$D4,$D4,1
                db 1,7,10,$D5,1
                db 1,8,10,$D5,1
                db 1,9,10,$D5,1
                db 1,10,10,$D5,1
                db 1,11,10,$D5,1
                db 1,13,10,$D5,1
                db 1,14,10,$D5,1
                db 1,15,10,$D5,1
                db 1,16,10,$D5,1,0

HdnChrPts:      incbin "hdnchpts.bin"   ; patrones del marcador de heading
HdnAttrs1:      db 0,1,2,3,4,5,6,7,8    ; atributos del marcador de heading
HdnAttrs2:      db 6,7,8,3,4,5,0,1,2
HdnAttrs3:      db 8,7,6,5,4,3,2,1,0
HdnAttrs4:      db 2,1,0,5,4,3,8,7,6

TrkIcons:       db "0","1","3","8","9","A","B","C",0    ; estados de tracking
SrcVals:        db "0","1","2","3","6","8","9",0        ; valores de source

SrcMsgs:        db "2D GPS  ","3D GPS  ","2D DGPS ","3D DGPS "
                db "DR      ","degr.DR ","unknown "

InvalidStr:     db "------"
InvBigStr:      db "::::::::"

Pkt_SetTAIP:    db 14,$10,$BC,$00,$07,$07,$03,$01,$00,$00,$01,$01,$00,$10,$03
Pkt_NoRPV:      db 13,">FPV00000000<"
Pkt_GetST:      db 5,">QST<"
Pkt_GetAL:      db 5,">QAL<"
Pkt_GetPV:      db 5,">QPV<"
Pkt_GetTM:      db 5,">QTM<"
Pkt_GetVR:      db 5,">QVR<"
IP_Data:        db "GPSIP",17,">SIP+00+000+0000<"

MapMinLat:      db "+3734378"
MapMaxLat:      db "+3742755"
MapMinLng:      db "-00600713"
MapMaxLng:      db "-00594332"

Mult6TblBCD:    db $00,$06,$12,$18,$24,$30,$36,$42,$48,$54
Mult50Tbl:      db 0,50,100,150

AscTb1000:      dw 0,1000,2000,3000,4000,5000,6000,7000,8000,9000
AscTb100:       dw 0,100,200,300,400,500,600,700,800,900

ErrorMsg0:      db 7,7,"ERROR!",0
                db 4,9,"GPS receiver",0
                db 4,10,"not detected",0,$FF

ErrorMsg1:      db 7,7,"ERROR!",0
                db 4,9,"TAIP protocol",0
                db 2,10,"does not respond",0,$FF

ErrorMsg2:      db 7,7,"ERROR!",0
                db 4,9,"Communication",0
                db 4,10,"unrecoverable",0,$FF

ErrorMsg3:      db 2,7,"No map available",0
                db 4,8,"for current",0
                db 6,9,"position",0,$FF


SECTION "CordCnvTb",DATA,BANK[2]

XCrd2Map:       incbin "xcrd2map.bin"
YCrd2Map:       incbin "ycrd2map.bin"


;-----------------------------------------------------------------------------
; Variables en RAM.
;-----------------------------------------------------------------------------

SECTION "Vars",BSS

ScreenMode:     ds 1            ; modo pantalla: 0=navegaci¢n / 1=mapa

RxCntr:         ds 1            ; contador auxiliar de recepciones de datos

Buf_ST:         ds 64           ; buffers para almacenar los paquetes actuales
Buf_AL:         ds 64
Buf_PV:         ds 64
Buf_TM:         ds 64

RpErrCnt:       ds 1            ; n£mero de errores en paquetes recibidos

TrackingStat:   ds 1            ; variables de los datos GPS actuales
AntennaStat:    ds 1

Age_AL:         ds 1
Altitude:       ds 6
VSpeed:         ds 4

Source_PV:      ds 1
Age_PV:         ds 1
Latitude:       ds 9
Longitude:      ds 9
Velocity:       ds 3
Heading:        ds 3

GPSTime:        ds 6
GPSDate:        ds 6

DecimLat:       ds 8
DecimLng:       ds 9

MapScX:         ds 1            ; varibles de la funci¢n de dibujo del mapa
MapScY:         ds 1
MapTlOff:       ds 2
MapPgRow:       ds 1
MapPage:        ds 1

M2KmBuf:        ds 10           ; variables auxiliares de funciones

HdnSetFlag:     ds 1            ; auxiliar para dibujo de gr fico de heading

Crd0Flag:       ds 1            ; auxiliar para dibujo de coordenadas

Buffer:         ds 1024         ; buffer auxiliar


