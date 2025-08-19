;---------------------------------
;  Hardware registers addresses.
;---------------------------------

IF !DEF(HW_Inc)

HW_Inc  EQU 1

P1      EQU $00
SB      EQU $01
SC      EQU $02
DIVr    EQU $04
TIMA    EQU $05
TMA     EQU $06
TAC     EQU $07
IFr     EQU $0F
NR10    EQU $10
NR11    EQU $11
NR12    EQU $12
NR13    EQU $13
NR14    EQU $14
NR21    EQU $16
NR22    EQU $17
NR23    EQU $18
NR24    EQU $19
NR30    EQU $1A
NR31    EQU $1B
NR32    EQU $1C
NR33    EQU $1D
NR34    EQU $1E
NR41    EQU $20
NR42    EQU $21
NR43    EQU $22
NR44    EQU $23
NR50    EQU $24
NR51    EQU $25
NR52    EQU $26
WAVERAM EQU $FF30
LCDC    EQU $40
STAT    EQU $41
SCY     EQU $42
SCX     EQU $43
LY      EQU $44
LYC     EQU $45
DMA     EQU $46
BGP     EQU $47
OBP0    EQU $48
OBP1    EQU $49
WY      EQU $4A
WX      EQU $4B
KEY1    EQU $4D
VBK     EQU $4F
HDMA1   EQU $51
HDMA2   EQU $52
HDMA3   EQU $53
HDMA4   EQU $54
HDMA5   EQU $55
RP      EQU $56
BCPS    EQU $68
BCPD    EQU $69
OCPS    EQU $6A
OCPD    EQU $6B
SVBK    EQU $70
IE      EQU $FF

CH1_ENT             EQU $10
CH1_WAVE            EQU $11
CH1_ENV             EQU $12
CH1_FREQ_LO         EQU $13
CH1_FREQ_HI_KICK    EQU $14
CH2_WAVE            EQU $16
CH2_ENV             EQU $17
CH2_FREQ_LO         EQU $18
CH2_FREQ_HI_KICK    EQU $19
CH3_ONOFF           EQU $1A
CH3_LENGTH          EQU $1B
CH3_VOLUME          EQU $1C
CH3_FREQ_LO         EQU $1D
CH3_FREQ_HI_KICK    EQU $1E
CH4_LENGTH          EQU $20
CH4_ENV             EQU $21
CH4_POLY            EQU $22
CH4_KICK            EQU $23
SND_VIN             EQU $24
SND_STEREO          EQU $25
SND_STAT            EQU $26

ENDC

