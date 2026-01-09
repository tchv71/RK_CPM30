;**************************************************
;*  B1CONIO.ASM - RK CP/M BIOS console I/O module *
;*	(c) TCHV,		1990-92		  *
;**************************************************

; NOTE: This module is designed for use with 8275 display controller
; and 8257 DMA chip

CONVER::
	DB	10,13,'Console I/O V3.1 Healh/Zenith'
IFDEF	CONSOLE80
	DB	' (80 symbols width)'
ENDIF
	DB	' - 31-mar-2025'
	DB	0

ROBOTRON	Equ	0

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
IFDEF	VDP9918
	cpi	0C0h
	JNZ	cvm01
	MVI	A,80h
	JMP	cvm02
cvm01:	CPI	80H
	RNZ
	XRA	A
cvm02:
	CALL	SETSCR2
	JMP	CONIN
ELSE
	sta	ViewMode
	;sta	SCR_BUFF
IFNDEF	RK60K
	@out	PALM_CNTRL
ENDIF
	jmp	CONIN
ENDIF

ViewPtr: dw	ViewTbl
ViewTbl: db	0c0h,90h,0 ; 84h,85h,80h,0 ; ,81h,0 - Not necesarry
ViewMode:db	090h;84H

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
	db	13+80h, 10      ; ^Enter
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
IFNDEF	VDP9918
	LDA	ViewMode
IFNDEF	RK60K
	@out	PALM_CNTRL
ENDIF
	MVI	A,84h
	STA	SCR_BUFF
ENDIF
	MOV	A,C
IFNDEF	VDP9918
	ANI	7FH
ENDIF
IFDEF	VDP9918
	PUSH	PSW
	LDA	CursorShowed
	ORA	A
	JZ	pnc03
	call	ClearCursor
pnc03:
	POP	PSW
ENDIF
	call	GetCurPos
	CALL	OUTC
	SHLD	CHPNT
IFDEF	VDP9918
pnc01:
	LDA	CursorShowed
	ORA	A
	JZ	pnc04
IFDEF FONT8X16
	PUSH	H
	PUSH	B
	LXI	B, T_T80_VRAM_ATTR_ADDRESS
	DAD	B
	CALL	T_SetAddrReadHL
	IN	VDP
	STA	CURATR
	CALL	T_SetAddrWriteHL
	LDA	ScrAttr
	;RLC
	;RLC
	;RLC
	;RLC
	OUT	VDP
	POP	B
	POP	H
ELSE
	CALL	T_SetAddrReadHL
	IN	VDP
	STA	CURSYM
IFDEF	FONT8X16
	IN	VDP
	STA	CURATR
ENDIF
	CALL	T_SetAddrWriteHL
	MVI	A, 255 ; Cursor
	OUT	VDP
IFDEF	FONT8X16
	LDA	ScrAttr
	OUT	VDP
ENDIF
IFDEF	F18A_POS_ATTRS
	PUSH	H
	PUSH	B
	LXI	B, T_T80_VRAM_ATTR_ADDRESS
	DAD	B
	POP	B
	CALL	T_SetAddrWriteHL
	LDA	ScrAttr
	RLC
	RLC
	RLC
	RLC
	OUT	VDP
	POP	H
ENDIF
ENDIF
	SHLD	CURADR
pnc04:
ENDIF
	lhld	CURX
	call	GOTOXY
	POP	PSW
	POP	D
	POP	B
	POP	H
	RET

GetCurPos:
	LHLD	CHPNT
	ret
IFDEF	VDP9918
ClearCursor:
	LHLD	CURADR
IFDEF FONT8X16
	PUSH	B
	LXI	B, T_T80_VRAM_ATTR_ADDRESS
	DAD	B
	CALL	T_SetAddrWriteHL
	LDA	CURATR
	OUT	VDP
	POP	B
ELSE
	CALL	T_SetAddrWriteHL
	LDA	CURSYM
	OUT	VDP
