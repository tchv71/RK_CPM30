include	RkConfig.mac

include b0disk.mac
include 82xx.mac
include RK86.MAC
include SCREEN.MAC

IFDEF	USE_PRG_DC
	IFDEF	EXTERNAL_PORTS
	START_CCP	EQU 0CF00H - 400H - 1000h ; Palmira with IN/OUT ports
	ELSE
	START_CCP	EQU 0CA00h - 400H ; Palmira with ports in F800-FFFF
	ENDIF
ELSE
	IFDEF	RK60K
	START_CCP	EQU 0BC00h - 400H ; RK 60k
	ELSE
	START_CCP	EQU  9000h - 400H ; Palmira
	ENDIF
ENDIF

	.phase	100h
include B0PRGDC.ASM
	.dephase
	.phase START_CCP

include CCP.ASM
include BDOS.ASM

include B1MAIN.ASM
include B2DISK.ASM
;include FDCNTR.ASM
include B1CONIO.ASM
IFDEF VDP9918
include 9918.asm
tmsFont:
include font8x16.asm
tmsFontEnd:
tmsFont8:
include fontMsx.asm
tmsFont8End:

ENDIF
include B1DISPB.ASM
include B1LSTAUX.ASM
;include B0FLPDSK.ASM
include B0FlpDmy.ASM
;include b0RAMDSK.ASM
include B0SD.ASM
include sdbios.asm
IFDEF OWN_GETC
include E0GETC.ASM
ENDIF
include DEBLOCK.ASM
BIOS_END:
IFDEF VDP9918
IF	BIOS_END GT 0FFF0h OR BIOS_END LT 1000H
	ERROR BIOS DOES NOT FIT
ENDIF
ELSE
IF	BIOS_END GT SCR_BUFF
	ERROR BIOS DOES NOT FIT
ENDIF
ENDIF
	END

