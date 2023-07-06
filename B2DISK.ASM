;**********************************************
;*   B2DISK.ASM - CP/M BIOS disk functions    *
;* 	  (c) TCHV	1991-1993     	      *
;**********************************************

; This module defines the following procedures :
PUBLIC	DSKINIT 	; Disk initialisation
; CP/M BIOS functions
PUBLIC	HOME@,SELDSK,SETDMA,SECTRN,SETTRK,SETREC,RD_REC,WR_REC

DSKVER::	DB	10,13,'Disk BIOS V3.1      7-sep-1993',0

; History

;	25-jun-1993 - delete controller dependent features & add fdcntr
;		      module
;	 7-sep-1993 - add some comments & transfer disk features into
;		      separate modules

;EXTRN ChgDrive,WT_END_CMD

;EXTRN RamD_R,RamD_W,RamD_I,RAM_TO_EXT,EXT_TO_RAM

;EXTRN FlpD_R,FlpD_W,FlpD_I,FLSH_WB,LAST_OPER,FLP_TBL

;INCLUDE B0DISK.MAC

PROFI_DISKS	EQU	1
MaxDiskCode		EQU	'B';'E'   ; Maximum disk code


; DISK ALLOCATION
FLOP40		EQU	1	; DISK B:
SD		EQU	0
FLOP80		EQU	0	; A:
RAMDISK		EQU	2	; C:


FRST_T	EQU	0	; FIRST TRACK OF CP/M AREA


;*************** Disk buffers allocation *****************
DIRBF:	ds 80H;		EQU	0E6D0h-80h


;ALL00	EQU	DIRBF-31
;CHK00	EQU	ALL00-10h

ALL01:	DS	64
CHK01:	DS	32

ALL02:	DS	64
CHK02:	DS	32

ALL03:	DS	250
CHK03:	DS	1

;ALL02:	DS	16
;CHK02:	DS	1

;ALL03	EQU	0EFE0H
;CHK03:	DS	16

;ALL04:	DS	64
;CHK04:	DS	32



; Disk parameter header table
DPBASE:
	;DW	0,0,0,0,DIRBF,DPBLK1,CHK00,ALL00	; Disk A
	DW	1,0,0,0,DIRBF,DPBLK2,CHK01,ALL01	; Disk A
	DW	1,0,0,0,DIRBF,DPBLK2,CHK02,ALL02	; Disk B
	DW	0,0,0,0,DIRBF,DPBLK3,CHK03,ALL03	; Disk C
	;DW	0,0,0,0,DIRBF,DPBLK1,CHK03,ALL03	; Disk D
	;DW	0,0,0,0,DIRBF,DPBLK4,CHK04,ALL04	; Disk E


; ** Sector translation tables - not needed
TRANS1:;DB	1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
;	DB	19,20,21,22,23,24,25,26,27,28,29,30,31,32,33
;	DB	34,35,36,37,38,39,40,41,42,43,44,45,46,47,48
;	DB	49,50,51,52,53,54,55,56,57,58,59,60,61,62,63
;	DB	64,65,66,67,68,69,70,71,72

TRANS2:;DB	1,2,3,4,5,6,7,8
; **

; FLOPPY 40-TRK DISK (A:,D:) PARAMETER BLOCK
;DPBLK1:	DW	72	;SEC ON TRK
;	DB	04H	;BLK SHF
;	DB	0FH	;BLK MASK
;	DB	00H	;0-MASK
;	DW	179	;DISK SIZE
;	DW	63	;DIR LEN
;	DB	1000000b;Directory allocation - each bit for one group
;	DB	0000000b; -"-
;	DW	16	;Disk bitmap size
;	DW	FRST_T+1


; FLOPPY 80-TRK DISK (B:) PARAMETER BLOCK
DPBLK2:	DW	80	;SEC ON TRK
	DB	04H	;BLK SHF
	DB	0FH	;BLK MASK
	DB	00H	;0-MASK
	DW	780/2-1	;DISK SIZE
	DW	128-1	;DIR LEN
	DB	11000000B	; DIRECTORY BIT MAP
	DB	00000000B
	DW	32
	DW	2

; gide-cfa  DISK (Ñ:) PARAMETER BLOCK
DPBLK3:
	DW	128	;SEC ON TRK
	DB	5	;BLK SHF
	DB	31	;BLK MASK
	DB	01H	;0-MASK
	DW	2000-1	;DISK SIZE = 1000*512*16/4096 -1
	DW	1024-1	;DIR LEN
	DB	0FFh	; DIRECTORY BIT MAP
	DB	0
	DW	0
	DW	1

; ********** RAMDISK (C:) PARAMETER BLOCK ***********
; Last operation codes


;DPBLK3:	DW	C_SEC_ON_TRK	;SEC ON TRK
;	DB	3	;BLK SHF
;	DB	7	;BLK MASK
;	DB	00H	;0-MASK
;	DW	64-8-1	;DISK SIZE
;	DW	C_DIR_ENTRS-1	;DIR LEN
;	DB	10000000b
;	DB	00000000b
;	DW	0
;	DW	C_OFFSET

;; FLOPPY 80-TRK DISK (E:) PARAMETER BLOCK
;DPBLK4:	DW	72	;SEC ON TRK
;	DB	04H	;BLK SHF
;	DB	0FH	;BLK MASK
;	DB	00H	;0-MASK
;	DW	(720-9)/2-1	;DISK SIZE
;	DW	128-1	;DIR LEN
;	DB	1100000b
;	DB	0000000b
;	DW	32
;	DW	1
;************** End disk buffer allocation & parameters *********