IFNDEF	MSX
	LDA	CURATR
	OUT	VDP
ENDIF
IFDEF F18A_POS_ATTRS
	PUSH	B
	LXI	B, T_T80_VRAM_ATTR_ADDRESS
	DAD	B
	POP	B
	CALL	T_SetAddrWriteHL
	LDA	CURATR
	RLC
	RLC
	RLC
	RLC
	OUT	VDP
ENDIF
ENDIF
	RET
ENDIF

OUTC:	MOV	B,A
	LDA	?ESC
	ORA	A
	JZ	@@@
	DCR	A
	STA	?ESC
	JZ	_ESC2
	DCR	A
	JZ	_ESC1
	lda	?EscColor
	ora	a
	jnz	EscColorAdd
	MOV	A,B
	CPI	'Y'
	RZ
	CPI	'Z'
	JZ	GetCursPos

IF ROBOTRON
	XRA	A
	STA	?ESC
	RET
ENDIF
	cpi	'['
	jz	EscColor
	PUSH	PSW
	XRA	A
	STA	?ESC
	STA	?EscColor
	POP	PSW
	cpi	'a'
	jz	HideCursor
	cpi	'b'
	jz	ShowCursor
	cpi	'A'
	jz	Up
	cpi	'B'
	jz	Down
	cpi	'C'
	jz	LEFT
	cpi	'D'
	jz	Right
	CPI	45H ; 'E'
	JZ	CLS
	SUI	4BH ; 'K'
	JZ	DELEOL
	DCR	A   ; 'L'
	JZ	INSLIN 
	DCR	A   ; 'M'
	RNZ
; Delete line contained the cursor
DELLIN:	PUSH	H
	LHLD	STRADR
DL01:
IFDEF	VDP9918
	MVI	C, PHYS_H -1
ENDIF
DL02:
	MOV	D,H
	MOV	E,L
	CALL	NXT_S
IFDEF	VDP9918
	PUSH	H
	PUSH	D

	PUSH	D
	XCHG
	LXI	H,STRBUF
IFDEF	MSX
	MVI	B,PHYS_W
ELSE
	MVI	B,PHYS_W * 2
ENDIF
	;IN	VDP+1 ; Read status
	CALL	T_ShAddrReadBytes
	POP	D
	CALL	T_ShAddrWriteBytes
IFDEF F18A_POS_ATTRS
	XCHG
	PUSH	B
	LXI	B,T_T80_VRAM_ATTR_ADDRESS
	DAD	B
	POP	D
	XCHG
	CALL	T_ShAddrReadBytes
	CALL	T_ShAddrWriteBytes
ENDIF
	POP	D
	POP	H
	DCR	C
	JNZ	DL02
	;XRA	A
	LXI	B,PHYS_W
	XCHG
IFDEF	MSX
	XRA	A
	CALL	T_Fill
ELSE
	LHLD	ScrAttr
	CALL	T_FillHL
ENDIF
	POP	H
	RET
ELSE
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
ENDIF

HideCursor:
	xra	a
	sta	CursorShowed
	push	h
IFDEF	VDP9918
	call	ClearCursor
ENDIF
	pop	h
	ret

ShowCursor:
	mvi	a,1
	sta	CursorShowed
	ret

GetCursPos:
	PUSH	H
	PUSH	B
	LXI	H, CharBuf
	SHLD	CharBufPtr
	LDA	CURX
	MOV	B,A
	LDA	XSIZE
	SUB	B
	ADI	20h
	MOV	M,A
	INX	H
	LDA	CURY
	MOV	B,A
	LDA	YSIZE
	SUB	B
	ADI	20h
	MOV	M,A
	INX	H
	MVI	M,0
	XRA	A
	STA	?ESC
	POP	B
	POP	H
	RET

CharBuf:
	DS	2
	DB	0
CharBufPtr:
	DW	0

EscColor:
	mvi	a,1
	sta	?EscColor
	mvi	a,6
	sta	?ESC
	push	h
	lxi	h,ColorCode
	shld	ColorCodePtr
	pop	h
	ret

EscColorAdd:
	push	h
	call	EscCA01
	pop	h
	ret

EscCA01:
	mov	a,b
	cpi	'm'
	lhld	ColorCodePtr
	jz	EndEscColor
	mov	m,a
	inx	h
	shld	ColorCodePtr
	ret
EndEscColor:
	xra	a
	mov	m,a
	sta	?EscColor
	sta	?ESC
ParseColor:
	lxi	h,ColorCode+1
	mov	a,m
	ora	a
	jnz	pc02
; 1 - symbol sequence
	dcx	h
	mov	a,m
	cpi	'0'
	jz	ClrReset
	cpi	'1' ; Bold
	cpi	'4' ; Underline
	cpi	'7' ; Reverse
	ret
ClrReset:
	lxi	h,1fh;T_BLACK OR (T_WHITE SHL 4)
	shld	ScrAttr
	ret
pc02:	inx	h
	mov	a,m
	ora	a
	jnz	pc03
	dcx	h
	dcx	h
	mov	a,m
	cpi	'3'
	mvi	d,0
	jz	ClrSetFg
	cpi	'4'
	jz	ClrSetBg
	cpi	'9'
	mvi	d,8
	rnz
ClrSetFg:
	call	GetClrMap
	rnc
	mov	e, m
	lxi	h,ScrAttr
	mov	a,m
	ani	0F0h
	ora	e
	mov	m,a
	ret

pc03:	dcx	h
	dcx	h
	mov	a,m
	cpi	'1'
	rnz
	inx	h
	mov	a,m
	cpi	'0'
	rnz
	mvi	d,8
ClrSetBg:
	call	GetClrMap
	rnc
	mov	a, m
	rlc
	rlc
	rlc
	rlc
	mov	e,a
	lxi	h,ScrAttr
	mov	a,m
	ani	0Fh
	ora	e
	mov	m,a
	ret


GetClrMap:
	inx	h
	mov	a,m
	cpi	'8'
	rnc
	sui	'0'
	add	d
	mov	e,a
	mvi	d,0
	lxi	h,ColorMap
	dad	d
	stc
	ret

; INSERT LINE UNDER CURSOR
INSLIN:	PUSH	H
	LHLD	STRADR
IFDEF	VDP9918
IL01:	MOV	D,H
	MOV	E,L
	CALL	NXT_S
	PUSH	H
	PUSH	D
	PUSH	H
	LXI	H,STRBUF
	MVI	B,PHYS_W * 2
	CALL	T_ShAddrReadBytes
	POP	D
	CALL	T_ShAddrWriteBytes
	POP	D
	POP	H
	CPI	high(ENDSCR)
	JNZ	IL01
	MOV	A,L
	CPI	low(ENDSCR)
	JNZ	IL01
	;XRA	A
	LXI	B,PHYS_W
	LHLD	ScrAttr
	CALL	T_FillHL
	POP	H
	RET
ELSE
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
ENDIF


; DELETE TO END OF LINE
DELEOL:	PUSH	H
	call	GetCurPos
	LDA	CURX
IFNDEF	VDP9918
	JMP	FILL
ELSE
	MOV	C,A
	XRA	A
	MOV	B,A
	XCHG
	LHLD	ScrAttr
	JMP	T_FillHL
ENDIF

@@@:	MOV	A,B
	CPI	20h
	JNC	PutcNoCtrl
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
IF ROBOTRON
	CPI	1
	JZ	@HOME
	CPI	0CH
	JZ	CLS
	CPI	1AH
	JZ	UP
	CPI	15H
	JZ	RIGHT
	CPI	16H
	JZ	DELEOL
ELSE
	CPI	1FH
	JZ	CLS
ENDIF
PutcNoCtrl:
IFDEF	VDP9918
	PUSH	PSW
	CALL	T_SetAddrWriteHL
	POP	PSW
	OUT	VDP
