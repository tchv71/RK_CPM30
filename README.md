# RK_CPM30

CP/M 2.2 bios V3.0 for Palmira with SD-card adapter by Winx.RU

Uses *.FDI files as disk images

All CP/M related files resides in \CPM folder, typical content is:
A.FDI - disk A:
B.FDI - disk B:
8x16eng.FNT - file with 7-bit ASCII font
CPM.rkl - executable CP/M binary image

Sources for M80 macro assembler

BDOS.ASM and CCP.ASM is disassembled, original sources are found here: 
https://github.com/brouhaha/cpm22

Makefile is for compilation on PC (using M80 and L80 wrappers from here: https://github.com/Konamiman/M80dotNet)

Console:
F1 changes code page from 7-bit ASCII to KOI7 and vice versa
