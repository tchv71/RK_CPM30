OWN_GETC	EQU	1
USE_PRG_DC	EQU	1
IFDEF	USE_PRG_DC
START_CCP	EQU 0CA00h
ELSE
START_CCP	EQU 9200h-3
ENDIF

include b0disk.mac
include 82xx.mac
include RK86.MAC
include SCREEN.MAC

IFDEF	USE_PRG_DC
	.phase	100h
include B0PRGDC.ASM
	.dephase
	.phase START_CCP
ELSE
	.phase START_CCP
	JMP	BOOT
ENDIF

include CCP.ASM
include BDOS.ASM
;IFDEF	USE_PRG_DC
;	.dephase
;	.phase 0E000h
;ENDIF
include B1MAIN.ASM
include B2DISK.ASM
;include FDCNTR.ASM
include B1CONIO.ASM
include B1DISPB.ASM
include B1LSTAUX.ASM
;include B0FLPDSK.ASM
include B0FlpDmy.ASM
include b0RAMDSK.ASM
include B0SD.ASM
include sdbios.asm
IFDEF OWN_GETC
include E0GETC.ASM
ENDIF
BIOS_END:
	END

