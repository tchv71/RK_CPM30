;**************************************************
;*  B1CONIO.ASM - RK CP/M BIOS console I/O module *
;*	(c) TCHV,		1990-92		  *
;**************************************************

; NOTE: This module is designed for use with 8275 display controller
; and 8257 DMA chip

CONVER::
	DB	10,13,'Console I/O        V3.0 Healh/Zenith',0

; This module defines following procedures :
PUBLIC		CON_ST,CONIN,CONOUT
PUBLIC		PRNT,PUTS

;INCLUDE RK86.MAC
;INCLUDE 82XX.MAC
;INCLUDE SCREEN.MAC

;------------------ Console Input ------------------------

CON_ST:
IFNDEF OWN_GETC
	JMP	0F812H
ELSE
	JMP	GETST
ENDIF

CONIN::
IFDEF OWN_GETC
	CALL	GETCHR
ELSE
	CALL 0F803H
ENDIF
	ora	a
	jz	ChangeViewMode
	cpi	20h
	jc	CorrCntrl
	cpi	7fh
	jz	CorrCntrl
	ret

ChangeViewMode:
	push	h
	lhld	ViewPtr
	inx	h
	mov	a,m
	ora	a
	jnz	$+6
	lxi	h,ViewTbl
	mov	a,m
	shld	ViewPtr
	pop	h
	sta	ViewMode
	;sta	SCR_BUFF
IFNDEF	RK60K
	@out	PALM_CNTRL
ENDIF
	jmp	CONIN

ViewPtr: dw	ViewTbl
ViewTbl: db	0c0h,80h,0 ; 84h,85h,80h,0 ; ,81h,0 - Not necesarry
ViewMode:db	0C0h;84H

; Perform key translation Acc->Acc
CorrCntrl:
	push	h
	push	b
	mov	b,a
	@in	PPI+2
	MOV	C,A
	mvi	a,?SHIFT
	ana	c
	jz	@exit
	mov	a,c
	ani	?CTRL
	jnz	@001
	mvi	a,80h
	ora	b
	mov	b,a
@001:
	lxi	h,CorrTbl
@loop:	mov	a,m
	inx	h
        inx	h
	inr	a
	jz	@exit
	dcr	a
	cmp	b
	jnz	@loop
	dcx	h
	mov	b,m
@exit:	mov	a,b
	ani	7fh
	pop	b
	pop	h
	ret

; Key translation table
CorrTbl:
;****  Arrow keys ****
	db	19h,	'E'-40h	; Up
	db	1Ah,	'X'-40h ; Down
	db	8,	'H'-40h	; Left
	db	18h,	'D'-40h	; Right
;*** Cntrl+Arrow keys ***
	db	19h+80h,'R'-40h	; ^Up
	db	1Ah+80h,'C'-40h ; ^Down
	db	8+80h,	'A'-40h	; ^Left
	db	18h+80h,'F'-40h	; ^Right
;*** Other keys ***
	db	7fh,	8

	db	0ffh

;------------------- Console output -----------------------------

PRNT::	POP	H
	CALL	PUTS
	pchl

PUTS:
PRNT1:	MOV	A,M
	INX	H
	MOV	C,A
	ORA	A
	RZ
	CALL	CONOUT
	JMP	PRNT1


CONOUT:	PUSH	H
	PUSH	B
	PUSH	D
	PUSH	PSW
	LDA	ViewMode
	;STA	SCR_BUFF
IFNDEF	RK60K
	@out	PALM_CNTRL
ENDIF
	MOV	A,C
	ANI	7FH
	LHLD	CHPNT
	CALL	OUTC
	SHLD	CHPNT

	lhld	CURX
	call	GOTOXY
	POP	PSW
	POP	D
	POP	B
	POP	H
	RET

OUTC:	MOV	B,A
	LDA	?ESC
	ORA	A
	JZ	@@@
	DCR	A
	STA	?ESC
	JZ	_ESC2
	DCR	A
	JZ	_ESC1
	MOV	A,B
	CPI	'Y'
	RZ
	PUSH	PSW
	XRA	A
	STA	?ESC
	POP	PSW
	cpi	'A'
	jz	Up
	cpi	'B'
	jz	Down
	cpi	'C'
	jz	LEFT
	cpi	'D'
	jz	Right
	CPI	45H
	JZ	CLS
	SUI	4BH
	JZ	DELEOL
	DCR	A
	JZ	INSLIN
	DCR	A
	RNZ