;-------- DISK INITIALIZATION ----------
DskInit:
	XRA	A
	STA	OLDDSK
	STA	OLDF40
        call	RamD_I
	call	SD_I
        jmp	FlpD_I
        

SAV_SYS::
	RET
;	LXI	H,C_BASE;##
;	LXI	D,0
;	lxi	b,C_SIZE+D_SIZE
;	jmp	RAM_TO_EXT

;	CALL	FLSH_WB
;
;	LXI	H,C_BASE;##
;	LXI	D,0
;	lxi	b,C_SIZE+D_SIZE
;	jmp	EXT_TO_RAM

;------ SOME CP/M BIOS FUNCTIONS -------

HOME@:	MVI	C,0
SETTRK:	LXI	H,CPM_TRACK
	MOV	M,C
	RET


SELDSK:	LXI	H,0
	MOV	A,C
	STA	CPM_DISK
	;CALL	CHECK_D
	LDA	CPM_DISK
	CPI	3;MaxDiskCode-'A'+1
	;ORA	A
	RNC
	LDA	CPM_DISK
	MOV	L,A
	MVI	H,0
	DAD	H
	DAD	H
	DAD	H
	DAD	H
	LXI	D,DPBASE
	DAD	D
	RET

CHECK_D::
	LDA	OLDDSK
	MOV	B,A
	LDA	CPM_DISK
	CMP	B
	RZ
	STA	OLDDSK
	RET
	CPI	RAMDISK
	RZ
	CPI	SD
	RZ
	PUSH	PSW	; CHANGE FLOPPY DRIVE
	CALL	FLSH_WB
	CALL	WT_END_CMD
	MVI	A,WRITING
	STA	LAST_OPER
	POP	PSW
	CPI	FLOP80
	MOV	B,A
	MVI	A,2
	STA	DRIVE
	JZ	ChgDrive
	LDA	OLDDSK
	CPI	'E'-'A'
	LDA	DRIVE
	JZ	ChgDrive

	MVI	A,1
	STA	DRIVE
	LDA	OLDF40
	CMP	B
	LDA	DRIVE
        JZ	ChgDrive
	MOV	A,B
	STA	OLDF40
	PUSH	PSW
	LDA	DRIVE
	CALL	ChgDrive
	CALL	PRNT;##
	DB	10,13,'Ins disk ',0
	POP	PSW
	ADI	'A'
	MOV	C,A
	CALL	CONOUT;##
	CALL	PRNT;##
	DB	': & type a key',10,13,0
	JMP	CONIN


SETREC:	LXI	H,CPM_RECORD
	MOV	M,C
	RET

;-----------------------------------------

SECTRN:
ifdef	PROFI_DISKS
	mov	a,c
	inr	a
	STA	CPM_RECORD
	mov	l,a
	ret
else
	LDA	CPM_DISK
	CPI	FLOP80
	PUSH	B
	MOV	A,C
	JNZ	NO_TRAN	; NO INTERLEAVE TRANSLATION

; PERFORM INTERLEAVE (1:2) TRANSLATION
	ANI	3	; SAVE 2 LOWEST BITS OF SECT NUMBER
	MOV	B,A

	MOV	A,C
	XRA	B	; RESET THESE 2 BITS
	CPI	36
	JC	FIRST_HALF
	SUI	36
	ADD	A
	ADI	4
	JMP	$+4
FIRST_HALF:
	ADD	A
	ORA	B	; RESTORE SAVED BITS

NO_TRAN:INR	A
	STA	CPM_RECORD
	MOV	L,A
	POP	B
	RET
endif
;---------------------------------
SET_PARAMS::
	lxi	h,FLP_TBL ; Floppy disk physical parameter table
	lda	CPM_DISK
	cpi	FLOP80
	jnz	noFLOP80
	mvi	m,8
	inx	h
	mvi	m,5
	inx	h
	mvi	m,0ffh
	inx	h
	mvi	m,3
	ret

noFLOP80:
	mvi	m,4
	inx	h
	mvi	m,9
	inx	h
	mvi	m,1111B
	inx	H
	mvi	m,2
	ret

;-------------------------
SETDMA:	MOV	L,C
	MOV	H,B
	SHLD	DMA_ADDR
	RET

;============ FLOPPY DISK OPERATIONS ============


;*****************************************
; READ CURRENT RECORD (128 BYTES)
;  TRACK & SECTOR DEFINES RECORD
;	POSITION
;\
RD_REC:
	LDA	CPM_DISK
	CPI	SD
	JMP	SD_R
	;JZ	SD_R
	CPI	RAMDISK
	JZ	RamD_R
	jmp	FlpD_R

;**********************************************
; WRITE CURRENT RECORD TO DISK
;  (TRACK) & (SECTOR) DEFINES RECORD
;		POSITION
WR_REC::
	LDA	CPM_DISK
	CPI	SD
	JMP	SD_W
	;JZ	SD_W
	CPI	RAMDISK
	JZ	RamD_W	; Check for ramdisk call.
	jmp	FlpD_W


OLDDSK::	DB	0	; LAST CP/M DISK



BAD::	MVI	A,0FFH
	STA	_IO_RESULT
	RET

;	CALL	PRNT##
;	DB	10,13,'Bad sector ',0
;	JMP	0

; --------------------------------------------------------
;		CP/M DISK BIOS VARIABLES

_IO_RESULT:DS	1
SECT::	ds	1
SIDE::	ds	1
DRIVE:	ds	1

CPM_TRACK::	DB	0
CPM_RECORD::	DB	0
CPM_DISK::	DB	0

DMA_ADDR::	DW	0
DPTR:		DW	0

;STK_SAVE:	DS	2
OLDF40::		ds	1
;		END
		