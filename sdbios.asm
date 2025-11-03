; SD BIOS for Computer "Radio 86RK"
; (c) 09-10-2014 vinxru (aleksey.f.morozov@gmail.com)

	;.org 07600h-683 ; Last byte should be at 0D5FFh
				   

IFNDEF USE_DMA
USER_PORT	EQU PPI2      ; KR580VV55 address
SEND_MODE	EQU 10000000b ; Send mode (1 0 0 A СH 0 B CL)
RECV_MODE	EQU 10010000b ; Receive mode (1 0 0 A СH 0 B CL)
ENDIF

; MC codes
STA_START	EQU	040h ; MC switched to command receive mode
STA_WAIT	EQU	041h ; MC is executing command
STA_OK_DISK	EQU	042h ; The drive is working, MC is ready to receive command
STA_OK_CMD	EQU	043h ; Command is executed
STA_OK_READ	EQU	044h ; MC is ready to transfer next data block
STA_OK_ENTRY	EQU	045h ; MC is ready to transfer file record
STA_OK_WRITE	EQU	046h ; MC is waiting for next data block (for write)
STA_OK_ADDR	EQU	047h ; MC is ready to send loading address
STA_OK_BLOCK	EQU	04Fh 

ERR_DATETIME	EQU	50H

; IN and OUT MACRO comands
@in	MACRO	addr
IF ((addr) LT 256)
	in	addr
ELSE
	lda	addr
ENDIF
	ENDM

@out	MACRO	addr
IF ((addr) LT 256)
	out	addr
ELSE
	sta	addr
ENDIF
	ENDM


;----------------------------------------------------------------------------
; D-режим, HL-имя файла / A-код ошибки

CmdOpenDelete: 
	; Command code
	MVI	A, 4
	CALL	StartCommand

	; Mode
	MOV	A, D
	CALL	SendByte

	; File name
	CALL	SendString

	; Wait for MC will be ready
	CALL	SwitchRecvAndWait
	CPI	STA_OK_CMD
	JZ	Ret0
IFDEF USE_DMA
	ret
ELSE
	JMP	EndCommand
ENDIF
;----------------------------------------------------------------------------
; B-mode, DE:HL-position / A-error code, DE:HL-position

CmdSeekGetSize:
	; Command code
	MVI 	A, 5
	CALL	StartCommand

	; Mode
	MOV	A, B
	CALL	SendByte

	; Position
	CALL	SendWord
	XCHG
	CALL	SendWord

	; Wait for MC will be ready. Should answer with STA_OK_CMD code
	CALL	SwitchRecvAndWait
	CPI	STA_OK_CMD
IFDEF USE_DMA
	RNZ
ELSE
	JNZ	EndCommand
ENDIF
	; File size
	CALL	RecvWord
	XCHG
	CALL	RecvWord

	; The result
	JMP	Ret0
	
;----------------------------------------------------------------------------
; HL-size, DE-address / HL-how much was loaded, A-error code

CmdRead:
	; Command code
	MVI	A, 6
	CALL	StartCommand

	; Address in BC
	MOV	B, D
	MOV	C, E

	; Block size
	CALL	SendWord	; HL-size

	; Switch to receive mode
	CALL	SwitchRecv

	; Block receiving. On enter BC - address, HL - received length
IFDEF USE_DMA
; Load data to address in BC. 
; On exit: HL - how much loaded
; A will be rewritten
; If no errors, Z=1 on exit

RecvBuf:
	LXI	H, 0
RecvBuf0:
	; Wait
	CALL	WaitForReady
	CPI	STA_OK_READ
	JZ		Ret0	; Z on exit (no error)
	CPI	STA_OK_BLOCK
	RNZ;	EndCommand	; NZ on exit (error)

	; Loaded data size in DE
	CALL	RecvWord

	; Overall size in HL
	DAD D

	;CALL	ReceiveBufferIfEmpty
	; Load DE bytes to address in BC
	CALL	RecvBlock

	JMP	RecvBuf0
ELSE
	JMP	RecvBuf
ENDIF
;----------------------------------------------------------------------------
; HL-size, DE-address / A-error code

CmdWrite:
	; Command code
	MVI	A, 7
	CALL	StartCommand
	
	; Block size
	CALL	SendWord	; HL-размер

	; Now the address in HL
	XCHG
IFDEF USE_DMA
	MOV    B,H
	MOV    C,L
ENDIF
CmdWriteFile2:
	; Command result
	CALL	SwitchRecvAndWait
	CPI  	STA_OK_CMD
	JZ  	Ret0
	CPI  	STA_OK_WRITE
IFDEF USE_DMA
	RNZ
ELSE
	JNZ	EndCommand
ENDIF

	; Block size MC may receive in DE
	CALL	RecvWord

	; Switch to send mode
	CALL	SwitchSend

	; Block transfer. Address in BC, length in DE.
CmdWriteFile1:
IFDEF USE_DMA
	CALL	SendBlock
ELSE
	MOV	A, M
	INX	H
	CALL	SendByte
	DCX	D
	MOV	A, D
	ORA	E
	JNZ 	CmdWriteFile1

	JMP	CmdWriteFile2
ENDIF
;--------------------------------------------------------------------------------
CmdGetDate:
	MVI	A,2Ah
	call	StartCommand

	call	SwRecvSave; WeekDay
	call	RecvSave  ; Month
	call	RecvSave  ; Date (1...31)
	call	RecvSave
EndDateCmd2:
	call	RecvByte
EndDateCmd:
	cpi	STA_OK_CMD
IFDEF	USE_DMA
	RET
ELSE
	jz	ret0
	jmp	EndCommand
ENDIF

CmdSetDate:
	mvi	a,2Bh
	call	StartCommand

	mvi	a,2 ; WeekDay todo: need to compute from Day,Month,Year
	inx	d
	call	SendByte
	call	LdByteSend ; Month
	call	LdByteSend ; Day
	call	LdByteSend ; Year
	jmp	CmdSetXX

SwRecvSave:
	call	SwitchRecvAndWait
	stax	d
	inx	d
	ret

RecvSave:
	call	RecvByte
	stax	d
	inx	d
	ret

CmdGetTime:
	mvi	A,2Ch
	call	StartCommand

	call	SwRecvSave; Hours (0...23)
	call	RecvSave  ; Minutes (0...59)
	call	RecvSave  ; Seconds (0...59)
	call	RecvByte
	call	RecvByte
	jmp	EndDateCmd2

CmdSetTime:
	mvi	a,2Dh
	call	StartCommand

	call	LdByteSend ; Hours (0...23)
	call	LdByteSend ; Minutes (0...59)
	call	LdByteSend ; Seconds (0...59)
	mvi	a,100      ; SecondFraction
	call	SendByte
	xra	a	   ; SubSeconds
CmdSetXX:
	call	SendByte
	call	SwitchRecvAndWait
	jmp	EndDateCmd


;----------------------------------------------------------------------------
; Начало любой команды. 
; A - код команды
;----------------------------------------------------------------------------
; Начало любой команды. 
; A - код команды
StartCommand:
	; The first stage is synchronization with the controller
	; 256 attempts are accepted, each of which skips 256+ bytes
	; That is, this is the maximum amount of data that the controller can transmit
	PUSH	B
	PUSH	H
	PUSH	PSW
IFNDEF USE_DMA
	MVI	C, 0
ENDIF

StartCommand1:
	; Send mode (release the bus) and init HL
	CALL	SwitchRecv

IFNDEF USE_DMA
	; Начало любой команды (это шина адреса)
	;LXI	H, USER_PORT+1
	;MVI	M,0
	XRA	A
	@out	USER_PORT+1
	;MVI	M, 44h
	MVI	A,44h
	@out	USER_PORT+1
	;MVI	M, 40h
	MVI	A,40h
	@out	USER_PORT+1
	;MVI	M, 0h
	XRA	A
	@out	USER_PORT+1
ENDIF
	; If there is synchronization, controller will answer STA_START
	CALL	RecvByte
	CPI	STA_START
IFDEF USE_DMA
	JNZ	StartCommandErr2
ELSE
	JZ	StartCommand2

	; Пауза. И за одно пропускаем 256 байт (в сумме будет 
	; пропущено 64 Кб данных, максимальный размер пакета)
	PUSH	B
	MVI	C, 0
StartCommand3:
	CALL	RecvByte
	DCR	C
	JNZ	StartCommand3
	POP	B

	; Попытки
	DCR	C
	JNZ	StartCommand1
	; Код ошибки
	MVI	A, STA_START
