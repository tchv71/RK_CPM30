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

	LXI	H,C_BASE+7CDH	; SPECIAL SUBROUTINE FOR CCP
	MOV	A,M
	CPI	2		; MODIFICATION
	JZ	C_BASE+76BH
	MVI	M,2
	JMP	C_BASE+6D8H


;------ FIRST TIME INITIALIZATION --------

BOOT:	LXI	SP,100H
	CALL	DskInit;##
	CALL	SETSCR
	CALL	SAV_SYS;##

	CALL	PRNT;##
	DB	27,45H,	'CP/M-80 vers. 2.2'
	DB	0DH,0AH,'Copyright (C) 1980, Digital Research'
	DB	0DH,0AH,'BIOS vers. 3.0      (c) TCHV,1991-92'
	DB	0DH,0AH,0

	;JMP	$

	lxi	h,DSKVER;##
	call	PUTS
	lxi	h,CONVER;##
	call	PUTS
	lxi	h,LSTVER;##
	call	PUTS
	XRA	A
	STA	DEF_DSK
	STA	IO_BYTE

WBOOT:	; WARM START OF CP/M BIOS - LOADING SYSTEM
	LXI	SP,100H
WBT:	CALL	SETSCR;##

	CALL	LD_SYS;##

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


