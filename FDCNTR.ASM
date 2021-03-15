; ----  CONTROLLER DEPENDENT SUBROUTINES  -------
;    Version 1.2 for R86-rk  (c) TCHV 1991-93

;	27-Jan-1992  - Transparent error recovery
;	16-Feb-1992  - Debug error recovery
;	26-jun-1993  - Add ABRT_CMD etc..
;	05-jul-1993  - Debug error recovery
;       07-jul-1993

MaxTrying	equ	5; Maximum repeats of a command
Sector_Operation	equ	1
Debug		equ	1

; This module contains following procedures :
PUBLIC	HOME,POSIT,FD_WR_INIT,FD_RD_INIT,STPMTR,WT_END_CMD
PUBLIC	OPER,ChgDrive,ABRT_CMD,START_NOT_SECTOR_OPERATION

EXTRN	BAD	; user hook if a bad sector detected
;-------------------------------------------------

	.8080
FDC_COM_STAT	EQU	0F700H
FDC_TRK		EQU	FDC_COM_STAT+1
FDC_SECT	EQU	FDC_COM_STAT+2
FDC_DATA	EQU	FDC_COM_STAT+3
FDC_CNTRL	EQU	FDC_COM_STAT+4
DMA		EQU	0F7E0H

; CHANGE CURRENT DRIVE Acc - Drive number (1-A,2-B)
; Returns Cy=0 - Ok, Cy=1 - Drive not ready
ChgDrive:
	push	psw
busy:	lda	FDC_Com_Stat
	ani	1
	jnz	busy
	pop	psw
	sta	drive	; to be extended
	call	Home	; Track is not remembered
	call	Wt_end_cmd
	call	Home
	mvi	a,0ffh
	sta	?40TRK
	ora	a
	ret

; SET THE HEAD TO TRACK 00
HOME:	MVI	A,8	; HOME & START MOTOR
	JMP	Start_Not_Sector_Operation

; STOP MOTOR & UNSELECT DRIVE
STPMTR:	ret
;	CALL	WT_END_CMD
;	XRA	A
;	STA	CNTRL
;	MVI	A,40H
;	CALL	STR_CMD
;	JMP	WT_END_CMD

; ABORT CURRENT DISK COMMAND
ABRT_CMD:MVI	A,0D0H
	STA	FDC_COM_STAT
	XRA	A
	STA	WAIT_RQ
	RET

; Start motor if it's not activated
Start_Motor:
	lda	FDC_COM_STAT
	ani	20h
	rnz
	lda	FDC_Trk
	sta	FDC_Data
	mvi	a,18h	; Start motor, Seek no check
	call	Start_Not_Sector_Operation
	jmp	WT_END_CMD

; SET HEAD TO DESIRED TRACK (ACC)
POSIT:	PUSH	PSW
	CALL	WT_END_CMD
	POP	PSW		; SET TRACK NO INTO
	STA	FDC_Data	; DATA REGISTER
	push	b
	mov	b,a
	lda	FDC_Trk
	cmp	b
	pop	b
	rz
	LDA	?40TRK
	ORA	A
	JZ	POSIT80
	MVI	A,14H	; Seek and Check command
	CALL	Start_Not_Sector_Operation
	CALL	Wait_no_check
	RZ
	LDA	?40TRK
	CMA
	STA	?40TRK
	LDA	FDC_Data
	PUSH	PSW
	CALL	HOME
	POP	PSW
	JMP	POSIT

POSIT80:PUSH	B
	LDA	FDC_Data
	PUSH	PSW
	ADD	A
	STA	FDC_Data
	LDA	FDC_Trk
	ADD	A
	STA	FDC_Trk
	MVI	A,18H	; Seek no check
	CALL	Start_Not_Sector_Operation
	call	WT_END_CMD
	POP	PSW
	STA	FDC_Trk
	STA	FDC_Data
	MVI	A,14H	; Seek and check
	POP	B
	JMP	Start_Not_Sector_Operation

;----------------------------------------------------
; WAIT FOR END OF PREVIOUS DISK COMMAND
;  Note: This subrotine exits only if no errors detected
WT_END_CMD:
	lda	Last_Operation_Kind
	ora	a	; ? Not_Sector_Operation
	jz	Simple_Wait
	CALL	Wait_no_check	; Wait for end of previous sector command
	jnz	Error_Detected
		mvi	a,MaxTrying	; Last attempt was succsessful,
		sta	TryCounter	; re-set trying counter
		RET