StartCommandErr2:
	POP	B ; Прошлое значение PSW
	POP	H ; Прошлое значение H
	POP	B ; Прошлое значение B
	POP	B ; Выходим через функцию.
	RET

;----------------------------------------------------------------------------
; Синхронизация с контроллером есть. Контроллер должен ответить STA_OK_DISK

StartCommand2:
ENDIF
	; Ответ	 	
	CALL	WaitForReady
	CPI	STA_OK_DISK
	JNZ	StartCommandErr2

	; Переключаемся в режим передачи
	CALL	SwitchSend

	POP	PSW
	POP	H
	POP	B

	; Передаем код команды
	JMP	SendByte

IFDEF USE_DMA
StartCommandErr2:
	POP	B ; Прошлое значение PSW
	POP	H ; Прошлое значение H
	POP	B ; Прошлое значение B
	POP	B ; Выходим через функцию.
	RET
ELSE

;----------------------------------------------------------------------------
; Переключиться в режим передачи

SwitchSend:
	CALL	RecvByte
SwitchSend0:
	MVI	A, SEND_MODE
	@out	USER_PORT+3
	RET
ENDIF
;----------------------------------------------------------------------------
; Successful command ending 
; and additional tick for MC to relase the bus

Ret0:
	XRA	A

;----------------------------------------------------------------------------
; Command ending with error in A 
;EndCommand:
IFNDEF USE_DMA

EndCommand:
	PUSH	PSW
	CALL	RecvByte
	POP	PSW
ENDIF
	RET

;----------------------------------------------------------------------------
; Receive word in DE 
; A is corrupted.
RecvWord:
IFNDEF DMA_SIMPLE
	CALL	RecvByte
	MOV	E, A
	CALL	RecvByte
	MOV	D, A
ELSE
	PUSH	H
	PUSH	B
	LXI	D,BUF
	LXI	B,4002h
	;RST	3;
	CALL	SET_DMAW
	XCHG
	MOV	E,M
	INX	H
	MOV	D,M
	POP	B
	POP	H
ENDIF
	RET

;----------------------------------------------------------------------------
; Send word from HL 
; A is corrupted.
SendWord:
IFNDEF DMA_SIMPLE
	MOV	A, L
	CALL	SendByte
	MOV	A, H
	JMP	SendByte
ELSE
	PUSH	D
	PUSH	B
	LXI	D, BUF
	MOV	A, L
	STAX	D
	INX	D
	MOV	A,H
	STAX	D
	DCX	D
	LXI	B,8002h
	JMP	SendDma
ENDIF
;----------------------------------------------------------------------------
; Send string
; HL - string
; A is corrupted.

SendString:
	XRA	A
	ORA	M
	JZ	SendByte
	CALL	SendByte
	INX	H
	JMP	SendString

IFNDEF USE_DMA
;----------------------------------------------------------------------------
; Switch to receive mode

SwitchRecv:
	MVI	A, RECV_MODE
	@out	USER_PORT+3
	RET
ENDIF

;----------------------------------------------------------------------------
; Switch to receive mode and wait for MC ready

SwitchRecvAndWait:
	CALL SwitchRecv

;----------------------------------------------------------------------------
; Wait for MC ready.

WaitForReady:
	CALL	RecvByte
	CPI	STA_WAIT
	JZ	WaitForReady
	RET

IFDEF USE_DMA
;----------------------------------------------------------------------------
; Send DE bytes from address in BC
; A is corrupted.
SendBlock:
	MVI	A,80H
	JMP	RecvSendBlock

;----------------------------------------------------------------------------
; Receive DE bytes to address in BC
; Enlarge BC by block size
; A is corrupted.
RecvBlock:
	MVI	A,40H
RecvSendBlock:
	PUSH	D

	; Swap BC and DE
	PUSH	B
	PUSH	D
	POP	B
	POP	D

	PUSH	B
	ORA	B
	MOV	B,A
	CALL	SET_DMAW
	XCHG
	POP	B
	DAD	B
	XCHG
	MOV	C,E
	MOV	B,D
	POP	D
	RET

;RecvBlock2:
;	JMP	DmaReadVariable
ELSE
;----------------------------------------------------------------------------
; Принять DE байт по адресу BC
; Портим A
RecvBlock:
	PUSH	H
	LXI 	H, USER_PORT+1
	INR 	D
	XRA 	A
	ORA 	E
	JZ 	RecvBlock2
