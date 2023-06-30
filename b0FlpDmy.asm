FlpD_I:
	XRA	A
	STA	OLDDSK
	RET
FLSH_WB:
WT_END_CMD:
ChgDrive:
FlpD_R:
FlpD_W:
	RET
; Disk parameters
FLP_TBL::
RecsPerSect:	db	4
MaxSect:	db	9	; Maximum sector number
FullMask:	db	0fh	; Full sector mask
SectShift:	db	2

LAST_OPER:	DB	0
