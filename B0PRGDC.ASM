	LXI	SP,100h

	MVI	A,80H ; Start page
	LXI	D,MAP
	CALL	PROG_DC

	MVI	A,80H
	STA	PALM_CNTRL
	LXI	H,FONT
	MVI	D,0
	CALL	CmdOpenDelete
	LXI	D,0D800H
	LXI	H,2048
	CALL	CmdRead
	JNZ	ERR_READ
	MVI	A,0C0h
	STA	PALM_CNTRL

	MVI	A,0D8h
	LXI	D,MAP2
	CALL	PROG_DC

	LXI	H,CCP_START + C_SIZE + D_SIZE
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
	JMP	BOOT

ERR_READ:
	MVI	A,0A0h
	OUT	-1
	MVI	A,4
	OUT	0E0H
	MVI	A,80H
	OUT	-1
	JMP	0E000H

BEGPRO:
	OUT 0
	INR M
	DCR B
	RZ
	JMP BEGPRO

PROG_DC:
	PUSH	PSW
	MVI A,0A4H;  Включить режим репрограммирования
	OUT -1;     внутренних устройств
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
	MVI A,84H   ; Включить рабочий режим
	OUT -1
	MVI A,80H   ; Записать в системный регистр-начальные
	OUT -1      ; значения: турборежим выключен, нулевая
                    ; страница дополнительного озу
	RET


FONT:	DB	'CPM/8X16ENG.FNT',0

MAP:
	DB	40h,10
	;DB	2,2,2,0,2,1,2,7,2,8,2,10,2,6,2,11
	DB	16,10
	DB	8,10,8,13
	DB	18h,10
	DB	1,6 ;  8253 first
	DB	1,0 ;  8255 first
	DB	1,1 ;  8255 second
	DB	1,2 ;  8275 display adapter
	DB	1,4 ;  8257 DMA chip
	DB	1,11;  Palmira control byte
;	DB	2,10;  Rest 2 - RAM
	DB	0

MAP2:	DB	8,10,0

CCP_START:
