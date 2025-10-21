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
IFNDEF	VDP9918
	LDA	ViewMode
	;STA	SCR_BUFF
IFNDEF	RK60K
	@out	PALM_CNTRL
ENDIF
ENDIF
	MOV	A,C
IFNDEF	VDP9918
	ANI	7FH
ENDIF
IFDEF	VDP9918
	PUSH	PSW
	LHLD	CURADR
pnc02:
	CALL	T_SetAddrWriteHL
	LDA	CURSYM
	OUT	VDP
	POP	PSW
ENDIF
	LHLD	CHPNT
	CALL	OUTC
	SHLD	CHPNT
IFDEF	VDP9918
pnc01:
	CALL	T_SetAddrReadHL
	IN	VDP
	STA	CURSYM
	CALL	T_SetAddrWriteHL
	MVI	A, 255 ; Cursor
	OUT	VDP
	SHLD	CURADR
ENDIF
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
IF ROBOTRON
	XRA	A
	STA	?ESC
	RET
ENDIF
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
; Delete line contained the cursor
DELLIN:	PUSH	H
	LHLD	STRADR
DL01:
	MOV	D,H
	MOV	E,L
	CALL	NXT_S
IFDEF	VDP9918
	PUSH	H
	PUSH	D

	PUSH	D
	XCHG
	LXI	H,STRBUF
	MVI	B,PHYS_W
	CALL	T_ShAddrReadBytes
	POP	D
	;MVI	B, PHYS_W
	CALL	T_ShAddrWriteBytes
	POP	D
	POP	H
	MOV	A,H
	CPI	high(ENDSCR)
	JNZ	DL01
	MOV	A,L
	CPI	low(ENDSCR)
	JNZ	DL01
	XRA	A
	LXI	B,PHYS_W
	CALL	T_Fill

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
	MVI	B,PHYS_W
	CALL	T_ShAddrReadBytes
	POP	D
	LXI	H,STRBUF
	MVI	B, PHYS_W
	CALL	T_ShAddrWriteBytes
	POP	D
	POP	H
	CPI	high(ENDSCR)
	JNZ	IL01
	MOV	A,L
	CPI	low(ENDSCR)
	JNZ	IL01
	XRA	A
	LXI	B,PHYS_W
	CALL	T_Fill
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
	LHLD	CHPNT
	LDA	CURX
IFNDEF	VDP9918
	JMP	FILL
ELSE
	MOV	C,A
	XRA	A
	MOV	B,A
	XCHG
	JMP	T_Fill
ENDIF

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
	MOV	B,H
	MOV	C,L
	CALL	T_SetAddrWrite
	POP	PSW
	OUT	VDP
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
	LHLD	STRADR
	PUSH	H
	LHLD	BEGSCR
	JMP	DL01
ENDIF
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
	JZ	SCRLL
	STA	CURY
	XCHG
	SHLD	STRADR
	XCHG
	RET
IFDEF	VDP9918
SCRLL:	JMP	SCRUP
ELSE
SCRLL:	LHLD	CHPNT
	JMP	SCROLL
ENDIF
NO_EI:	DB	1

CLS:	CALL	@HOME
IFDEF	VDP9918
	LXI	D,0
	LXI	B, SCR_SIZE
	XRA	A
	JMP	T_Fill
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
	LDA	NO_EI
	ORA	A
	RNZ
	EI
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
	PUSH	H
	lxi	h,Irq_handler
	shld	39h
	mvi	a,0c3h
	sta	38h
IFDEF VDP9918
	RET
ENDIF
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
	POP	H
	;EI
	RET

Irq_Handler:
	EI
	RET
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
	lxi	d,SCR_BUFF+2*PHYS_W-1
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
	MVI	A,80H
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
	LDA	NO_EI
	ORA	A
	RNZ
	EI
	RET
ENDIF

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
IFDEF	VDP9918
CURADR:	DW	VRAM
CURSYM:	DB	0
ENDIF
STRBUF:	DS	PHYS_W


;	end

