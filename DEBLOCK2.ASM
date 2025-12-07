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
	xor  a ; Принтер не готов
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

	; Дополнительная информация от CP/M:
	; 0 - Запись данных можно отложить
	; 1 - Нужно записать все данные на дискету сейчас
	; 2 - Запись в блок файловой системы,который до этого не использовался
	; Сообщается только о первом 128-секторе 2048 байтного блока.
	LD	A,C
	LD	(WRITE_MODE),A

	; Если это запись в блок файловой системы, который до этого не
	; использовался, то взводится счетчик блокирующий чтение с дискеты
	CP	2
	JP	Z,BIOS_WRITE_FIRST_NEW

	; Если счетчик равен нулю, то читаем как обычно
	LD	A,(NEW_COUNT)
	OR	A
	JP	Z,BIOS_WRITE_STOP_NEW

	; С каждой записью уменьшается счетчик
	DEC	A
	LD	(NEW_COUNT),A

	; Если изменился диск, дорожка или сектор, то счетчик сбрасывается
	LD	A,(NEW_DISK)
	LD	HL,ARG_SELDSK
	CP	(HL)
	JP	NZ,BIOS_WRITE_STOP_NEW

	LD	HL,(NEW_TRACK)
	LD	DE,ARG_TRACK
	CALL	CMP_HL_PDE
	JP	NZ,BIOS_WRITE_STOP_NEW

	LD	HL,(NEW_SECTOR)
	LD	DE,ARG_SECTOR_128
	CALL	CMP_HL_PDE
	JP	NZ,BIOS_WRITE_STOP_NEW

BIOS_WRITE_NEW:
	; С каждой записью увеличивается номер сектора
	INC	HL
	LD	(NEW_SECTOR),HL

	; Переход на следующую дорожку
	EX	DE,HL
	LD	HL,(ARG_DPB)
	EX	DE,HL
	CALL	CMP_HL_PDE
	JP	NZ,BIOS_WRITE_TRACK
	LD	HL,0
	LD	(NEW_SECTOR),HL ; TODO: Можно сохранять один раз в конце
	LD	HL,(NEW_TRACK)
	INC	HL
	LD	(NEW_TRACK),HL
BIOS_WRITE_TRACK:

	LD	BC,0  ; Режим работы - запись, чтение запрещено

BIOS_WRITE_END:
	CALL	BUFFER_WORK

	POP     HL
	POP     DE
	POP     BC
	XOR	A
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
	; Сброс счетчика блокирующего чтение с дискеты
	XOR	A
	LD	(NEW_COUNT),A
	LD	BC,1  ; Режим работы - обычная запись
	JP	BIOS_WRITE_END

;**************************************************************

BIOS_READ:
	PUSH	BC
	PUSH	DE
	PUSH	HL

	; Сброс счетчика блокирующего чтение с дискеты
	XOR	A
	LD	(NEW_COUNT),A

	CALL	BUFFER_READ

	POP     HL
	POP     DE
	POP     BC
	RET

;
;**************************************************************
;*
;*           5 1 2   B Y T E   S E C T O R S
;*
;**************************************************************
;

BUFFER_READ:
	; Режим работы - чтение с дискеты в буфер
	LD	A,2
	LD	(WRITE_MODE),A
	LD	BC,101h

BUFFER_WORK:
	; Вычисление номера реального 512-байтного сектора
	LD  D, C
	LD	HL,(ARG_SECTOR_128)
	LD  C, 2
	CALL	SHIFTR
	LD	(ARG_SECTOR_512),HL
	LD  C, D

	; Если в буфере нет данных, то переходим на загрузку
	LD	A,(BUFFER_DISK)
	CP	-1
	JP	Z,BUFFER_WORK_3

	; Если в буфере не тот диск, дорожка, сектор, то сохраняем буфер
	; и загружем другой сектор
	LD	HL,ARG_SELDSK
	CP	(HL)
	JP	NZ,BUFFER_WORK_2

	LD	HL,(ARG_TRACK)
	LD	DE,BUFFER_TRACK
	CALL	CMP_HL_PDE
	JP	NZ,BUFFER_WORK_2

	LD	HL,(ARG_SECTOR_512)
	LD	DE,BUFFER_SECTOR
	CALL	CMP_HL_PDE
	JP	Z,BUFFER_WORK_5

BUFFER_WORK_2:
	; Если нужно сохранить буфер, то сохраняем
	LD	A,(BUFFER_CHANGED)
	OR	A
	CALL	NZ,BUFFER_WORK_7
	OR	A
	RET	NZ

BUFFER_WORK_3:
	; Информация о новом секторе
	XOR	A
	LD	(BUFFER_CHANGED),A
	LD	A,(ARG_SELDSK)
	LD	(BUFFER_DISK),A
	LD	HL,(ARG_TRACK)
	LD	(BUFFER_TRACK),HL
	LD	HL,(ARG_SECTOR_512)
	LD	(BUFFER_SECTOR),HL

	; Если разрешено загрузить в буфер, то загружаем
	LD	A,C
	OR	A
	PUSH	BC
	CALL	NZ,BIOS_READ_512
	POP	BC
	OR	A
	JP  Z,BUFFER_WORK_5

	; Очистить буфер, если не удалось прочитать
	LD	A,-1
	LD	(BUFFER_DISK),A
	RET

BUFFER_WORK_5:
	; Вычисляем адрес 128 байтного сектора в буфере
	LD	A,(ARG_SECTOR_128)
	AND	3
	LD	H,A
	LD	L,0
	LD  C, 1
	CALL	SHIFTR
	LD	DE,BUFFER
	ADD	HL,DE
	EX	DE,HL

	; Читаем или записываем 128 байтный сектор
	LD	HL,(ARG_DMA)
	LD	C,CPM_SECTOR_SIZE
	LD	A,B ; 0 - запись, 1 - чтение
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

	; Если CP/M не требует сохранить буфер сейчас,то выходим
	LD	A,(WRITE_MODE) ; Разместить в регистре WRITE_MODE
	CP	1
	LD	A,0
	RET	NZ

BUFFER_WORK_7:
	; Записываем сектор на дискету
	;PUSH	BC
	XOR	A
	LD	(BUFFER_CHANGED),A
	CALL	BIOS_WRITE_512
	;POP	BC
	RET


BIOS_READ_512:
	;PUSH	HL
	;PUSH	DE
	;PUSH	BC
	CALL	SD_SEEK
	LD	DE, BUFFER
	LD	HL, 512
	CALL	CmdRead
	;POP	BC
	;POP	DE
	;POP	HL
	RET

BIOS_WRITE_512:
	;PUSH	HL
	;PUSH	DE
	;PUSH	BC
	CALL	SD_SEEK
	LD	DE, BUFFER
	LD	HL, 512
	CALL	CmdWrite
	;POP	BC
	;POP	DE
	;POP	HL
	RET

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
