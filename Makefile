.SUFFIXES: .ASM .REL

.ASM.REL:
	M80 '=$< /I/L'
	
ALL:	CPM.rkl

CPM.REL: CCP.ASM BDOS.ASM B1MAIN.ASM B2DISK.ASM FDCNTR.ASM B1CONIO.ASM B1DISPB.ASM B1LSTAUX.ASM B0FLPDSK.ASM B0RAMDSK.ASM sdbios.asm b0FlpDmy.asm B0SD.ASM b0disk.mac 82xx.mac RK86.MAC SCREEN.MAC E0GETC.ASM B0PRGDC.ASM

CPM.BIN: CPM.REL Makefile
#CCP.REL BDOS.REL B1MAIN.REL B2DISK.REL FDCNTR.REL B1CONIO.REL B1DISPB.REL B1LSTAUX.REL B0FLPDSK.REL B0RAMDSK.REL
#	./L80 CCP,BDOS,B1MAIN,B2DISK,FDCNTR,B1CONIO,B1DISPB,B1LSTAUX,B0FLPDSK,B0RAMDSK,CPM/N/X/E
#	L80 CCP,BDOS,B1MAIN,B2DISK,FDCNTR,B1CONIO,B1DISPB,B1LSTAUX,B0FLPDSK,B0RAMDSK,$@/N/Y/E
	L80 /P:100,$<,$@/N/Y/E
	../m80noi/x64/Release/m80noi.exe CPM.PRN
	../makerk/Release/makerk.exe 100 $@ CPM.rkl
#	../makerk/Release/makerk.exe 91FD $@ CPM.rkl

CPM.rkl: CPM.BIN

clean:
	del *.REL