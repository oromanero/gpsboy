
;-----------------------------------------------------------------------------
; Cabecera de la ROM.
;-----------------------------------------------------------------------------

SECTION "Header",HOME[0]

RST_00:     jp RST_00           ; vectores de interrupci¢n
            DB 0,0,0,0,0
RST_08:     jp RST_08
            DB 0,0,0,0,0
RST_10:     jp RST_10
            DB 0,0,0,0,0
RST_18:     jp RST_18
            DB 0,0,0,0,0
RST_20:     jp RST_20
            DB 0,0,0,0,0
RST_28:     jp RST_28
            DB 0,0,0,0,0
RST_30:     jp RST_30
            DB 0,0,0,0,0
RST_38:     jp RST_38
            DB 0,0,0,0,0
            jp VBlankInt        ; $40   VBlank
            DB 0,0,0,0,0
            jp RST_38           ; $48   LCD
            DB 0,0,0,0,0
            jp RST_38           ; $50   Timer
            DB 0,0,0,0,0
            jp RST_38           ; $58   Serial
            DB 0,0,0,0,0
            jp RST_38           ; $60   PAD
            DB 0,0,0,0,0
        REPT $100-$68
            DB 0
        ENDR

            nop                 ; $100  reset
            jp  Start

            ; logo nintendo
            DB  $CE,$ED,$66,$66,$CC,$0D,$00,$0B,$03,$73,$00,$83,$00,$0C,$00,$0D
            DB  $00,$08,$11,$1F,$88,$89,$00,$0E,$DC,$CC,$6E,$E6,$DD,$DD,$D9,$99
            DB  $BB,$BB,$67,$63,$6E,$0E,$EC,$CC,$DD,$DC,$99,$9F,$BB,$B9,$33,$3E

            ;    ÚÄÄÄÄÄnameÄÄÄÄÄ¿
            DB  "GPS BOY        €"
            DB  0,0,0           ; SGB features
            DB  $19             ; type   0:ROM ONLY     1:MBC1
                                ;        2:MBC1+RAM     3:MBC1+RAM+BATT
                                ;        5:MBC2         6:MBC2+BATTERY
            DB  4               ; ROM size  0:32K 1:64K 2:128K 3:256K 4:512K
            DB  2               ; RAM size  0:none  1:16K  2:8K  3:32K
            DB  1,0             ; country (0: Japan) / manufacturer
            DB  0,0             ; version / complement check
            DW  0               ; checksum

