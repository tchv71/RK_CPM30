; *****	B1DISPB.ASM - Display parameter block *********

;INCLUDE A:SCREEN.MAC

S	equ	0b	; All/Odd lines to display    (0/1)
VV	equ	00b	; Frame reverse time:   00 - 1 T_Row
;						01 - 2 T_Row
;						02 - 3 T_Row
;						03 - 4 T_Row
UUUU	equ	10-1	; Cursor scan line number     (1..16)
LLLL	equ	10-1	; Number of scan lines/symbol (1..16)
@M	equ	1	; Count lines 0 -  from 0  ; 1 - from 1
@F	equ	1	; Display ctrl symbols : 0 - as space
CC	equ	01	; Cursor style 		      (0..3)
;						 1 - no display
ZZZZ	equ	0dh	; Horizontal RVV time

Disp_PB::	db	S*128+PHYS_W-1
		db	VV*64+PHYS_H-1	; Display parameters
		db	UUUU*16+LLLL
		db	@M*128+@F*64+CC*16+ZZZZ
		dw	SCR_BUFF,PHYS_W*PHYS_H-1; DMA parameters
;		END

		