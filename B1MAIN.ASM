;******** CP/M BIOS V2.3 FOR R86-RK ********
;*     (C) TCHV
;*******************************************

;	B0MAIN.ASM - CP/M bios main module

;	30-MAY-1991 - FIRST VERSION
;	XX-XXX-1991 - 80-SYMBOL SCREEN MODE ADDED
;	03-JAN-1992 - ADDED 2-DRIVE SUPPORT
;	06-JAN-1992 - SECTOR INTERLEAVING FOR DRIVE B:
;	22-Mar-1992 - Add PROFI disk format
;	24-Mar-1992 - Break into modules
;	02-Nov-1992 - Add version information

;	INCLUDE         B0CONIO.H
;	INCLUDE         B0DISK.H
;	INCLUDE         B0LSTAUX.H

;EXTRN	PUTS	; FROM B0CONIO.ASM

SYSPG	EQU	0	; THE PAGE OF SYSTEM RAM
BDOSTRP EQU	5	;

DEF_DSK	EQU	4
IO_BYTE	EQU	3

	ds	bios-$
B_BASE::
;----------------------------------------------------
;	BIOS FUNCTION TABLE
	JMP	BOOT	; Cold boot of the system
WBOOT_ADR:
	JMP	WBOOT	; Warm boot of the system

	JMP	CON_ST;##;~~\
	JMP	 CONIN;##;---)- Console I/O
	JMP	CONOUT;##;__/		(see B0CONIO.ASM)

	JMP	LSTOUT;##;______  LST and AUX functions
	JMP	 PUNCH;##;  !		(see B0LSTAUX.asm)
	JMP	READER;##;_/!
;			   !
	JMP	 HOME@;##;__!_________ Disk functions
	JMP	SELDSK;##;  !	 /	(see B2DISK.asm)
	JMP	SETTRK;##;  !	!
	JMP	SETREC;##;  !	!
	JMP	SETDMA;##;  !	!
	JMP	RD_REC;##;__!___/!
	JMP	WR_REC;##;  !	!
	JMP	LST_ST;##;_/	!
	JMP	SECTRN;##;______/

	JMP	SET_CONFIG
	JMP	DATE
;	JMP	ERR_READ
;	LXI	H,C_BASE+7CDH	; SPECIAL SUBROUTINE FOR CCP
;	MOV	A,M
;	CPI	2		; MODIFICATION
;	JZ	C_BASE+76BH
;	MVI	M,2
;	JMP	C_BASE+6D8H

DATE:
	push	d
IF 0
	@in	0FFh
	mvi	a,0C0h
	@out	0FFh
	; Set PPI3 as PPI2 temporary
	mvi	a,14
	@out	PPI2
	@out	PPI2+1
	@out	PPI2+2
	@out	PPI2+3
	@in	0FFh
	mvi	a,80h
	@out	0FFh
ENDIF
	call	DispDate

IF 0
	push	psw
	@in	0FFh
	mvi	a,0C0h
	@out	0FFh
	; Restore PPI2
	mvi	a,1
	@out	PPI2
	@out	PPI2+1
	@out	PPI2+2
	@out	PPI2+3
	@in	0FFh
	mvi	a,80h
	@out	0FFh
	pop	psw
ENDIF
	pop	d
	cpi	2bh
	jz	SetClock
	ret

DispDate:
	mov	a,c
	cpi	2aH
	jz	CmdGetDate
	cpi	2bh
	jz	CmdSetDate
	cpi	2ch
	jz	CmdGetTime
	cpi	2dh
	jz	CmdSetTime
	mvi	A,0FFH
	ret

SET_CONFIG:
	XCHG
	LXI	D,VRAM
	MOV	M,E
	INX	H
	MOV	M,D
	INX	H

	LXI	D,PPI
	MOV	M,E
	INX	H
	MOV	M,D
	INX	H

	LXI	D,PPI2
	MOV	M,E
	INX	H
	MOV	M,D
	INX	H

	LXI	D,DISP
	MOV	M,E
	INX	H
	MOV	M,D
	INX	H

	LXI	D,DMA
	MOV	M,E
	INX	H
	MOV	M,D
	INX	H

IFDEF PALM_CNTRL
	LXI	D,PALM_CNTRL
	MOV	M,E
	INX	H
	MOV	M,D
	INX	H
ENDIF
	LXI	D,PPI3
	MOV	M,E
	INX	H
	MOV	M,D
	INX	H
	RET


;------ FIRST TIME INITIALIZATION --------

BOOT:
	;JMP	0F86Ch
	MVI	a,80h
	@out	PALM_CNTRL
	LXI	SP,C_BASE-100h
	CALL	DskInit;##
	;CALL	SETSCR
	CALL	SAV_SYS;##
IFDEF	VDP9918
	CALL	T_Reset
ENDIF
	CALL	SETSCR
	CALL	LOAD_FONT
	CALL	PRNT;##
IFNDEF	VDP9918
	DB	1FH
ENDIF
	DB	'CP/M-80 vers. 2.2'
	DB	0DH,0AH,'Copyright (C) 1980, Digital Research'
	DB	0DH,0AH,'BIOS vers. 3.2      (c) TCHV,1991-92'
	DB	",2023", 0DH, 0AH
IFDEF	USE_PRG_DC
IFDEF EXTERNAL_PORTS
	DB	"Palmira ProgDC in/out"
ELSE
	DB	"Palmira ProgDC"
ENDIF
ELSE
IFDEF	RK60K
	DB	"RK60K"
ELSE
	DB	"Palmira"
ENDIF
ENDIF
	DB	0DH,0AH,0

	lxi	h,DSKVER;##
	call	PUTS
	lxi	h,CONVER;##
	call	PUTS
	lxi	h,LSTVER;##
	call	PUTS
	CALL	SD_I
	XRA	A
	STA	DEF_DSK
	STA	IO_BYTE
	JMP	WBOOT2

WBOOT:	; WARM START OF CP/M BIOS - LOADING SYSTEM
	;JMP	0f86ch
	LXI	SP,C_BASE-100h
	CALL	LOAD_FONT
WBOOT2:
	CALL	SD_I01
	MVI	C,0
	CALL	SELDSK
	CALL	HOME@
WBT:	CALL	SETSCR;##
	CALL	LD_SYS;##

IF 0;DEF	USE_PRG_DC
	XRA	A
	STA	NO_EI
	CALL	Init_IRQ
	EI
ENDIF
	LHLD	C_BASE
	MOV	A,L	; CHECK CP/M DISK PRESENCE
	CPI	0C3H
	JNZ	ASKDOS

	LXI	B,80H
	CALL	SETDMA;##
	MVI	A,0C3H
	STA	SYSPG
	STA	BDOSTRP
	LXI	H,WBOOT_ADR
	SHLD	SYSPG+1
	LXI	H,D_BASE;##
	SHLD	BDOSTRP+1
	LDA	DEF_DSK
	MOV	C,A
	JMP	C_BASE;##

ASKDOS:	CALL	PRNT;##
	DB	10,13,'Ins DOS disk',0
	CALL	CONIN
	JMP	WBT



;	END