; Delete line contains the cursor
DELLIN:	PUSH	H
	LHLD	STRADR
	MOV	D,H
	MOV	E,L
	CALL	NXT_S
DL0:	MOV	A,M
	STAX	D
	INX	H
	INX	D
	MOV	A,D
	CPI	high(ENDSCR)
	JNZ	DL0
	MOV	A,E
	CPI	low(ENDSCR)
	JNZ	DL0
	POP	H
	RET

; INSERT LINE UNDER CURSOR
INSLIN:	PUSH	H
	LHLD	STRADR
	LXI	D,ENDSCR
	LXI	B,ENDSCR-PHYS_W
CPY:	DCX	B
	DCX	D
	LDAX	B
	STAX	D
	MOV	A,B
	CMP	H
	JNZ	CPY
	MOV	A,C
	CMP	L
	JNZ	CPY

	MVI	A,SCR_W
FILL:	MVI	M,0
	INX	H
	DCR	A
	JNZ	FILL
	POP	H
        RET


; DELETE TO END OF LINE
DELEOL:	PUSH	H
	LHLD	CHPNT
	LDA	CURX
	JMP	FILL


@@@:	MOV	A,B
	CPI	@ESC
	JZ	_ESC
	CPI	0DH
	JZ	@CR
	CPI	0AH
	JZ	@LF
	CPI	8
	JZ	LEFT
	CPI	7
	JZ	BELL
	CPI	1FH
	JZ	CLS
	MOV	M,A
	INX	H
	LDA	CURX
	DCR	A
	STA	CURX
	RNZ
	LDA	XSIZE
	STA	CURX
	LHLD	STRADR
	CALL	NXT_S
	LDA	CURY
	DCR	A
	JZ	SCRUP
	STA	CURY
	SHLD	STRADR
	RET

_ESC:	MVI	A,3
	STA	?ESC
	RET

_ESC1:	LDA	YSIZE
	PUSH	PSW
	ADI	20H
	SUB	B
	STA	CURY
	MOV	B,A
	POP	PSW
	SUB	B
	LHLD	BEGSCR
	INR	A
_@ESC:	SHLD	STRADR
	DCR	A
	RZ
	CALL	NXT_S
	JMP	_@ESC

_ESC2:	LDA	XSIZE
	ADI	20H
	SUB	B
	STA	CURX
	MOV	A,B
	SUI	20H
	MOV	C,A
	MVI	B,0
	DAD	B
	RET

BELL:	PUSH	H
	; 0FE75 on Palmira
	;CALL	0FD24H
	POP	H
	RET

SCRUP:	LHLD	STRADR

SCROLL:	PUSH	H
	LHLD	BEGSCR
	MOV	D,H
	MOV	E,L
        CALL	NXT_S
	LDA	YSIZE
	DCR	A
	MOV	C,A
SCRU0:	LDA	XSIZE
	MOV	B,A
SCRU1:	MOV	A,M
	STAX	D
	INX	H
	INX	D
	DCR	B
	JNZ	SCRU1
	CALL	NEXTST
	XCHG
	CALL	NEXTST
	XCHG
	DCR	C
	JNZ	SCRU0
	LHLD	STRADR
	LDA	XSIZE
SCRU2:	MVI	M,0
	INX	H
	DCR	A
 	JNZ	SCRU2
	POP	H
	RET

NEXTST:	LDA	XSIZE
	CMA
	INR	A
	ADI	PHYS_W
	ADD	L
	MOV	L,A
	RNC
	INR	H
	RET

PrevST:	push	b
		lxi	b,-Phys_W
		dad	b
	pop	b
	RET


LEFT:	LDA	CURX
	INR	A
	MOV	B,A
	LDA	XSIZE
	CMP	B
	RC
	MOV	A,B
	STA	CURX
	DCX	H
	RET


RIGHT:	LDA	CURX
	DCR	A
	RZ
	STA	CURX
	INX	H
	RET


