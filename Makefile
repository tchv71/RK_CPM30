.SUFFIXES: .ASM .REL .BIN
PORT=COM2:
ASMDEP=Cpm.ASM CCP.ASM BDOS.ASM B1MAIN.ASM B2DISK.ASM FDCNTR.ASM B1CONIO.ASM B1DISPB.ASM B1LSTAUX.ASM B0FLPDSK.ASM B0RAMDSK.ASM sdbios.asm b0FlpDmy.asm B0SD.ASM b0disk.mac RK86.MAC SCREEN.MAC E0GETC.ASM B0PRGDC.ASM RkConfig.mac DEBLOCK.ASM
M80PATH=D:/M80


ALL:	CPM/CPM.rkl CPM/CPM_P.rkl

CPM6.REL: $(ASMDEP)
	$(M80PATH)/M80 '$@=Cpm.ASM /I/L'

CPMP.REL: $(ASMDEP)
	$(M80PATH)/M80 '$@=Cpm.ASM /I/L'

CPMPC.REL: $(ASMDEP)
	$(M80PATH)/M80 '$@=Cpm.ASM /I/L'


_palmira: RkConfigPalmira.mac
	copy /y RkConfigPalmira.mac RkConfig.mac
	copy /y RkConfigPalmira.mac _palmira
# touch equivalent
	copy /b RkConfig.mac +,,
	copy /b RkConfig60k.mac +,,
	copy /b RkConfigPalmiraCPM.mac +,,

_palmiraCPM: RkConfigPalmiraCPM.mac
	copy /y RkConfigPalmiraCPM.mac RkConfig.mac
	copy /y RkConfigPalmiraCPM.mac _palmiraCPM
# touch equivalent
	copy /b RkConfig.mac +,,
	copy /b RkConfig60k.mac +,,
	copy /b RkConfigPalmira.mac +,,

_Rk60k: RkConfig60k.mac
	copy /y RkConfig60k.mac RkConfig.mac
	copy /y RkConfig60k.mac _Rk60k
# touch equivalent
	copy /b RkConfig.mac +,,
	copy /b RkConfigPalmiraCPM.mac +,,
	copy /b RkConfigPalmira.mac +,,

CPM/CPM.rkl: _palmiraCPM CPMPC.BIN
	../makerk/Release/makerk.exe 100 CPMPC.BIN $@

CPM/CPM_P.rkl: _palmira CPMP.BIN
	../makerk/Release/makerk.exe 100 CPMP.BIN $@

CPM/CPM60K.rk: _Rk60k CPM6.BIN
	../makerk/Release/makerk.exe 100 CPM6.BIN $@

.REL.BIN:
	$(M80PATH)/L80 /P:100,$<,$@/N/Y/E

clean:
	del *.REL

send: $(SENDPATH)
	MODE $(PORT) baud=115200 parity=N data=8 stop=1
	cmd /C copy /B $< $(PORT)