Error_Detected:	; Try again
	lda	TryCounter
	dcr	a
	jz	BAD@	; All attempts are unsuccessfull
	sta	TryCounter
	call	Repeat_Command	; Try one more time
	jmp	WT_END_CMD

;--------------------------------------------------------
Simple_Wait:
	call	Wait_no_check
	rz
Bad@:	mvi	a,MaxTrying
	sta	TryCounter
	jmp	Bad

Wait_no_check:
	LDA	WAIT_RQ	; IS WAITING NECESARRY ?
	ORA	A
	RZ
WT_EC:	LDA	FDC_Cntrl; WAIT FOR INRQ
	ANI	40H	;  SIGNAL
	JZ	WT_EC
	XRA	A
	STA	WAIT_RQ
	LDA	FDC_Com_Stat	; READ STATUS & CLEAR INRQ SIGNAL
	ANI	18H 		; CHECK ERROR BITS
	RET


	dseg
WAIT_RQ:db	0
?40TRK:	DB	0FFH
	cseg

; Repeat last controller command
Repeat_Command:
	push	h
	push	d
	push	b

ifdef	Debug
	PUSH	B
	mvi	c,7
	call	0f809h
	POP	B
endif
if 0
	lda	TryCounter
	cpi	3
	jnc	Simple_Repeat
endif
	lda	TryCounter
	push	psw
		xra	a
		sta	Last_Operation_Kind
		lda	FDC_Trk
		push	psw
			call	HOME
		pop	psw
		call	POSIT
	pop	psw
	sta	TryCounter
Simple_Repeat:
	lhld	LastSize
	mov	b,h
	mov	c,l
	lhld	LastAddr
	xchg
	lhld	Last_SideSect
	lda	LastCommand
	call	RW_COMM
	pop	b
	pop	d
	pop	h
	ret

; INITIALISE SECTOR WRITING
;  In: H - side (0/0ffh) ; L - sector (0..)
FD_WR_INIT:
	LXI	B,4200H
	MVI	A,0A0H
	jmp	FD_RW_COMMON

; INITIALISE SECTOR READING
FD_RD_INIT:
	LXI	B,8200H
	MVI	A,80H
FD_RW_COMMON:
; PROGRAM DMA & DISK CONTROLLERS
OPER:
	push	psw
	call	WT_END_CMD
	push	h
	call	Start_Motor
	pop	h
	pop	psw
RW_COMM:
	sta	LastCommand
	shld	Last_SideSect
	mov	a,l
	sta	FDC_Sect
	MVI	A,0A4H
	STA	DMA+8
	push	h
	LXI	H,DMA+2
	MOV	M,E
	MOV	M,D
	INX	H
	MOV	M,C
	MOV	M,B
	MVI	L,0E8H
	MVI	M,0B6H
	pop	h
	lda	LastCommand
	call	START_CMD
			; * Save information to
			; repeat command if necesarry
	shld	Last_SideSect
	xchg
	shld	LastAddr
	xchg
	mov	h,b
	mov	l,c
	shld	LastSize
			; *
	mvi	a,Sector_operation
	sta	Last_Operation_Kind
	MVI	A,0FFH
	STA	WAIT_RQ	; WAITING IS NECESARRY
	RET

; Start not sector operation
Start_Not_Sector_Operation:
	push	psw
	call	WT_END_CMD
	pop	psw
	push	h
	mvi	h,0
	call	START_CMD
	pop	h
	xra	a
	sta	Last_Operation_Kind
	mvi	a,0ffh
	sta	WAIT_RQ
	ret

START_CMD:
	PUSH	PSW
	mov	a,h	; 0 OR 0FFH
	ANI	10H
	ORI	20H	; HLD IMITATION & DRIVE 1 SELECT
	push	b
	mov	b,a
	lda	drive
	ora	b
	pop	b
	STA	FDC_Cntrl
	POP	PSW
	STA	FDC_COM_STAT
	ret


	dseg
DRIVE:	DB	1
Last_Operation_Kind:	db	0
Last_SideSect:	ds	2
LastCommand:	ds	1
LastAddr:	ds	2
LastSize:	ds	2
TryCounter:	db	MaxTrying
	END