IFNDEF	MSX
	LDA	ScrAttr
	OUT	VDP
ENDIF
IFDEF F18A_POS_ATTRS
	PUSH	H
	PUSH	B
	LXI	B, T_T80_VRAM_ATTR_ADDRESS
	DAD	B
	POP	B
	CALL	T_SetAddrWriteHL
	LDA	ScrAttr
	RLC
	RLC
	RLC
	RLC
	OUT	VDP
	POP	H
ENDIF
ELSE
	MOV	M,A
ENDIF
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

ESC5F:	DB	0

_ESC:
IF ROBOTRON
	MVI	A,2
ELSE
	MVI	A,3
ENDIF
	STA	?ESC
	RET

_ESC1:
IF ROBOTRON
	MOV	A,B
	CPI	5Fh
	JNZ	_ESC11
	MVI	A,1
	STA	ESC5F
	RET
ENDIF
_ESC11:	LDA	YSIZE
	PUSH	PSW
IF ROBOTRON
ELSE
	ADI	20H
ENDIF
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

ColorCode:
	DS	4
ColorCodePtr:
	DS	2
_ESC2:
IF ROBOTRON
	LDA	ESC5F
	ORA	A
	MVI	A,0
	STA	ESC5F
	MOV	A,B
	JNZ	PutcNoCtrl
ENDIF
	LDA	XSIZE
IF ROBOTRON
	SUB	B
	STA	CURX
	MOV	A,B
ELSE
	ADI	20H
	SUB	B
	STA	CURX
	MOV	A,B
	SUI	20H
ENDIF
	MOV	C,A
	MVI	B,0
	DAD	B
	RET

BELL:	PUSH	H
	; 0FE75 on Palmira
	;CALL	0FD24H
	POP	H
	RET

SCRUP:
IFDEF	VDP9918
IFDEF VDP_TEXT_SCROLL
	.z80
	PUSH	BC
	PUSH	HL
	LD	B, T_REG_SCROLL_Y
	LD	HL, ScrollLine
	INC	(HL)
	LD	A, PHYS_H
	CP	(HL)
	JP	NZ, $+5
	LD	(HL), 0
	LD	C, (HL)
	CALL	T_WriteRegValue
	POP	HL
	POP	BC
	
	LD	A, (ScrollLine)
	OR	A
	JP	NZ, $+5
	LD	A, PHYS_H
 IF 1
	DEC	A
	PUSH	BC
	LD	L, A
	LD	H, 0
	ADD	HL, HL
	ADD	HL, HL
	ADD	HL, HL
	ADD	HL, HL
	LD	C, L
	LD	B, H
	ADD	HL, HL
	ADD	HL, HL
	ADD	HL, BC
	POP	BC
	;JP	DL12
 ELSE
	LD	HL, 0
DL01:
	DEC	A
	JP	Z, DL12
	PUSH	AF
	CALL	NXT_S
	POP	AF
	JP	DL01
 ENDIF
DL12:
	PUSH	BC
	PUSH	DE
	LD	BC, PHYS_W
	LD	DE,4Fh
	EX	DE, HL
	CALL	T_FillHL
	EX	DE, HL
	POP	DE
	POP	BC
	RET
	.8080
@HOME:	LHLD	BEGSCR
	SHLD	STRADR
	LDA	XSIZE
	STA	CURX
	LDA	YSIZE
	STA	CURY
	XRA	A
	;JMP	SetTextScroll
	.z80
SetTextScroll:
	PUSH	BC
	LD	(ScrollLine), A
	LD	C, A
	LD	B, T_REG_SCROLL_Y
	CALL	T_WriteRegValue
	POP	BC
	RET
ScrollLine:
	db	0
	.8080
ELSE ; DEF VDP_TEXT_SCROLL
	LHLD	STRADR
	PUSH	H
	LHLD	BEGSCR
	JMP	DL01

@HOME:	PUSH	H
	LHLD	BEGSCR
	SHLD	STRADR
	SHLD	CHPNT
	LDA	XSIZE
	STA	CURX
	LDA	YSIZE
	STA	CURY
	LHLD	CURX
	CALL	GotoXY
	POP	H
	RET
ENDIF ; DEF VDP_TEXT_SCROLL
ELSE
	LHLD	STRADR

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
@HOME:	PUSH	H
	LHLD	BEGSCR
	SHLD	STRADR
	SHLD	CHPNT
	LDA	XSIZE
	STA	CURX
	LDA	YSIZE
	STA	CURY
	LHLD	CURX
	CALL	GotoXY
	POP	H
	RET
ENDIF

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
	RZ
	STA	CURY

	push	h
	LHLD	STRADR
	CALL	Nxt_S
	SHLD	STRADR
	pop	h
	jmp	Nxt_S

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
IFDEF	VDP9918
	JZ	SCRUP
ELSE
	JZ	SCRLL
ENDIF
	STA	CURY
	XCHG
	SHLD	STRADR
	XCHG
	RET
IFNDEF	VDP9918
SCRLL:	call	GetCurPos
	JMP	SCROLL
ELSE
SCRUP2:	CALL	SCRUP
	SHLD	STRADR
	SHLD	CHPNT
	RET
ENDIF
NO_EI:	DB	1

CLS:	CALL	@HOME
IFDEF	VDP9918
	LXI	D,0
	LXI	B, SCR_SIZE
	;XRA	A
IFDEF	MSX
	XRA	A
	CALL	T_Fill
IFDEF F18A_POS_ATTRS
	LXI	D, T_T80_VRAM_ATTR_ADDRESS
	LDA	ScrAttr
	RLC
	RLC
	RLC
	RLC
	CALL	T_FILL
ENDIF
	RET
ELSE
	PUSH	H
	LHLD	ScrAttr
	CALL	T_FillHL
	POP	H
	RET
ENDIF
ELSE
IF 1
	DI
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
	JMP	RET_SET_EI
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
ENDIF


NXT_S:	PUSH	B
	LXI	B,PHYS_W
	DAD	B
	POP	B
	RET

;*********** 8275 chip dependent features ****************

; Set CURSOR to position  HL : (Y,X)
GOTOXY:
IFDEF	VDP9918
	RET
ELSE
	MVI	A,80H	; Cursor move command
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
ENDIF

;EXTRN	Disp_PB

Init_IRQ:
	DI
	.Z80
	im	1
	.8080
	PUSH	H
	lxi	h,Irq_handler
	shld	39h
	mvi	a,0c3h
	sta	38h
IFDEF VDP9918
	POP	H
	JMP	RET_SET_EI
ENDIF
	mvi	a,0a0h
	@out	disp+1
	LXI	d,TimeBuf
	push	d
	mvi	c,2ch
	call	DATE
	pop	d
SetClock:
	ldax	d
	inx	d
	call	ToBcd
	lxi	h,Clock+2
	mov	m,a
	dcx	h
	ldax	d
	inx	d
	call	ToBcd
	mov	m,a
	dcx	h
	ldax	d
	call	ToBcd
	mov	m,a
	push	h
	lxi	d,DateBuf
	mvi	c,2Ah
	call	DATE
	pop	h
	lxi	h, DateStr
	call	DsplDate
	POP	H
	JMP	RET_SET_EI


DsplDate:
	push	d
	push	b

; Mon 22-11-2025 

	lda	WeekDay
	mov	c,a
	call	PrintWeekday
	mvi	m,' '
	inx h
	lda	Date_
	call	PrintDay
	mvi	m,'-'
	inx	h
	lda	Month
	call	PrintDay
	mvi	m,'-'
	inx	h
	lda	Year
	cpi	80
	jc	p2000
	mvi	m,'1'
	inx	h
	mvi	m,'9'
	inx	h
	jmp	date01
p2000:
	mvi	m,'2'
	inx	h
	mvi	m,'0'
	inx	h
date01:
	cpi	10
	jnc	date02
	mvi	m,'0'
	inx	h
date02:
	call	PrintDay
	mvi	m,0
	pop	b
	pop	d
	ret

PrintDate:
	ldax	d
	inx	d
	ora	a
	rz
	mov	m,a
	inx	h
	jmp	PrintDate


PrintWeekday:
	lxi	d,WeekDaysStr
	inr	c
pwd01:	dcr	c
	jz	pwd02
pwd03:	ldax	d
	inx	d
	ora	a
	rz
	cpi	'$'
	jnz	pwd03
	jmp	pwd01

pwd02:	ldax	d
	inx	d
	cpi	'$'
	rz
	mov	m,a
	inx	h
	jmp	pwd02

PrintDay:
	mvi	e,'0'
	cpi	10
	jc	pd01
pd02:
	inr	e
	sui	10
	cpi	10
	jnc	pd02
	mov	m,e
	inx	h
pd01:
	adi	'0'
	mov	m,a
	inx	h
	ret

Irq_Handler:
IFDEF VDP9918
	;call	T_ReadStatus
	PUSH	PSW
	IN	VDP+1
	POP	PSW
	JMP	RET_SET_EI
ENDIF
	PUSH	PSW
	@in	DISP+1
	PUSH	H
	LHLD	TICK_COUNTER
	INX	H
	SHLD	TICK_COUNTER
	MOV	A,H
	ORA	L
	JNZ	irq01
	LHLD	TICK_COUNTER+2
	INX	H
	SHLD	TICK_COUNTER+2
irq01:	CALL	UpdateClock
	POP	H
	POP	PSW
	EI
	RET

ClockSumm:
	DW	0

Clock:	DB	0,0,0

TimeBuf:
Hours:		DB	0
Minutes:	DB	0
Seconds:	DB	0
SecondFraction:	DB	0
SubSeconds:	DB	0

DateBuf:
WeekDay:	DB	0
Month:		DB	0
Date_:		DB	0
Year:		DB	0

DateStr:	ds	17

WeekDaysStr:
	DB	'Sun$Mon$Tue$Wed$Thu$Fr$Sat$',0

ToBcd:
	push	b
	mvi	c,0
tobcd02:
	cpi	10
	jc	tobcd01
	sui	10
	inr	c
	jmp	tobcd02
tobcd01:
	mov	b,a
	mov	a,c
	rlc
	rlc
	rlc
	rlc
	add	b
	pop	b
	ret

UpdateClock:
	lda	ClockSumm+1
	inr	a
	sta	ClockSumm+1
	push	b
	lxi	b,-15727 ; = round(61.4334*256)
	lhld	ClockSumm
	dad	b
	pop	b
	rnc
	shld	ClockSumm
; A second has passed
	LXI	H,Clock
	call	IncPos
	jnz	DispTime
	mvi	m,0
	inx	h
	call	IncPos
	jnz	DispTime
	mvi	m,0
	inx	h
	call	IncPos
	cpi	24h
	jnz	DispTime
	mvi	m,0
DispTime:
	push	d
	push	b
	lxi	d,SCR_BUFF+2*PHYS_W-1-3
	mvi	c,3
	lxi	h,Clock
DispT01:
	mov	b,m
	mov	a,b
	ani	0fh
	adi	'0'
	stax	d
	dcx	d
	mov	a,b
	ani	0f0h
	rrc
	rrc
	rrc
	rrc
	ani	0fh
	adi	'0'
	stax	d
	dcx	d
	dcr	c
	jz	DispT02
	mvi	a,':'
	stax	d
	dcx	d
DispT02:
	inx	h
	jnz	DispT01
	push	h
	xchg
	lxi	d, -16
	dad	d
	lxi	d, DateStr
	call	PrintDate
	pop	h
	pop	b
	pop	d
	ret

