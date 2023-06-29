; 	B0RAMDSK.ASM - RK-86 ram disk operations

;	 7-sep-1993 - separate module
	.8080

PUBLIC	RamD_R,RamD_W

;EXTRN	CPM_RECORD,CPM_TRACK,DMA_ADDR	; From BxDISK module


;------ RAM DISK OPERATIONS -------------
; READ ONE SECTOR FROM RAM DISK
RamD_R:	CALL	CMP_ADR
	JMP	EXT_TO_RAM

; WRITE ONE SECTOR TO RAM DISK
RamD_W:	CALL	CMP_ADR
	JMP	RAM_TO_EXT

RamD_I::
	RET

; Compute address for ramdisk operations
; Out:	HL - DMA address 	(RAM)
;	DE - RAMDISK address 	(ERAM)
;	BC - record size (128)
CMP_ADR:LDA	CPM_TRACK
	MOV	H,A
	MVI	L,0
	DAD	H
	DAD	H	; hl=trk*1024

	LXI	B,128
	LDA	CPM_RECORD
	dcr	a
	jz	@cmp1
@cmp0:	DAD	B
	DCR	A
	JNZ	@cmp0
@cmp1:	xchg
	lhld	DMA_ADDR
	RET


; Copy	from ordinary RAM to extended RAM
;	hl - RAM  addr (to)
;	de - ERAM addr (from)
;	bc - length
RAM_TO_EXT::
	shld	@@tmp
	lxi	h,0
	dad	sp
	shld	STK_SAVE

	lhld	@@tmp
	dad	b
	xchg
	dad	b	; Copying from top to bottom

	call	SHR_BC	; BC/=2

	sphl		; Set SP to source
	xchg		; HL to destination

	MVI	A,0FFH
	OUT	0FFH
WR_LP:	DCX	H
	MOV	D,M
	DCX	H
	MOV	E,M
	PUSH	D
	DCX	B
	MOV	A,B
	ORA	C
	JNZ	WR_LP
	JMP	RW_CMN

; Copy	from extended RAM to ordinary RAM
;	hl - RAM addr  (to)
;	de - ERAM addr (from)
;	bc - length
EXT_TO_RAM::
	shld	@@tmp
	lxi	h,0
	dad	sp
	shld	STK_SAVE

	lhld	@@tmp

	call	SHR_BC	; BC/=2

	xchg
	sphl		; Set SP to destination,
	xchg		; HL to source
	MVI	A,0FFH
	OUT	0FFH

RD_LP:	POP	D
	MOV	M,E
	INX	H
	MOV	M,D
	INX	H
	DCX	B
	MOV	A,B
	ORA	C
	JNZ	RD_LP
RW_CMN:	XRA	A
	OUT	0FFH
	LHLD	STK_SAVE
	SPHL
	XRA	A
	RET


SHR_BC:
	ora	a	; Clear CY
	mov	a,b
	rar
	mov	b,a
	mov	a,c
	rar
	mov	c,a
	ret

@@tmp:	ds	2
STK_SAVE:	ds	2
RAMDSK_END::
	END
