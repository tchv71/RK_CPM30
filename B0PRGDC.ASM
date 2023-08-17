@SYSREG	MACRO	VAL
	IN	-1
	MVI	A,VAL
	OUT	-1
	ENDM

	LXI	SP,100h

IFNDEF	USE_PRG_DC
	LXI	H,CCP_START + (CPM_BIN - C_BASE)
	MVI	B,63
	CALL	strcpyN
ENDIF

IFDEF	USE_PRG_DC
	@SYSREG	0C0h ; Turn on external device programming mode (for in/out commands)
	LXI	H,BEGPRO+1
	LXI	B,00000h
	MVI	A,15
	CALL	READR
	CALL	LOOP01 ; Turn on working mode

	MVI	A,80H ; Start page
	LXI	D,MAP
	CALL	PROG_DC
ENDIF

	LXI	H,CCP_START + (B_BASE-C_BASE)
	LXI	D, B_BASE
	LXI	B, (BIOS_END-B_BASE)
	CALL	CP001

IFDEF	USE_PRG_DC
IFDEF	EXTERNAL_PORTS
	@SYSREG	0C0h ; Turn on external device programming mode (for in/out commands)

	LXI	H,BEGPRO+1
	LXI	B,400h + PPI
	XRA	A
	CALL	READR

	LXI	B,400h + PPI2
	INR	A
	CALL	READR

	INR	A
	OUT	DISP
	OUT	DISP+1

	LXI	B,1000h + DMA	; DMA
	MVI	A,9
	CALL	READR

	MVI	A,6	; PSG
	LXI	B,400h + PSG1
	CALL	READR

	MVI	A,11
	OUT	PALM_CNTRL

	@SYSREG	80h
ENDIF
ENDIF

	MVI	A,80H
	@out	PALM_CNTRL
	LXI	H,FONT
	MVI	D,0
	CALL	CmdOpenDelete
	ORA	A
	JNZ	ERR_READ

	LXI	D,0D800H
	LXI	H,2048
	CALL	CmdRead
	ORA	A
	JNZ	ERR_READ
	MVI	A,0C0h
	@out	PALM_CNTRL

	MVI	A,0D8h
	LXI	D,MAP2
	CALL	PROG_DC
	LXI	H,CCP_START
	LXI	D, C_BASE
	LXI	B, (B_BASE-C_BASE)
	CALL	CP001
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

ERR_READ:
	@SYSREG	0A0h
	MVI	A,4
	OUT	0E0H
	@SYSREG	80h
	JMP	0E000H

READR:
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


FONT:	DB	'CPM/8X16ENG.FNT',0

MAP:
	DB	58h,10
	DB	8,13
	DB	18h,10
IFDEF	EXTERNAL_PORTS
	DB	8,10
ELSE
	DB	1,6 ;  8253 first
	DB	1,0 ;  8255 first
	DB	1,1 ;  8255 second
	DB	1,2 ;  8275 display adapter
	DB	1,4 ;  8257 DMA chip
	DB	1,11;  Palmira control byte
	DB	2,10;
ENDIF
	DB	0

MAP2:	DB	8,10,0

CCP_START:
