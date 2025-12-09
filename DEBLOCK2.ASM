	.z80

BIOS_HOME:
	PUSH	HL
	LD	HL,0
	LD	(ARG_TRACK),HL
	POP	HL
	RET

BIOS_SELDSK:
	LD	A,C		; check device number
	CP	STORAGE_COUNT
	LD	HL,0
	RET	NC
	;jp	c, $+4
	;XOR	A

	LD	(ARG_SELDSK),A
	LD	L,A		; calc DPH address
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	ADD	HL,HL
	PUSH	DE
	LD	DE,DPBASE;DPHLIST
	ADD	HL,DE
	PUSH	HL		; save DPB address
	LD	DE,10
	ADD	HL,DE
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	EX	DE,HL
	LD	(ARG_DPB),HL

	LD   H, A
	LD   A, (USERNO)
	ADD  A, A
	ADD  A, A
	ADD  A, A
	ADD  A, A
	ADD  A, H
	LD	 (TDRIVE),A	; save current device number

	POP	HL
	POP	DE
	RET

BIOS_SETTRK:
	PUSH	HL
	LD	H,B
	LD	L,C
	LD	(ARG_TRACK),HL
	POP	HL
	RET

BIOS_SETSEC:
	PUSH	HL
	LD	H,B
	LD	L,C
	LD	(ARG_SECTOR_128),HL
	POP	HL
	RET

BIOS_SETDMA:
	PUSH	HL
	LD	H,B
	LD	L,C
	LD	(ARG_DMA),HL
	POP	HL
	RET

BIOS_SECTRN:
	LD	H,B
	LD	L,C
	RET

BIOS_PRSTAT:
	xor  a ; Printer is not ready
	ret

;
;**************************************************************
;*
;*           F I L E   A P P E N D   O P T I M I Z A T I O N
;*
;**************************************************************
;

BIOS_WRITE:
	PUSH	BC
	PUSH	DE
	PUSH	HL

	; Additional information from CP/M:
	; 0 - Data writing can be delayed
	; 1 - We must write all data to disk just now
	; 2 - Writing to file system block not used before
	; Reported about first 128-byte sector from 2048-byte block.
	LD	A,C
	LD	(WRITE_MODE),A

	; If we writing to file system block not used before
	; set flag not to read from disc
	CP	2
	JP	Z,BIOS_WRITE_FIRST_NEW

	; If counter is zero - reading as usual
	LD	A,(NEW_COUNT)
	OR	A
	JP	Z,BIOS_WRITE_STOP_NEW

	; Each writing decrements the counter
	DEC	A
	LD	(NEW_COUNT),A

	; If disk, track or sector is changed - counter is cleared
	LD	A,(NEW_DISK)
	LD	HL,ARG_SELDSK
	CP	(HL)
	JP	NZ,BIOS_WRITE_STOP_NEW

	LD	HL,(NEW_TRACK)
	EX	DE, HL
	LD	HL,(ARG_TRACK)
	EX	DE, HL
	CALL	CMP_HL_PDE
	JP	NZ,BIOS_WRITE_STOP_NEW

	LD	HL,(NEW_SECTOR)
	EX	DE, HL
	LD	HL,(ARG_SECTOR_128)
	EX	DE, HL
	CALL	CMP_HL_PDE
	JP	NZ,BIOS_WRITE_STOP_NEW

BIOS_WRITE_NEW:
	; Each writing increment the sector number
	INC	HL
	LD	(NEW_SECTOR),HL

	; Переход на следующую дорожку
	EX	DE,HL
	LD	HL,(ARG_DPB)
	EX	DE,HL
	CALL	CMP_HL_PDE
	JP	NZ,BIOS_WRITE_TRACK
	LD	HL,0
	LD	(NEW_SECTOR),HL ; TODO: May save one time at the end
	LD	HL,(NEW_TRACK)
	INC	HL
	LD	(NEW_TRACK),HL
BIOS_WRITE_TRACK:

	LD	BC,0  ; Working mode - writing, reading is forbidden

BIOS_WRITE_END:
	CALL	BUFFER_WORK

	POP     HL
	POP     DE
	POP     BC
	RET

BIOS_WRITE_FIRST_NEW:
	LD	HL,(ARG_DPB)
	LD  DE,	3
	ADD HL, DE
	LD	A,(HL)	; Get block mask. 7 => 1k, 0Fh => 2k, 1Fh => 4k...
	LD	(NEW_COUNT),A
	LD	A,(ARG_SELDSK)
	LD	(NEW_DISK),A
	LD	HL,(ARG_TRACK)
	LD	(NEW_TRACK),HL
	LD	HL,(ARG_SECTOR_128)
	JP	BIOS_WRITE_NEW

BIOS_WRITE_STOP_NEW:
	; Clear the counter blocking reading from disc
	XOR	A
	LD	(NEW_COUNT),A
	LD	BC,1  ;  Working mode - usual writing
	JP	BIOS_WRITE_END

