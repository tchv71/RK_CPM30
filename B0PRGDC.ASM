@SYSREG	MACRO	VAL
	IN	-1
	MVI	A,VAL
	OUT	-1
	ENDM

TICK_COUNTER	EQU	38h+3

	LXI	SP,100h
	DI
	.z80
	im	1
	.8080
	LXI	H,0
	SHLD	TICK_COUNTER
	SHLD	TICK_COUNTER+2
IFDEF	RK60K
	LXI	H,CCP_START + (CPM_BIN - C_BASE)
	MVI	B,63
	CALL	strcpyN
ENDIF

IFDEF	USE_PRG_DC
IF 0
	@SYSREG	0C0h ; Turn on external device programming mode (for in/out commands)
	LXI	H,BEGPRO+1
	LXI	B,00000h
	MVI	A,15
	CALL	SETPORT
	CALL	LOOP01 ; Turn on working mode
ENDIF
	MVI	A,0;80H ; Start page
	LXI	D,MAP
	CALL	PROG_DC
ENDIF
	;@SYSREG	80h
	LXI	H,CCP_START + (B_BASE-C_BASE)
	LXI	D, B_BASE
	LXI	B, (BIOS_END-B_BASE)
	CALL	CP001
	MVI	A,1
	STA	NO_EI
IFNDEF VDP9918
	CALL	CLS
ENDIF
IFDEF	USE_PRG_DC
IFDEF	EXTERNAL_PORTS
	@SYSREG	0C0h ; Turn on external device programming mode (for in/out commands)

	LXI	H,BEGPRO+1
	LXI	D, MAP_PORTS
PORT_MAP:
	LDAX	D
	MOV	C,A
	INX	D
	LDAX	D
	ORA	A
	JZ	END_PORT_MAP
	MOV	B,A
	INX	D
	LDAX	D
	INX	D
	CALL	SETPORT
	JMP	PORT_MAP

END_PORT_MAP:
	@SYSREG	80h

ENDIF
ENDIF
	CALL	CLS
	CALL	SETSCR
	LXI	H,CCP_START
	LXI	D, C_BASE
	LXI	B, (B_BASE-C_BASE)
	CALL	CP001
	MVI	A,8AH
	@out	PPI+3
	JMP	BOOT

CP001:
	MOV	A,B
	ORA	C
	RZ
	MOV	A,M
	STAX	D
	INX	H
	INX	D
	DCX	B
	JMP	CP001


IFDEF	USE_PRG_DC
; A - value
; C - port number
; B - count
SETPORT:
	MOV	M,C
BEGPRO:
	OUT 0
	INR M
	DCR B
	RZ
	JMP BEGPRO

PROG_DC:
	PUSH	PSW
	@SYSREG	0A0H;  Включить режим репрограммирования  внутренних устройств
	POP	PSW
	LXI H,BEGPRO+1 ; Записать в hl адрес операнда
		     ; команды out для обеспечения инкремента
		     ; начинаем с out 80H
	MOV	M,A
LOOP:
	LDAX	D
	ORA	A
	JZ	LOOP01
	MOV	B,A
	INX	D
	LDAX	D
	INX	D
	CALL	BEGPRO
	JMP	LOOP
LOOP01:
	@SYSREG	80H	; Записать в системный регистр-начальные
			; значения: турборежим выключен, нулевая
			; страница дополнительного озу
	RET
ENDIF

strcpyN:
	LDAX	D
	INX	D
	MOV	M, A
	INX	H
	ORA	A
	RZ
	DCR	B
	JNZ	strcpyN
	MVI	M, 0 ; Терминатор
	RET


IFDEF	USE_PRG_DC
MAP:
	DB	40h,MEM_LO
	DB	40h,MEM_LO+10h
	DB	40h,MEM_HI
	DB	38h,MEM_HI+10h
IFDEF	EXTERNAL_PORTS
	DB	8,MEM_HI+10h
ELSE
	DB	1,6 ;  8253 first
	DB	1,0 ;  8255 first
	DB	1,1 ;  8255 second
	DB	1,2 ;  8275 display adapter
	DB	1,7 ;  8257 DMA chip
	DB	1,11;  Palmira control byte
	DB	2,1dh;
ENDIF

MAP_PORTS:
	DB	PPI,  4, 0
	DB	PPI2, 4, 1
	DB	DISP, 2, 2
	DB	DMA,  10h, 7
	DB	PSG1, 4, 6
	DB	PSG2, 4, 8
	DB	PALM_CNTRL, 1, 11
	DB	VDP, 2, 14
	DB	FT245R, 2, 12
	DB	0, 0
ENDIF
CCP_START:
