; TMS9918 definitions

T_0_MODE_GRAPHICS_I	EQU	0
T_1_MODE_GRAPHICS_II	EQU	1
T_2_MODE_TEXT		EQU	2
T_3_MODE_MULTICOLOR	EQU	3


T_TRANSPARENT		EQU	0
T_BLACK			EQU	1
T_MED_GREEN		EQU	2
T_LT_GREEN		EQU	3
T_DK_BLUE		EQU	4
T_LT_BLUE		EQU	5
T_DK_RED		EQU	6
T_CYAN			EQU	7
T_MED_RED		EQU	8
T_LT_RED		EQU	9
T_DK_YELLOW		EQU	10
T_LT_YELLOW		EQU	11
T_DK_GREEN		EQU	12
T_MAGENTA		EQU	13
T_GREY			EQU	14
T_WHITE			EQU	15

T_REG_0			EQU	0
T_REG_1			EQU	1
T_REG_2			EQU	2
T_REG_3			EQU	3
T_REG_4			EQU	4
T_REG_5			EQU	5
T_REG_6			EQU	6
T_REG_7			EQU	7
T_NUM_REGISTERS		EQU	8
T_REG_NAME_TABLE	EQU	T_REG_2
T_REG_COLOR_TABLE	EQU	T_REG_3
T_REG_PATTERN_TABLE	EQU	T_REG_4
T_REG_SPRITE_ATTR_TABLE	EQU	T_REG_5
T_REG_SPRITE_PATT_TABLE	EQU	T_REG_6
T_REG_FG_BG_COLOR	EQU	T_REG_7

T_R0_MODE_GR_I		EQU	00
T_R0_MODE_GR_II		EQU	02
T_R0_MODE_MULTICOLOR	EQU	00
T_R0_MODE_TEXT		EQU	00
T_R0_MODE_TEXT80	EQU	04
T_R0_MODE_TEXT8_80	EQU	80h
T_R0_EXT_VDP_ENABLE	EQU	01
T_R0_EXT_VDP_DISABLE	EQU	00

T_R1_RAM_16K		EQU	80h
T_R1_RAM_4K		EQU	00
T_R1_DISP_BLANK		EQU	00
T_R1_DISP_ACTIVE	EQU	40h
T_R1_INT_ENABLE		EQU	20h
T_R1_INT_DISABLE	EQU	00
T_R1_MODE_GRAPHICS_I	EQU	00
T_R1_MODE_GRAPHICS_II	EQU	00
T_R1_MODE_MULTICOLOR	EQU	08
T_R1_MODE_TEXT		EQU	10h
T_R1_SPR_8		EQU	00
T_R1_SPR_16		EQU	02
T_R1_SPR_MAG1		EQU	00
T_R1_SPR_MAG2		EQU	01

T_DEF_VRAM_NAME_ADDRESS		EQU	3800h
T_DEF_VRAM_COLOR_ADDRESS	EQU	0000
T_DEF_VRAM_PATT_ADDRESS		EQU	2000h
T_DEF_VRAM_SPR_ATTR_ADDRESS	EQU	3B00h
T_DEF_VRAM_SPR_PATT_ADDRESS	EQU	1800h

T_T80_VRAM_COLOR_ADDRESS	EQU	0A00h
T_T80_VRAM_NAME_ADDRESS		EQU	0000h
T_T80_VRAM_PATT_ADDRESS		EQU	2000h
T_T80_VRAM_ATTR_ADDRESS		EQU	3000h


VDP	EQU	98H

; reset registers and clear all 16KB of video memory
T_Reset:
	; blank the screen with 16KB enabled
	MVI	B, T_REG_1
	MVI	C, T_R1_RAM_16K
	CALL	T_WriteRegValue

	MVI	B, T_REG_0
	MVI	C, 0
	CALL	T_WriteRegValue

	MVI	B, T_REG_FG_BG_COLOR
	MVI	C, T_TRANSPARENT OR (T_TRANSPARENT SHL 4)
	CALL	T_WriteRegValue

	LXI	D, 0                   ; clear entire VRAM
	LXI	B, 4000h
	XRA	A
	;JMP	T_Fill ; fallthrough


TmsWait	EQU 10

; A - byte to fill
; DE - VRAM address
; BC - byte count
T_Fill:
	PUSH	B
	MOV	B,D
	MOV	C,E
	MOV	E,A
	CALL	T_SetAddrWrite
	POP	B
T_Fill01:
	MOV	A,E
	OUT	VDP
	DCX	B
	MOV	A,B
	ORA	C
	JNZ	T_Fill01
	RET

; HL - 2 bytes to fill
; DE - VRAM address
; BC - word count
T_FillHL:
	PUSH	B
	MOV	B,D
	MOV	C,E
	;MOV	E,A
	CALL	T_SetAddrWrite
	POP	B
T_Fill02:
	MOV	A,H
	OUT	VDP
	MOV	A,L
	OUT	VDP
	DCX	B
	MOV	A,B
	ORA	C
	JNZ	T_Fill02
	RET
; HL - buffer in RAm
; DE - byte count
T_WriteBytes:
	MOV	A,M
	OUT	VDP
	INX	H
	DCX	D
	MOV	A,D
	ORA	E
	JNZ	T_WriteBytes
	RET

; HL - buffer in RAM
; DE - VRAM address
; B - byte count
T_ShAddrWriteBytes:
	PUSH	B
	MOV	B,D
	MOV	C,E
	CALL	T_SetAddrWrite
	POP	B

T_ShortWriteBytes:
	MOV	A,M
	OUT	VDP
	INX	H
	DCR	B
	JNZ	T_ShortWriteBytes
	RET

; HL - buffer in RAM
; DE - byte count
T_ReadBytes:
	IN	VDP
	MOV	M,A
	INX	H
	DCX	D
	MOV	A,D
	ORA	E
	JNZ	T_ReadBytes
	RET

; HL - RAM buffer address
; DE - VRAM address to read
; B - byte count
T_ShAddrReadBytes:
	PUSH	H
	PUSH	B
	XCHG
	CALL	T_SetAddrReadHL
	XCHG
T_ShortReadBytes:
	IN	VDP
	MOV	M,A
	INX	H
	DCR	B
	JNZ	T_ShortReadBytes
	POP	B
	POP	H
	RET

T_ReadStatus:
	IN	VDP+1
	RET

; C - value
; B - reg
T_WriteRegValue:
	;CALL	T_WriteAddr
	DI
	MOV	A,C
	OUT	VDP+1
	MOV	A,B
	ORI	80H
	OUT	VDP+1
	JMP	RET_SET_EI

; HL - address to write
T_SetAddrWriteHL:
	DI
	MOV	A,L
	OUT	VDP+1
	MOV	A,H
	ORI	40H
	OUT	VDP+1
	JMP	RET_SET_EI

; HL - address to read
T_SetAddrReadHL:
	DI
	MOV	A,L
	OUT	VDP+1
	MOV	A,H
	OUT	VDP+1
	JMP	RET_SET_EI

; set the address to place text at X/Y coordinate
;	H = X
;	L = Y
T_TextPos:
	MOV	E,H
	MOV	A,L
	MVI	D, 0
	MOV	H,D
	MOV	L,D
	DAD	D                       ; Y x 1
	DAD	H                       ; Y x 2
	DAD	H                       ; Y x 4
	DAD	D                       ; Y x 5
	DAD	H                       ; Y x 10
	DAD	H                       ; Y x 20
	DAD	H                       ; Y x 40
	DAD	H                       ; Y x 80
	MOV	E,A
	DAD	D                       ; add X for final address
	LXI	D, T_T80_VRAM_NAME_ADDRESS       ; add name table base address
	DAD	D
	MOV	B,H
	MOV	C,L

; BC - address to write
T_SetAddrWrite:
	MOV	A,B
	ORI	40h
	MOV	B,A
; BC - address to read
T_SetAddrRead:
	DI
	MOV	A,C
	OUT	VDP+1
	MOV	A,B
	OUT	VDP+1
	JMP	RET_SET_EI

T_WriteData:
	MOV	A,C
	OUT	VDP
	RET

; copy a null-terminated string to VRAM
;	HL = ram source address
T_StrOut:
	MOV	A, M
	ORA	A
	RZ				; return when NULL is encountered
	OUT	VDP
	INX	H
	JMP	T_StrOut


T_InitialiseText80:
	;CALL	T_Reset
	PUSH	PSW


; non-bitmap color and pattern table configuration
	MVI	B, T_REG_COLOR_TABLE
	MVI	C, T_T80_VRAM_COLOR_ADDRESS / 40h
	CALL	T_WriteRegValue

	; set up pattern table address (register = address / 800H)
	MVI	B, T_REG_PATTERN_TABLE
	MVI	C, T_T80_VRAM_PATT_ADDRESS / 800h
	CALL	T_WriteRegValue

	; set up name table address (register = address / 400H)
	MVI	B, T_REG_NAME_TABLE
	MVI	C, (T_T80_VRAM_NAME_ADDRESS / 400h) AND 0fh;7Ch OR 3 
	CALL	T_WriteRegValue

	LXI	B, T_T80_VRAM_PATT_ADDRESS ; load font from address in bc
	CALL	T_SetAddrWrite

	POP	PSW
	CPI	80H
	JZ	font16
	LXI	H, tmsFont8
	LXI	D, tmsFont8End - tmsFont8
	CALL	T_WriteBytes

	LXI	B, (T_REG_0 SHL 8) OR T_R0_EXT_VDP_DISABLE OR T_R0_MODE_TEXT80
	CALL	T_WriteRegValue
	JMP	Reg0Ok

font16:
	LXI	H, tmsFont
	LXI	D, tmsFontEnd - tmsFont ; tmsFontBytes
	CALL	T_WriteBytes

	LXI	B, (T_REG_0 SHL 8) OR T_R0_EXT_VDP_DISABLE OR T_R0_MODE_TEXT80 OR T_R0_MODE_TEXT8_80
	CALL	T_WriteRegValue

reg0ok:
	LXI	B, (T_REG_1 SHL 8) OR T_R1_MODE_TEXT OR T_R1_DISP_ACTIVE OR T_R1_INT_ENABLE
	CALL	T_WriteRegValue

	LXI	B, (T_REG_FG_BG_COLOR SHL 8) OR T_DK_BLUE OR (T_WHITE SHL 4)
	JMP	T_WriteRegValue