IncPos:
	inr	m
	mov	a,m
	ani	0fH
	cpi	10
	mov	a,m
	rnz
	ani	0F0h
	adi	10h
	mov	m,a
	cpi	60h
	ret

; Set a screen mode according to Disp_PB
SETSCR::
IFDEF	VDP9918
IFDEF FONT8X16
	MVI	A,80H
ELSE
	XRA	A
ENDIF
SETSCR2:
	PUSH	PSW
	CALL	T_InitialiseText80
	POP	PSW
SetupCursor:
	CPI	80h
	JZ	sc16
	LXI	B, T_T80_VRAM_PATT_ADDRESS + 255 * 8
	CALL	T_SetAddrWrite
	MVI	A, 255 - 3
	MVI	B, 8
	JMP	sc01
sc16:
	LXI	B, T_T80_VRAM_PATT_ADDRESS + 255 * 16;8
	CALL	T_SetAddrWrite
	MVI	A, 255 - 3
	MVI	B, 16;8
sc01:	OUT	VDP
	DCR	B
	JNZ	sc01
	XRA	A
	@OUT	DISP+1	; Stop displaying
	RET
ELSE
	DI
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
	;DI
	@in	DMA+0Fh
	inr	a
	jz	VT37
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
	ori	80h
	@out	DMA+5
	mvi	a,0a4h
	@out	DMA+8
	JMP	END_DISP
VT37:
	XRA	A
	@out	DMA+0Dh
	rept	2
		mov	a,m
		@out	DMA+4	; Load channel 2
		inx	h
	endm
	rept	2
		mov	a,m
		@out	DMA+5
		inx	h
	endm
	mvi	a,1Ah
	@out	DMA+0Bh
	mvi	a,20h
	@out	DMA+8
	mvi	a,0bh
	@out	DMA+0Fh
END_DISP:
	POP	B
	POP	H
	JMP	RET_SET_EI
ENDIF

; User defined window coordinates
BEGSCR:	DW	VRAM
XSIZE:	DB	SCR_W
YSIZE:	DB	SCR_H
;***************************************

;extern uint8_t BIOS_COLOR __address(0xF759);
;extern uint16_t BIOS_CURSOR __address(0xF75A);
;extern uint8_t BIOS_CURSOR_VISIBLE __address(0xF75E);

IFNDEF VDP9918
CURATR:	DB	04Fh
CURX:	DB	SCR_W	; Current cursor location ( from DOWN-RIGHT corner)
CURY:	DB	SCR_H
CursorShowed:
	db	1
; Internal variables
CHPNT:	DW	VRAM	; Current position in screen buffer
?ESC:	DB	0	; ESC sequence flag
?EscColor:
	DB	0	; ESC color sequence flag
STRADR:	DW	VRAM	; Start of current line
ELSE
CURATR		EQU	0F759h
CURX		EQU	0F75Ah	; Current cursor location ( from DOWN-RIGHT corner)
CURY		EQU	CURX+1
CursorShowed	EQU	0F75Eh
; Internal variables
CHPNT		EQU	0F760h	; Current position in screen buffer
?ESC		EQU	0F762h	; ESC sequence flag
?EscColor	EQU	0F763h	; ESC color sequence flag
STRADR		EQU	0F764h	; Start of current line
ENDIF
IFDEF	VDP9918
CURADR:	DW	VRAM
CURSYM:	DB	0
ENDIF
STRBUF:	DS	PHYS_W*2
ScrAttr:	DW	4fh;T_WHITE OR (T_DK_BLUE SHL 4)
ColorMap:
IFDEF	VDP9918
	DB T_BLACK,T_DK_RED, T_DK_GREEN, T_DK_YELLOW, T_DK_BLUE, T_MAGENTA, T_CYAN, T_GREY
	DB T_GREY,T_LT_RED, T_LT_GREEN, T_LT_YELLOW, T_LT_BLUE, T_MAGENTA, T_CYAN, T_WHITE
ELSE
	DS	16
ENDIF
;	end

