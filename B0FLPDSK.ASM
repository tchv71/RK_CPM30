;****************************************************************
;*     B0FLPDSK.ASM - floppy disk operations			*
;*								*
;*  (c) TCHV,1993						*
;****************************************************************

INCLUDE B0DISK.MAC

PUBLIC FLPD_R,FLPD_W,FLSH_WB,FLP_TBL

EXTRN	SECB1,SECB2 ; Externally allocated sector buffers

EXTRN	CHECK_D
EXTRN	OLDF40,OLDDSK

EXTRN	CPM_RECORD,CPM_TRACK,DMA_ADDR
EXTRN	SET_PARAMS

;**********  From FDCNTR module ************************************
EXTRN	HOME,POSIT,FD_WR_INIT,FD_RD_INIT,WT_END_CMD,ABRT_CMD
EXTRN	START_NOT_SECTOR_OPERATION,Side,SECT
EXTRN	OPER,ChgDrive
;*******************************************************************

;Debug	equ	1

MARK	MACRO	SYM
ifdef Debug
	PUSH	B
	MVI	C,SYM
	CALL	CONOUT##
	POP	B
endif
	ENDM

MARK_POS	MACRO	str
ifdef	Debug
	push	b
	call	PRNT
	db	10,13,str,' T:',0
	lda	Cpm_TRACK
	pop	b
	call	mr_pos
endif
	ENDM

ifdef Debug
MR_POS:
	push	b
	call	HEXOUT##
	call	PRNT
	db	' S:',0
	lda	cpm_RECORD
	CALL	HEXOUT##
	call	prnt
	db	' Drive:',0
	lda	CPM_DISK
	adi	'A'
	mov	c,a
	call	CONOUT##
	call	prnt
	db	' C:',0
	pop	b
	mov	a,c
	CALL	HEXOUT##
	CALL	0F81BH
	INR	A
	RZ
@01:	CALL	conin##
	CPI	'S'
	JZ	@01
	RET
endif

; ***** Floppy disk module initialisation *****
FlpD_I::
	XRA	A	; NOTHING
	STA	LAST_OPER
	STA	SECTALL
	STA	OLDDSK
	STA	OLDF40
	LXI	H,SECB1
	SHLD	CUR_BF
	LXI	H,SECB2
	SHLD	NXT_BF
	ret
       


;**********  Read one record flom currently selected floppy disk *********
FlpD_R::
	XRA	A
	STA	IO_RESULT
        CALL	CHECK_D
	CALL	SET_PARAMS
	LDA	LAST_OPER
	CPI	READING
	JZ	@Cont_Reading	; Continue last reading operation
	CPI	WRITING
	CZ	FLSH_WB		; Flush write buffer before reading

START_READING:
;	MVI	C,'S'
;	call	puts

	CALL	WT_END_CMD	; This is the first reading operation
	MVI	A,READING
	STA	LAST_OPER
	CALL	RD_CUR_S

@TRANSF_RECORD:
	call	STRT_NXT
	jmp	TRANS_REC


@Cont_Reading:
	CALL	?IS_CUR		; if (record in current sector)
	JZ	TRANS_REC	; 	Copy it from buffer
	CALL	?IS_NEXT	; else
	JZ	TRANS_NEXT	;	Transfer record from next sector

	CALL	ABRT_CMD	;
	JMP	START_READING

TRANS_NEXT:
;	mvi	c,'N'
;	call	putc
	CALL	WT_END_CMD	;
;	jnz	START_READING	; if error -> try again
	CALL	EXC_BUFS	;	Make next sector current
	JMP	@TRANSF_RECORD	;	And copy record from it


; READ PHYSICAL SECTOR WITH CURRENT RECORD
RD_CUR_S:
	LXI	H,CUR_STN
	CALL	CMP_STN
	CALL	SET_STN
	LHLD	CUR_BF
	XCHG
RDSECT:	push	d
	push	h
		lhld	SECT
		call	FD_RD_INIT
	pop	h
	pop	d
	call	WT_END_CMD; Wait_No_Check
;        jnz	RDSECT
	ret


