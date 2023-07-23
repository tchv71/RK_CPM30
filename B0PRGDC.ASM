	LXI	SP,100h

	IN	-1
	MVI	A,0C0h
	OUT	-1 ; Turn on external device programming mode (for in/out commands)
	LXI	H,BEGPRO+1
	LXI	B,00000h
	MVI	A,15
	CALL	READR
	CALL	LOOP01 ; Turn on working mode

	MVI	A,80H ; Start page
	LXI	D,MAP
	CALL	PROG_DC


	LXI	H,CCP_START + (B_BASE-C_BASE)
	LXI	D, B_BASE
	LXI	B, (BIOS_END-B_BASE)
CP001:
	MOV	A,M
	STAX	D
	INX	H
	INX	D
	DCX	B
	MOV	A,B
	ORA	C
	JNZ	CP001

IFDEF	EXTERNAL_PORTS
	IN	-1
	MVI	A,0C0h
	OUT	-1 ; Turn on external device programming mode (for in/out commands)

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

	IN	-1
	MVI	A,80h
	OUT	-1
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
	JMP	BOOT

ERR_READ:
	IN	-1
	MVI	A,0A0h
	OUT	-1
	MVI	A,4
	OUT	0E0H
	IN	-1
	MVI	A,80H
	OUT	-1
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
	IN	-1
	MVI	A,0A0H;  ¬ключить режим репрограммировани€
	OUT	-1;     внутренних устройств
	POP	PSW
	LXI H,BEGPRO+1 ; «аписать в hl адрес операнда
		     ; команды out дл€ обеспечени€ инкремента
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
	IN	-1
	MVI	A,80H   ; «аписать в системный регистр-начальные
	OUT	-1      ; значени€: турборежим выключен, нулева€
                    ; страница дополнительного озу
	RET


FONT:	DB	'CPM/8X16ENG.FNT',0

MAP:
	DB	40h,10
	;DB	2,2,2,0,2,1,2,7,2,8,2,10,2,6,2,11
	DB	16,10
	DB	8,10,8,13
	DB	18h,10
IFDEF	EXTERNAL_PORTS
	DB	7,10
	DB	1,8Ah
ELSE
	DB	1,6 ;  8253 first
	DB	1,0 ;  8255 first
	DB	1,1 ;  8255 second
	DB	1,2 ;  8275 display adapter
	DB	1,4 ;  8257 DMA chip
	DB	1,11;  Palmira control byte
	DB	2,10;
	;DB	1,80h+10
;	DB	2,10;  Rest 2 - RAM
ENDIF
	DB	0

MAP2:	DB	8,10,0

CCP_START:
