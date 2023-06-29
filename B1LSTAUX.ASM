;	B0LSTAUX.ASM - LST AND AUX FUNCTIONS
LSTVER::	DB	10,13,'LST/AUX DRIVER V3.02     31-May-1993',0

;INCLUDE RK86.MAC

;--------- AUX DRIVER       (C) TCHV ------------

PUNCH::		RET

READER::	MVI	A,1AH
		RET

;--------- LST DRIVER       (C) TCHV ---------------
LSTOUT::	JMP	LPUTC
LST_ST::	MVI	A,0FFH
		RET

MC6312	EQU	1

if 	MC6312	; MC6312 printer with centronix interface
TextTransl	equ	0
TabReplace	equ	0
NoPrint		equ	0
CENTRONIX	equ	1
else
TextTransl	equ	1
TabReplace	equ	1
NoPrint		equ	0
endif

IF 	NoPrint
LPUTC:		RET
ELSE
TabSize 	equ	8


IF 	TabReplace
ExpandTab:
	push	b
	lda	TabLeft
	mvi	c,20h
@exp_tab_loop:
	call	Raw_LPUTC
	dcr	a
	jnz	@exp_Tab_Loop
	mvi	a,TabSize
	sta	TabLeft
	pop	b
	pop	psw
	ret
ENDIF

LPUTC:
	push	psw
IF	TabReplace
	mov	a,c
	cpi	9
	jz	ExpandTab
	cpi	0Ah
	jz	@01
	lda	TabLeft
	dcr	a
	sta	TabLeft
	jnz	@00
@01:	mvi	a,TabSize
	sta	TabLeft
@00:
ENDIF
IF	TextTransl
	mov	a,c
	cpi	60h
	jc	@3

	cpi	80h
	jnc	@1
	adi	0c0h-60h
	jmp	@3

@1:	cpi	80h+40h
	jc	@3

	cpi	80h+60h
	jnc	@2
	adi	20h
	jmp	@3

@2:	sui	80h
@3:	mov	c,a
ENDIF
	pop	psw
Raw_LPUTC:

PPI2_B	EQU	PPI2+1
PPI2_C	EQU	PPI2+2
PPI2_CR	EQU	PPI2+3

	push	psw
	lda	PPI_Init_flag
	ora	a
	jnz	@skip
	mvi	a,91H
	@out	PPI2_CR
	sta	PPI_Init_flag
@skip:	MVI	A,@set
	@out	PPI2_CR
@L_wait:
	@in	PPI2_C	; Wait for busy signal
ifdef	CENTRONIX
	ani	00000001b
@set	equ	0fh
@clr	equ	0eh
else
@set	equ	0eh
@clr	equ	0fh
	ani	00000011b
endif

	jnz	@L_wait
	mov	a,c
	@out	PPI2_B
	mvi	a,@clr
	@out	PPI2_CR
	MVI	A,3FH
@L_delay:
	DCR	A
	JNZ	@L_Delay
	MVI	A,@SET
	@OUT	PPI2_CR
	pop	psw
	RET

PPI_Init_Flag:	db	0
IF	TabReplace
TabLeft:	db	TabSize
ENDIF
ENDIF	; NoPrint
;	END

