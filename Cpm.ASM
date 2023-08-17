include	RkConfig.mac

include b0disk.mac
include 82xx.mac
include RK86.MAC
include SCREEN.MAC

IFDEF	USE_PRG_DC
IFDEF	EXTERNAL_PORTS
START_CCP	EQU 0D200H
ELSE
START_CCP	EQU 0CA00h
ENDIF
ELSE
START_CCP	EQU 9200h-3
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