WRSECT:	push	h
	lhld	SECT
	CALL	FD_WR_INIT
	pop	h
	JMP	WT_END_CMD

; COMPUTE CURRENT SIDE, SECTOR & TRACK
; IN :	HL - POINTER TO RECORD
CMP_STN:PUSH	H
	MVI	M,0 ; SIDE
	lda	RecsPerSect	; to be 2^N
	dcr	a
	cma
	mov	b,a
	LDA	MaxSect
	mov	c,a
	push	d
	lda	SectShift
	mov	e,a

	LDA	CPM_RECORD
	DCR	A
	ana	b

	RRC
	dcr	e
	jnz	$-2
	pop	d
	CMP	C
	JC	CP_S0
	MVI	M,0FFH
	SUB	C

CP_S0:	INX	H
	INR	A
	MOV	M,A
	INX	H
	LDA	CPM_TRACK
	MOV	M,A
	POP	H
	RET


; SET HEAD & SECTOR REGISTER TO POSITION (HL)
SET_STN:MOV	A,M
	STA	SIDE
	INX	H
	MOV	A,M
	STA	SECT
	INX	H
	MOV	A,M
	CALL	POSIT
	CALL	WT_END_CMD
	RET


; START READING OF NEXT PHYS. SECTOR
STRT_NXT:
	lda	MaxSect
	inr	a
	mov	c,a

	LXI	H,NXT_STN
	LDA	SECT
	INR	A
	STA	SECT
	cmp	c
	JC	ST_N
	MVI	A,1
	STA	SECT
	LDA	SIDE
	CMA
	STA	SIDE
	ORA	A
	JNZ	ST_N
;	MVI	C,'+'
;	CALL	PUTC
	MVI	A,58H
	CALL	START_NOT_SECTOR_OPERATION
	CALL	WT_END_CMD
ST_N:	LDA	SIDE
	MOV	M,A
	INX	H
	LDA	SECT
	MOV	M,A
	INX	H
	LDA	0F701h
if1
.printx " LDA	0F701h - RK dependent !!!"
endif
	MOV	M,A
	LHLD	NXT_BF
	XCHG
	push	h
	lhld	SECT
	call	FD_RD_INIT
	pop	h
	ret

; CHECKS IF CURRENT RECORD PLASES
;  INTO CURRENT PHYS. SECTOR
;  Z=1 - IT DOES
?IS_CUR:LXI	D,CUR_STN
	JMP	?IS_
; CHECKS FOR NEXT SECTOR
?IS_NEXT:
	LXI	D,NXT_STN
?IS_:	PUSH	D
	LXI	H,NEW_STN
	CALL	CMP_STN
	POP	D
CMP_S:	MVI	C,3
CMP_S0:	LDAX	D
	CMP	M
	INX	H
	INX	D
	RNZ
	DCR	C
	JNZ	CMP_S0
	RET


; EXCHANGE BUFFERS
EXC_BUFS:
	LXI	H,CUR_BF
	LXI	D,NXT_BF
	MVI	C,5
EX_B0:	MOV	B,M
	LDAX	D
	MOV	M,A
	MOV	A,B
	STAX	D
	INX	H
	INX	D
	DCR	C
	JNZ	EX_B0
	RET

; TRANSFER CURRENT RECORD FROM
; CURRENT PHYSICAL SECTOR BUFFER
; TO DMA ADRESS
TRANS_REC:
	LHLD	CUR_BF
	CALL	CALC_OFFSET
	XCHG
	MVI	C,128
	LHLD	DMA_ADDR
	XCHG
	JMP	CPYREC



; CALCULATE OFFSET IN SECTOR BUFFER FOR CPM_RECORD
;	In  :   HL - Start of sector buffer
; 	Out :	HL - Points to CPM_RECORD place in this buffer
CALC_OFFSET:
	lda	RecsPerSect
	dcr	a
	mov	b,a

	lDA	CPM_RECORD
	DCR	A
	ana	b
	LXI	D,128
	MOV	C,A
	MVI	A,1
	INR	C