RecvBlock1:
	MVI	A, 20h
	@out	USER_PORT+1
	XRA	A
	@out	USER_PORT+1
	@in	USER_PORT		; 13
	STAX	B		        ; 7
	INX	B		        ; 5
	DCR	E		        ; 5
	JNZ	RecvBlock1		; 10 = 54
RecvBlock2:
	DCR	D
	JNZ	RecvBlock1
	POP	H
	RET

;PPI_PG	EQU	0D0H 

IF 0
RecvBlock:
	PUSH	H
	;MVI	H,20H
IFDEF  	USE_PRG_DC
	@SYSREG	0A0H
	MVI	A,1
	OUT	PPI_PG
	@SYSREG	80H
	LXI	H,PPI_PG*256+1
ELSE
	LXI 	H, USER_PORT+1
ENDIF
	ANA	A
	MOV	A,D
	RAR
	MOV	D,A
	MOV	A,E
	RAR
	MOV	E,A
	INR 	D
	XRA 	A
	ORA 	E
	JZ 	RecvBlock2

RecvBlock1:
	REPT	2
	MVI	 M, 20h			; 10
	MVI	 M, 0			; 10
  IFDEF	USE_PRG_DC
	LDA	PPI_PG*256		; 13
  ELSE
	LDA	USER_PORT		; 13
  ENDIF
	STAX	B			; 7
	INX	B			; 5 = 51
	ENDM
	DCR	E			; 5
	JNZ	RecvBlock1		; 10 = 66
RecvBlock2:
	DCR	D
	JNZ	RecvBlock1
IFDEF	USE_PRG_DC
	@SYSREG	0A0H
	MVI	A,MEM_HI+10h
	OUT	PPI_PG
	@SYSREG	80H
ENDIF
	POP	H
	RET
ENDIF
;----------------------------------------------------------------------------
; Загрузка данных по адресу BC. 
; На выходе HL сколько загрузили
; Портим A
; Если загружено без ошибок, на выходе Z=1

RecvBuf:
	LXI	H, 0
RecvBuf0:
	; Подождать
	CALL	WaitForReady
	CPI	STA_OK_READ
	JZ	Ret0		; на выходе Z (нет ошибки)
	CPI	STA_OK_BLOCK
	JNZ	EndCommand	; на выходе NZ (ошибка)

	; Размер загруженных данных в DE
	CALL	RecvWord

	; В HL общий размер
	DAD D

	; Принять DE байт по адресу BC
	CALL	RecvBlock

	JMP	RecvBuf0
ENDIF
;----------------------------------------------------------------------------
; Copy the string with limit 256 symbols (including terminator)

strcpy255:
	MVI	B, 255
strcpy255_1:
	LDAX	D
	INX	D
	MOV	M, A
	INX	H
	ORA	A
	RZ
	DCR	B
	JNZ	strcpy255_1
	MVI	M, 0 ; Terminator
	RET

LdByteSend:
	ldax	d ; Month
	inx	d
;----------------------------------------------------------------------------
; Send byte from A.
SendByte:
IFDEF USE_DMA
IFNDEF DMA_SIMPLE
	PUSH	H
	LHLD	BUF_PTR
	MOV	M,A
	INX	H
	SHLD	BUF_PTR
	POP H
ELSE
	PUSH	D
	PUSH	B
	LXI	D,BUF
	STAX	D
	LXI	B,8001H
	;RST	3;
SendDma:
	CALL	SET_DMAW
	POP	B
	POP	D
ENDIF
	RET
ELSE
	@out	USER_PORT
ENDIF
;----------------------------------------------------------------------------
; Receive byte into А

RecvByte:
IFDEF USE_DMA
IFNDEF DMA_SIMPLE
	LDA	BUF_SIZE
	ORA	A
	CZ	DmaReadVariable
	LDA	BUF_SIZE
	DCR	A
	STA	BUF_SIZE
	PUSH	H
	LHLD	BUF_PTR
	MOV	A,M
	INX	H
	SHLD	BUF_PTR
	POP	H
ELSE
	PUSH	D
	PUSH	B
	LXI	D,BUF
	LXI	B,4001h
	;RST	3;
	CALL	SET_DMAW
	LDAX	D
	POP	B
	POP	D
ENDIF
ELSE
	MVI	A, 20h
	@out	USER_PORT+1
	XRA	A
	@out	USER_PORT+1
	@in	USER_PORT
ENDIF
	RET