UP:	LDA	CURY
	INR	A
	MOV	B,A
	LDA	YSIZE
	CMP	B
	rc	; JC	LFT0
	MOV	A,B
	STA	CURY
	call	PrevSt
	push	h
        LHLD	STRADR
	call	PrevSt
	shld	STRADR
	pop	h
	RET



DOWN:	LDA	CURY
	DCR	A
	JZ	DWN0
	STA	CURY

	push	h
	LHLD	STRADR
	CALL	Nxt_S
	SHLD	STRADR
	pop	h
	jmp	Nxt_S

DWN0:	RET


@CR:	LDA	XSIZE
	STA	CURX
	LHLD	STRADR
	RET

@LF:	XCHG
	LHLD	STRADR
	CALL	NXT_S
	XCHG
	CALL	NXT_S
	LDA	CURY
	DCR	A
	JZ	SCRLL
	STA	CURY
	XCHG
	SHLD	STRADR
	XCHG
	RET

SCRLL:	LHLD	CHPNT
	JMP	SCROLL

CLS:	CALL	@HOME
IF 1
	PUSH	H
	PUSH	D
	LXI	B,SCR_SIZE/4
	LXI	H,0
	MOV	D,H
	MOV	E,H
	DAD	SP
	LXI	SP,SCR_BUFF+SCR_SIZE
CLS0:
	PUSH	D
	PUSH	D
	DCX	B
	MOV	A,B
	ORA	C
	JNZ	CLS0
	SPHL
	POP	D
	POP	H
	RET
ELSE
	LDA	YSIZE
	MOV	B,A
	PUSH	H
CLS0:	LDA	XSIZE
	MOV	C,A
	PUSH	H
CLS1:	MVI	M,0
	INX	H
	DCR	C
	JNZ	CLS1
	POP	H
	CALL	NXT_S
	DCR	B
	JNZ	CLS0
	POP	H
	RET
ENDIF

@HOME:	LHLD	BEGSCR
	SHLD	STRADR
	LDA	XSIZE
	STA	CURX
	LDA	YSIZE
	STA	CURY
	RET


NXT_S:	PUSH	B
	LXI	B,PHYS_W
	DAD	B
	POP	B
	RET

;*********** 8275 chip dependent features ****************

; Set CURSOR to position  HL : (Y,X)
GOTOXY:	MVI	A,80H	; Cursor move command
	@OUT	DISP+1

	MOV	B,L
	LDA	XSIZE
	SUB	B
	ADI	HorizShift
	@out	DISP

	MOV	B,H
	LDA	YSIZE
	SUB	B
	ADI	FirstStr
	@OUT	DISP
	RET

;EXTRN	Disp_PB

; Set a screen mode according to Disp_PB
SETSCR::
	PUSH	H
	PUSH	B

; *** Load 8275 controller ****

	XRA	A
	@OUT	DISP+1	; Stop displaying

	MVI	C,4
	lxi	h,Disp_PB	; Display parameter block
	rept	4
		mov	a,m
		inx	h
		@out	DISP
	endm

	mvi	a,27H
	@out	DISP+1
	@in	DISP+1	; Clear RVV flag
@wait_RVV:
	@in	DISP+1	; Wait RVV signal
	ANI	DISP_INTR_Flag
	JZ	@wait_RVV

;*** Load 8257 controller ***

	mvi	a,80h
	@out	DMA+8	; Control register

	rept	2
		mov	a,m
		@out	DMA+4	; Load channel 3
		inx	h
	endm

	mov	a,m
	@out	DMA+5
	inx	h
	mov	a,m
	ori	40h
	@out	DMA+5
	mvi	a,0a4h
	@out	DMA+8
	POP	B
	POP	H
	RET

; User defined window coordinates
BEGSCR:	DW	VRAM
XSIZE:	DB	SCR_W
YSIZE:	DB	SCR_H
;***************************************

; Internal variables
CHPNT:	DW	VRAM	; Current position in screen buffer
?ESC:	DB	0	; ESC sequence flag

CURX:	DB	SCR_W	; Current cursor location ( from DOWN-RIGHT corner)
CURY:	DB	SCR_H
STRADR:	DW	VRAM	; Start of current line
;	end

