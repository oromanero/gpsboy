
;-----------------------------------------------------------------------------
; Rutinas de uso b sico.
;                                                            Enrique Sanchez
;                                                            junio 2001
;-----------------------------------------------------------------------------

PltColor:   MACRO
                DW \1 + (\2<<5) + (\3<<10)
            ENDM

INCLUDE "hw.inc"

SECTION "Basic",HOME

;-----------------------------------------------------------------------------
; Selecciona p gina ROM ($0-$FF) en $4000-$7FFF (MBC5).
;-----------------------------------------------------------------------------

SetROMBank: ld [$2000],a
            ;xor a
            ;ld [$3000],a
            ret

;-----------------------------------------------------------------------------
; Interrupci¢n del vertical blanking.
;-----------------------------------------------------------------------------

VBlankInt:  push af

            ldio a,[IFr]        ; borra el flag de interrupci¢n del VBlank
            and $FE
            ldio [IFr],a

            pop af
            reti

;-----------------------------------------------------------------------------
; Lee el valor del pad y lo devuelve en el registro A, en el formato
; [st/sel/b/a/dwn/up/lft/rg], siendo 1 los bits de los botones pulsados.
;-----------------------------------------------------------------------------

ReadPad:    ld a,$DF            ; selecciona l¡nea P15
            ldio [P1],a
            ldio a,[P1]
            ldio a,[P1]
            and $0F
            ld h,a
            swap h
            ld a,$EF            ; selecciona l¡nea P14
            ldio [P1],a
            ldio a,[P1]
            ldio a,[P1]
            ldio a,[P1]
            ldio a,[P1]
            ldio a,[P1]
            ldio a,[P1]
            and $0F
            or h
            cpl
            ld h,a
            ld a,$FF            ; desconecta las l¡neas P14 y P15
            ldio [P1],a
            ld a,h
            ret

;-----------------------------------------------------------------------------
; Apaga el LCD.
;-----------------------------------------------------------------------------

LCDOff:     ldio a,[LCDC]
            or a
            ret z
            call WaitVB
            xor a
            ldio [LCDC],a
            ret

;-----------------------------------------------------------------------------
; Espera el periodo de Vertical Blanking.
;-----------------------------------------------------------------------------

WaitVB:     ldio a,[LY]         ; espera VBlank
            cp $90
            jr nc,WaitVB
.wvbb       ldio a,[LY]
            cp $90
            jr c,.wvbb
            ret

;-----------------------------------------------------------------------------
; Espera el periodo de Horizontal Blanking.
;-----------------------------------------------------------------------------

WaitHB:     ldio a,[STAT]       ; espera fin HBlank
            and $03
            jr z,WaitHB
.d          ldio a,[STAT]       ; espera comienzo HBlank
            and $03
            jr nz,.d
            ret

;-----------------------------------------------------------------------------
; Inicializa todo el hardware.
;-----------------------------------------------------------------------------

HWInit:     di                  ; interrupciones desactivadas
            call LCDOff         ; LCD desactivado
            ld a,1
            ldio [IE],a
            xor a
            ldio [IFr],a

            xor a
            ldio [TAC],a        ; timer desactivado

            ldio [NR52],a       ; sonido nulo

            ldio [SCX],a        ; scrolls a cero
            ldio [SCY],a
            ldio [WX],a
            ldio [WY],a

            ld hl,$C000         ; borra la RAM interna
            ld bc,$2000
            ld d,0
            call MemFill

            ld hl,$8000         ; borra la memoria de video
            ld bc,$2000
            ld d,0
            call MemFill
            ld a,1
            ldio [VBK],a
            ld hl,$8000
            ld bc,$2000
            ld d,0
            call MemFill

            ld a,1              ; banco 1 seleccionado en $4000-$7FFF
            call SetROMBank

            xor a               ; bancos de video y de WRAM a 0
            ldio [VBK],a
            ldio [SVBK],a

            ld hl,$FE00         ; limpia la tabla de sprites
            ld bc,40*4
            ld d,0
            call MemFill

            ret

;-----------------------------------------------------------------------------
; Copia de un bloque de memoria (pseudo LDIR).
;     Entrada: HL=origen, DE=destino, BC=longitud
;-----------------------------------------------------------------------------

MemCopy:    ld a,c
            or a
            jr z,.a
            inc b
.a          ld a,[hl+]
            ld [de],a
            inc de
            dec c
            jr nz,.a
            dec b
            jr nz,.a
            ret

;-----------------------------------------------------------------------------
; Llena un bloque de memoria con un mismo valor.
;     Entrada: HL=destino, BC=longitud, D=dato
;-----------------------------------------------------------------------------

MemFill:    ld a,c
            or a
            jr z,.a
            inc b
.a          ld a,d
.b          ld [hl+],a
            dec c
            jr nz,.b
            dec b
            jr nz,.b
            ret

;-----------------------------------------------------------------------------
; Carga paletas de fondo de CGB.
;     Entrada: HL = direcc¡on de las paletas (4 colores x 2 bytes cada una)
;               A = n£mero de paleta inicial (0-7)
;               B = n£mero de paletas a definir
;-----------------------------------------------------------------------------

LoadPalBG:  add a
            add a
            add a
            or $80
            ldio [BCPS],a
.a          ld c,8
.b          ld a,[hl+]
            ldio [BCPD],a
            dec c
            jr nz,.b
            dec b
            jr nz,.a
            ret

;-----------------------------------------------------------------------------
; Carga paletas de sprites de CGB.
;     An loga a la anterior.
;-----------------------------------------------------------------------------

LoadPalSp:  add a
            add a
            add a
            or $80
            ldio [OCPS],a
.a          ld c,8
.b          ld a,[hl+]
            ldio [OCPD],a
            dec c
            jr nz,.b
            dec b
            jr nz,.a
            ret

;-----------------------------------------------------------------------------
; Transferencias DMA durante los HBlank o de prop¢sito general.
;   Entrada:  HL = origen ($0-$7FFF ¢ $A000-$DFFF, 4 bits bajos ignorados)
;             DE = destino ($8000-$9FFF, 3 bits altos y 4 bajos ignorados)
;             C = n£mero de bloques de 16 bytes a transferir menos 1 (1-128)
;-----------------------------------------------------------------------------

DMATransHB: set 7,c
DMATransGP: ld a,h
            ldio [HDMA1],a
            ld a,l
            ldio [HDMA2],a
            ld a,d
            ldio [HDMA3],a
            ld a,e
            ldio [HDMA4],a
            ld a,c
            ldio [HDMA5],a
            ret