IFDEF USE_DMA
IFNDEF DMA_SIMPLE
;----------------------------------------------------------------------------
SEND_MODE	EQU 0	 ; Send mode
RECV_MODE	EQU 1	 ; Receive mode
;----------------------------------------------------------------------------
; Set send or receive mode

SwitchRecv:
	PUSH	H
	LDA	Mode
	ORA	A ; CPI SEND_MODE
	JNZ	RM01

	PUSH	D
	PUSH	B
	LXI	H,-BUF
	XCHG
	LHLD	BUF_PTR
	DAD	D
	MOV	A,H
	ORA	L
	JZ	RM02
	XCHG
	LXI	H,BUF-2
	MOV	M,E
	INX	H
	MOV	M,D
	DCX	H
	XCHG
	LXI	B,8002h
	;RST	3
	CALL	SET_DMAW
	LDAX	D
	INX	D
	MOV	C,A
	LDAX	D
	INX	D
	ORI	80H
	MOV	B,A
	;RST	3
	CALL	SET_DMAW
RM02:
	POP	B
	POP	D
RM01:
	MVI	A, RECV_MODE
	JMP	SetMode
SwitchSend:
	PUSH	H
	XRA	A ; MVI   A,SEND_MODE
SetMode:
	STA	Mode
	XRA	A
	STA	BUF_SIZE
	LXI	H, BUF
	SHLD	BUF_PTR
	;MVI	C,0
	POP	H
	RET

; Read variable length DMA record - the first packet is 2 bytes length,
; the second - data with previosly transmitted length
DmaReadVariable:
	PUSH	D
	PUSH	B
	LXI	B,4002H
	LXI	D,BUF
	;RST	3
	CALL	SET_DMAW
	LDAX	D
	INX	D
	MOV	C,A
	LDAX	D
	INX	D
	ORI	40H
	MOV	B,A
	CALL	SET_DMAW
	MOV	A,C
	STA	BUF_SIZE
	;CPI	16
	;JNC	$
	;MOV	A,B
	;ANI	3Fh
	;JNZ	$
	XCHG
	SHLD	BUF_PTR
	XCHG
	POP	B
	POP	D
	RET

ELSE ; DMA_SIMPLE
SwitchRecv:
SwitchSend:
	RET
ENDIF

; Set DMA with waiting of the end of transfer
SET_DMAW:
; Program DMA controller
; DE - start address
; BC - packet length with MSB:
;   10 - read cycle (transfer from memory to device)
;   01 - write cycle (thansfer from device to memory)
	DI
	@IN	DMA+0Fh
	INR	A
	JZ	DVT37
	MVI	A,0F4H
	@OUT	DMA+8

	MOV	A,E
	@OUT	DMA
	MOV	A,D
	@OUT	DMA
	DCX	B
	MOV	A,C
	@OUT	DMA+1
	MOV	A,B
	@OUT	DMA+1
	INX	B
	MVI	A,0F5H
	@OUT	DMA+8
WD01:
	LDA	NO_EI
	ORA	A
	JNZ	WAIT_DMA
	EI
WAIT_DMA:
	@IN	DMA+8
	ANI	1
	JZ	WAIT_DMA
	RET
DVT37:
	MOV	A,B
	PUSH	PSW
	ANI	3Fh
	MOV	B,A
	@OUT	DMA+0Ch
	MVI	A,4 ; Stop DMA_CHANNEL 0
	@OUT	DMA+0Ah
	MOV	A,E
	@out	DMA
	MOV	A,D
	@out	DMA
	DCX	B
	MOV	A,C
	@OUT	DMA+1
	MOV	A,B
	@OUT	DMA+1
	INX	B

	POP	PSW
	ANI	0C0H
	RRC
	RRC
	RRC
	RRC
IFNDEF CHANNEL0
	ORI	1
ENDIF
	@OUT	DMA+0Bh
	MVI	A,20h
	@OUT	DMA+8
IFDEF CHANNEL0
	XRA	A
ELSE
	MVI	A,1 ; Start channel 1
ENDIF
	@OUT	DMA+0Ah
	JMP	WD01


IFNDEF DMA_SIMPLE
Mode:		db	RECV_MODE
BUF_PTR:	ds	2
BUF_SIZE:	ds	1
BUF:		ds	32
ELSE
BUF:		ds	2
ENDIF
ENDIF
;.End
