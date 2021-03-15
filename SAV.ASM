;	SAV.ASM - save L80 data area to CPM.BIN

EXTRN	PRNT

INCLUDE BASE.ASM

	lxi	d,fcb
	push	d
	mvi	c,13h
	call	5
	pop	d
	mvi	c,16h
	call	5
	inr	a
	jz	CantCreate

	lxi	d,02ad1h
	mvi	b,(0e200h-C_BASE)/128
SaveLoop:
	push	b
	push	d
		mvi	c,1ah
		call	5
		lxi	d,fcb
		mvi	c,15h
		call	5
	pop	d
	pop	b
	lxi	h,128
	dad	d
	xchg
	ora	a
	jnz	CantSave
	dcr	b
	jnz	SaveLoop
	lxi	d,FCB
	mvi	c,10h
	call	5
	inr	a
	jz	CantClose
	jmp	0


CantClose:
	call	prnt
	db	'Can''t close CPM.BIN',0
	jmp	0

CantSave:
	call	prnt
	db	'Can''t save CPM.BIN',0
	jmp	0

CantCreate:
	call	prnt
	db	'Can''t create CPM.BIN',0
	jmp	0

FCB:	DB	0,'CPM     BIN'
	REPT	(36-12)/2
		DW	0
	ENDM

	END

eate:
	call	prnt
	db	'Can''t create CPM.BI