;**************************************************************

BIOS_READ:
	;PUSH	BC
	;PUSH	DE
	;PUSH	HL

	; Clear the counter blocking reading from disc
	XOR	A
	LD	(NEW_COUNT),A

	;JP	BUFFER_READ

	;POP     HL
	;POP     DE
	;POP     BC
	;RET

;
;**************************************************************
;*
;*           5 1 2   B Y T E   S E C T O R S
;*
;**************************************************************
;

BUFFER_READ:
	; Working mode -  reading from disc to buffer
	LD	A,2
	LD	(WRITE_MODE),A
	LD	BC,101h

BUFFER_WORK:
	; Compute the real 512-byte sector number
	LD  D, C
	LD	HL,(ARG_SECTOR_128)
	LD  C, 2
	CALL	SHIFTR
	LD	(ARG_SECTOR_512),HL
	LD  C, D

	; If there is no data in buffer - jump to loading
	LD	A,(BUFFER_DISK)
	CP	-1
	JP	Z,BUFFER_WORK_3

	; If there is another disc, track or sector in buffer - save buffer
	; and load another sector
	LD	HL,ARG_SELDSK
	CP	(HL)
	JP	NZ,BUFFER_WORK_2

	LD	HL,(ARG_TRACK)
	EX	DE, HL
	LD	HL,(BUFFER_TRACK)
	EX	DE, HL
	CALL	CMP_HL_PDE
	JP	NZ,BUFFER_WORK_2

	LD	HL,(ARG_SECTOR_512)
	EX	DE, HL
	LD	HL,(BUFFER_SECTOR)
	EX	DE, HL
	CALL	CMP_HL_PDE
	JP	Z,BUFFER_WORK_5

BUFFER_WORK_2:
	; If we need to save buffer - do this
	LD	A,(BUFFER_CHANGED)
	OR	A
	CALL	NZ,BUFFER_WORK_7
	OR	A
	RET	NZ

BUFFER_WORK_3:
	; Information about new sector
	XOR	A
	LD	(BUFFER_CHANGED),A
	LD	A,(ARG_SELDSK)
	LD	(BUFFER_DISK),A
	LD	HL,(ARG_TRACK)
	LD	(BUFFER_TRACK),HL
	LD	HL,(ARG_SECTOR_512)
	LD	(BUFFER_SECTOR),HL

	; If loading to buffer is allowed - do this
	LD	A,C
	OR	A
	PUSH	BC
	CALL	NZ,BIOS_READ_512
	POP	BC
	OR	A
	JP  Z,BUFFER_WORK_5

	; Clear the buffer if the reading failed
	LD	A,-1
	LD	(BUFFER_DISK),A
	RET

BUFFER_WORK_5:
	; Compute 128-byte sector address in buffer
	LD	A,(ARG_SECTOR_128)
	AND	3
	LD	H,A
	LD	L,0
	LD  C, 1
	CALL	SHIFTR
	LD	DE,BUFFER
	ADD	HL,DE
	EX	DE,HL

	; Read or write 128-byte sector
	LD	HL,(ARG_DMA)
	LD	C,CPM_SECTOR_SIZE
	LD	A,B ; 0 - writing, 1 - reading
	OR	A
	JP	NZ,BUFFER_WORK_6
	LD	A,1
	LD	(BUFFER_CHANGED),A
	EX	DE,HL
BUFFER_WORK_6:
	LD	A,(DE)
	INC	DE
	LD	(HL),A
	INC	HL
	DEC	C
	JP	NZ,BUFFER_WORK_6

	; If CP/M does not require to save the buffer just now, we can exit
	LD	A,(WRITE_MODE)
	CP	1
	LD	A,0
	RET	NZ

BUFFER_WORK_7:
	; Write the sector to disc
	PUSH	BC
	XOR	A
	LD	(BUFFER_CHANGED),A
	CALL	BIOS_WRITE_512
	POP	BC
	RET


BIOS_READ_512:
	CALL	SD_SEEK
	LD	DE, BUFFER
	LD	HL, 512
	JP	CmdRead

BIOS_WRITE_512:
	CALL	SD_SEEK
	LD	DE, BUFFER
	LD	HL, 512
	JP	CmdWrite
;
;**************************************************************
;*
;*           M I S C   F U N C T I O N S
;*
;**************************************************************
;
;
;   Shift (HL) right (C) bits.
;
SHIFTR:	INC	C
SHIFTR1:DEC	C
	RET	Z
	LD	A,H
	OR	A
	RRA
	LD	H,A
	LD	A,L
	RRA
	LD	L,A
	JP	SHIFTR1

CMP_HL_PDE:
	LD	A,(DE)
	CP	L
	RET	NZ
	INC	DE
	LD	A,(DE)
	CP	H
	RET


	.8080