CLC_OFF:DCR	C	; CALCULATE OFFSET
	RZ		; IN SECTOR BUFFER
	RLC
	DAD	D
	JMP	CLC_OFF

;**********  Write current record to currentlu selected floppy disk ********
FLPD_W: MARK_POS	'Writing'
	XRA	A
	STA	IO_RESULT
	CALL	CHECK_D
	CALL	SET_PARAMS
	LDA	LAST_OPER	; WAS LAST OPER WRITING?
	CPI	WRITING
	JZ	WRS_0
	MARK	'+'
	CALL	WT_END_CMD
	CALL	Make_Buff_Empty	; Set Sector buffer address
				; and clear allocation counter
WRS_0:	CALL	?IS_NEXT
	JZ	TR_TO_C
	MARK	'n'
				; SAVE ALL TRANSFRRED BUT NOT WRITTEN
	CALL	FLSH_WB		; RECORDS
	LXI	H,NXT_STN
	CALL	CMP_STN
TR_TO_C:CALL	SAVE_IN_BUF	; TRANSFER CURRENT RECORD
	LDA	SECTALL		; TO SECTOR BUFFER
	mov	c,a
	lda	FullMask
	CMP	c
	JNZ	END_WR
	MARK	'w'
	CALL	EXC_BUFS	; SECTOR BUFFER FULL - SAVE IT
	CALL	WT_END_CMD
	LXI	H,CUR_STN
	CALL	SET_STN
	LHLD	CUR_BF
	XCHG
	push	h
	lhld	SECT
	CALL	FD_WR_INIT
	pop	h
	XRA	A
	STA	SECTALL
END_WR:	MVI	A,WRITING
	STA	LAST_OPER
	LDA	IO_RESULT
	RET

SAVE_IN_BUF:
;	MARK	'T'
	LHLD	NXT_BF
	CALL	CALC_OFFSET
	MOV	C,A
	LDA	SECTALL
	ORA	C
	STA	SECTALL
	XCHG
	LHLD	DMA_ADDR
CPYREC:	MVI	B,128
CPY_S1:	MOV	A,M
	STAX	D
	INX	H
	INX	D
	DCR	B
	JNZ	CPY_S1
	LDA	IO_RESULT
	RET


FLSH_WB:
	LDA	LAST_OPER
	CPI	WRITING
	RNZ
	LDA	SECTALL
	ORA	A
	RZ
	MARK	'f'
	CALL	WT_END_CMD
	LXI	H,NXT_STN
	CALL	SET_STN
	LHLD	CUR_BF
	XCHG
	CALL	RDSECT
	LHLD	CUR_BF
	XCHG
	LHLD	NXT_BF
	lda	RecsPerSect
	mov	c,a
	LDA	SECTALL
FLSH_L:	RRC
	JC	CPY_R
	PUSH	B
	LXI	B,128
	DAD	B
	XCHG
	DAD	B
	XCHG
	POP	B
	JMP	FLSH_0
CPY_R:	PUSH	PSW
	CALL	CPYREC
	POP	PSW
FLSH_0:	DCR	C
	JNZ	FLSH_L
	LHLD	CUR_BF
	XCHG
	push	h
	lhld	SECT
	CALL	FD_WR_INIT
	pop	h
	MVI	A,WRITING
	STA	LAST_OPER
MAKE_BUFF_EMPTY:
	LXI	H,NXT_STN
	CALL	CMP_STN
	XRA	A
	STA	SECTALL
	RET

LAST_OPER::	DB	NOTHING	; Type of last operation

SECTALL:DB	0	; RECORD ALLOCATION MAP IN SECTOR

; Disk parameters
FLP_TBL::
RecsPerSect:	db	4
MaxSect:	db	9	; Maximum sector number
FullMask:	db	0fh	; Full sector mask
SectShift:	db	2

CUR_BF:	DS	2	; CURRENT SECTOR BUFFER
CUR_STN:DS	3	; CUR SIDE,SECTOR & TRACK

NXT_BF:	DS	2
NXT_STN:DS	3

NEW_STN:DS	3	; NEW REC. SETTINGS
IO_RESULT:	ds	1
	END
