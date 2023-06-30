	.phase 9500h;0BC00h
include b0disk.mac
include 82xx.mac
include RK86.MAC
include SCREEN.MAC
;B_BASE	equ	0A000h
	JMP	BOOT
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

	END

