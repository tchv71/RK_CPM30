; SD BIOS for Computer "Radio 86RK"
; (c) 09-10-2014 vinxru (aleksey.f.morozov@gmail.com)

     ;.org 07600h-683 ; Последний байт кода должен быть 075FFh
                       
;----------------------------------------------------------------------------
; Использовать DMA для обмена с SD-картой (требует специальной прошивки контроллера)
USE_DMA         EQU 1
;INIT_VIDEO      EQU SETSCR;0F82DH
USER_PORT       EQU PPI2    ; Адрес КР580ВВ55
;INIT_STACK      EQU 0B6CFh
IFNDEF USE_DMA
SEND_MODE       EQU 10000000b ; Режим передачи (1 0 0 A СH 0 B CL)
RECV_MODE       EQU 10010000b ; Режим приема (1 0 0 A СH 0 B CL)
ENDIF

STA_START       EQU 040h ; МК переключен в режим приема команд
STA_WAIT        EQU 041h ; МК выполняет команду
STA_OK_DISK     EQU 042h ; Накопитель исправен, микроконтроллер готов к приему команды
STA_OK_CMD      EQU 043h ; Команда выполнена
STA_OK_READ     EQU 044h ; МК готов передать следующий блок данных
STA_OK_ENTRY    EQU 045h ; MK готов передать запись о файле
STA_OK_WRITE	EQU 046h ; MK ждет следующий блок для записи
STA_OK_ADDR     EQU 047h ; МК готов передать адрес загрузки
STA_OK_BLOCK    EQU 04Fh 

ERR_DATETIME    EQU 50H
;VER_BUF         EQU  BUF

; IN and OUT MACRO comands
@in	MACRO	addr
IF ((addr) LT 256)
        in	addr
ELSE
        lda	addr
ENDIF
        ENDM

@out	MACRO	addr
IF ((addr) LT 256)
        out	addr
ELSE
        sta	addr
ENDIF
        ENDM

;----------------------------------------------------------------------------
; Заголовок RK файла

     ;db ($+2)>>8, ($+2)&0FFh
     
;----------------------------------------------------------------------------
	      
;Entry:
;     ; Устанавливаем границу свободной памяти
;     LXI	H, SELF_NAME
;     CALL	0F833h
;
;     ; Вывод названия контроллера на экран
;     LXI	H, aHello
;     CALL	0F818h
;
;     ; Вывод версии контроллера
;     CALL	PrintVer
;
;     ; Перевод строки
;     lxi	h, aCrLf
;     CALL	0F818h
;
;     ; Запускаем файл SHELL.RK без ком строки
;     LXI	H, aShellRk
;     LXI	D, aEmpty
;     CALL	CmdExec
;     PUSH	PSW
;
;     ; Ошибка - файл не найден
;     CPI	04h
;     JNZ 	Error2
;
;     ; Вывод сообщения "ФАЙЛ НЕ НАЙДЕН BOOT/SHELL.RK"
;     LXI	H, aErrorShellRk
;     CALL	0F818h
;     JMP	$
;
;;----------------------------------------------------------------------------
;
;PrintVer:
;     ; Команда получения версии
;     MVI	A, 1
;     CALL	StartCommand	; Лишний такт в котором пропустим версию
;     CALL	SwitchRecv
;     
;     ; Получаем версию набора команд и текст
;     LXI	B, VER_BUF
;     LXI	D, 18          ; 1 ый байт версия, последний байт - отпускаем шину
;     CALL	RecvBlock
;          
;     ; Вывод версии железа
;     XRA	A
;     STA	VER_BUF+17
;     LXI	H, VER_BUF+1
;     JMP 	0F818h
;
;;----------------------------------------------------------------------------
;
;aHello:         db 13,10,"SD BIOS V1.0",13,10
;aSdController:  db "SD CONTROLLER ",0
;aCrLf:          db 13,10,0
;aErrorShellRk:  db "fajl ne najden "
;aShellRk:       db "BOOT/SHELL.RK",0
;                db "(c) 04-05-2014 vinxru"
;
;; Код ниже будет затерт ком строкой и собственым именем
;
;SELF_NAME    EQU $-512 ; путь (буфер 256 байт)
;CMD_LINE     EQU  $-256 ; команданая строка 256 байт
;
;;----------------------------------------------------------------------------
;; РЕЗИДЕНТНАЯ ЧАСТЬ SD BIOS
;;----------------------------------------------------------------------------
;
;aError:    db "o{ibka SD "
;aEmpty:    db 0

;----------------------------------------------------------------------------
; Тут восстанавливается то, что можно быть испорчено при сбое

;Error:     
;     ; Инициализация стека
;     LXI	SP, INIT_STACK
;
;     ; Сохраняем код ошибки
;     PUSH	PSW
;
;     ; Очистка экрана
;     ; Сначала надо удалить из области экрана все спец символы, а то синхра сбивается
;     MVI	C, 1Fh
;     CALL	0F809h     
;     ; А теперь перезагрузить видеоконтроллер
;     CALL       INIT_VIDEO
;
;Error2:
;     ; Вывод текста "ОШИБКА SD "
;     LXI	H, aError
;     CALL	0F818h
;
;     ; Вывод кода ошибки
;     POP	PSW
;     CALL	0F815h
;
;     ; Виснем
;     JMP	$

;----------------------------------------------------------------------------

;BiosEntry:
;     PUSH       H
;     LXI	H, JmpTbl
;     ADD	L
;     MOV	L, A
;     MOV	L, M
;     XTHL
;     RET

;----------------------------------------------------------------------------
; Страница 8D00. Все переходы JmpTbl в пределах одной страницы

;JmpTbl:
;     dw 0;CmdExec           ; 0 HL-имя файла, DE-командная строка  / A-код ошибки
;     dw 0;CmdFind           ; 1 HL-имя файла, DE-максимум файлов для загрузки, BC-адрес / HL-сколько загрузили, A-код ошибки
;     dw CmdOpenDelete       ; 2 D-режим, HL-имя файла / A-код ошибки
;     dw CmdSeekGetSize      ; 3 B-режим, DE:HL-позиция / A-код ошибки, DE:HL-позиция
;     dw CmdRead             ; 4 HL-размер, DE-адрес / HL-сколько загрузили, A-код ошибки
;     dw CmdWrite            ; 5 HL-размер, DE-адрес / A-код ошибки
;     dw 0;CmdMove           ; 6 HL-из, DE-в / A-код ошибки

;----------------------------------------------------------------------------
; HL-путь, DE-максимум файлов для загрузки, BC-адрес / HL-сколько загрузили, A-код ошибки

;CmdFind:
;     ; Код команды
;     MVI	A, 3
;     CALL	StartCommand
;
;     ; Путь
;     CALL	SendString
;
;     ; Максимум файлов
;     XCHG
;     CALL	SendWord
;
;     ; Переключаемся в режим приема
;     CALL	SwitchRecv
;
;     ; Счетчик
;     LXI	H, 0
;
;CmdFindLoop:
;     ; Ждем пока МК прочитает
;     CALL	WaitForReady
;     CPI	ERR_OK
;     JZ		Ret0
;     CPI	ERR_OK_ENTRY
;     JNZ	EndCommand
;
;     ; Прием блока данных
;     LXI	D, 20	; Длина блока
;     CALL	RecvBlock
;
;     ; Увеличиваем счетчик файлов
;     INX	H
;
;     ; Цикл
;     JMP	CmdFindLoop

;----------------------------------------------------------------------------
; D-режим, HL-имя файла / A-код ошибки

CmdOpenDelete: 
     ; Код команды
     MVI	A, 4
     CALL	StartCommand

     ; Режим
     MOV	A, D
     CALL	Send

     ; Имя файла
     CALL	SendString

     ; Ждем пока МК сообразит
     CALL	SwitchRecvAndWait
     CPI	STA_OK_CMD
     JZ		Ret0
IFDEF USE_DMA
     ret
ELSE
     JMP	EndCommand
ENDIF
;----------------------------------------------------------------------------
; B-режим, DE:HL-позиция / A-код ошибки, DE:HL-позиция

CmdSeekGetSize:
     ; Код команды
     MVI 	A, 5
     CALL	StartCommand

     ; Режим     
     MOV	A, B
     CALL	Send

     ; Позиция     
     CALL	SendWord
     XCHG
     CALL	SendWord

   ; Ждем пока МК сообразит. МК должен ответить кодом STA_OK_CMD
     CALL	SwitchRecvAndWait
     CPI	STA_OK_CMD
IFDEF USE_DMA
     RNZ
ELSE
     JNZ	EndCommand
ENDIF
     ; Длина файла
     CALL	RecvWord
     XCHG
     CALL	RecvWord

     ; Результат
     JMP	Ret0
     
;----------------------------------------------------------------------------
; HL-размер, DE-адрес / HL-сколько загрузили, A-код ошибки

CmdRead:
     ; Код команды
     MVI	A, 6
     CALL	StartCommand

     ; Адрес в BC
     MOV	B, D
     MOV	C, E

     ; Размер блока
     CALL	SendWord        ; HL-размер

     ; Переключаемся в режим приема
     CALL	SwitchRecv

     ; Прием блока. На входе адрес BC, принятая длина в HL
IFDEF USE_DMA
;----------------------------------------------------------------------------
; Загрузка данных по адресу BC. 
; На выходе HL сколько загрузили
; Портим A
; Если загружено без ошибок, на выходе Z=1

RecvBuf:
     LXI	H, 0
RecvBuf0:   
     ; Подождать
     CALL	WaitForReady
     CPI	STA_OK_READ
     JZ		Ret0		; на выходе Z (нет ошибки)
     CPI    STA_OK_BLOCK
     RNZ;	EndCommand	; на выходе NZ (ошибка)

     ; Размер загруженных данных в DE
     CALL	RecvWord

     ; В HL общий размер
     DAD D

     ;CALL       ReceiveBufferIfEmpty
     ; Принять DE байт по адресу BC
     CALL	RecvBlock

     JMP	RecvBuf0
ELSE
     JMP	RecvBuf
ENDIF
;----------------------------------------------------------------------------
; HL-размер, DE-адрес / A-код ошибки

CmdWrite:
     ; Код команды
     MVI	A, 7
     CALL	StartCommand
     
     ; Размер блока
     CALL	SendWord        ; HL-размер

     ; Теперь адрес в HL
     XCHG
IFDEF USE_DMA
     MOV    B,H
     MOV    C,L
ENDIF
CmdWriteFile2:
    ; Результат выполнения команды
     CALL	SwitchRecvAndWait
     CPI  	STA_OK_CMD
     JZ  	Ret0
     CPI  	STA_OK_WRITE
IFDEF USE_DMA
     RNZ
ELSE
     JNZ	EndCommand
ENDIF

     ; Размер блока, который может принять МК в DE
     CALL       RecvWord

     ; Переключаемся в режим передачи    
     CALL       SwitchSend

     ; Передача блока. Адрес BC длина DE.
CmdWriteFile1:
IFDEF USE_DMA
     CALL       SendBlock
ELSE
;CmdWriteFile1:
;     MOV	A, M
;     INX	H
;     CALL	Send
;     DCX	D
;     MOV	A, D
;     ORA	E
;     JNZ 	CmdWriteFile1
     MOV        B,H
     MOV        C,L
IFDEF  	USE_PRG_DC
     @SYSREG    0A0H
     MVI        A,1
     OUT        PPI_PG
     @SYSREG    80H
     LXI        H, PPI_PG*256+1
ELSE
     LXI 	H, USER_PORT+1
ENDIF
     ANA        A
     MOV        A,D
     RAR
     MOV        D,A
     MOV        A,E
     RAR
     MOV        E,A
     INR 	D
     XRA 	A
     ORA 	E
     JZ 	SendBlock2

SendBlock1:
     REPT        2
     LDAX        B
  IFDEF  	USE_PRG_DC
     STA        PPI_PG*256              ; 13
  ELSE
     STA        USER_PORT               ; 13
  ENDIF
     INX         B                      ; 5
     MVI         M, 20h			; 10
     MVI         M, 0			; 10
     ENDM
     DCR	E		        ; 5
     JNZ	SendBlock1		; 10 = 66
SendBlock2:
     DCR	D
     JNZ	SendBlock1
IFDEF  	USE_PRG_DC
     @SYSREG    0A0H
     MVI        A,MEM_HI+10h
     OUT        PPI_PG
     @SYSREG    80H
ENDIF
     MOV        H,B
     MOV        L,C
ENDIF
     JMP	CmdWriteFile2
;--------------------------------------------------------------------------------
CmdGetDate:
     MVI        A,2Ah
     call       StartCommand

     call       SwitchRecvAndWait
     stax       d ; WeekDay
     inx        d
     call       Recv
     stax       d ; Month
     inx        d
     call       Recv
     stax       d ; Date (1...31)
     inx        d
     call       Recv
     stax       d
     call       Recv
EndDateCmd:
     push       psw
     call       SwitchSend
     mvi        a,STA_OK_CMD
     call       Send
     pop        psw

     cpi        STA_OK_CMD
     jz         ret0
IFDEF USE_DMA
     RET
ELSE
     jmp        EndCommand
ENDIF

CmdSetDate:
     mvi        a,2Bh
     call       StartCommand

     mvi        a,2 ; WeekDay todo: need to compute from Day,Month,Year
     inx        d
     call       Send
     ldax       d ; Month
     inx        d
     call       Send
     ldax       d ; Day
     inx        d
     call       Send
     ldax       d ; Year
     call       Send
     call       SwitchRecvAndWait
     jmp        EndDateCmd

CmdGetTime:
     mvi        A,2Ch
     call       StartCommand

     call       SwitchRecvAndWait
     stax       d ; Hours (0...23)
     inx        d
     call       Recv
     stax       d ; Minutes (0...59)
     inx        d
     call       Recv
     stax       d ; Seconds (0...59)
     inx        d
     call       Recv
     call       Recv
     jmp        EndDateCmd

CmdSetTime:
     mvi        a,2Dh
     call       StartCommand

     ldax       d ; Hours (0...23)
     inx        d
     call       Send
     ldax       d ; Minutes (0...59)
     inx        d
     call       Send
     ldax       d ; Seconds (0...59)
     inx        d
     call       Send
     mvi        a,100 ; SecondFraction
     call       Send
     xra        a ; SubSeconds
     call       Send
     call       SwitchRecvAndWait
     jmp        EndDateCmd

;----------------------------------------------------------------------------
; HL-из, DE-в / A-код ошибки

;CmdMove:     
;     ; Код команды
;     MVI	A, 8
;     CALL	StartCommand
;
;     ; Имя файла
;     CALL	SendString
;
;     ; Ждем пока МК сообразит
;     CALL	SwitchRecvAndWait
;     CPI	ERR_OK_WRITE
;     JNZ	EndCommand
;
;     ; Переключаемся в режим передачи
;     CALL	SwitchSend
;
;     ; Имя файла
;     XCHG
;     CALL	SendString

;WaitEnd:
;     ; Ждем пока МК сообразит
;     CALL	SwitchRecvAndWait
;     CPI	ERR_OK
;     JZ		Ret0
;     JMP	EndCommand

;----------------------------------------------------------------------------
; HL-имя файла, DE-командная строка / A-код ошибки

;CmdExec:
;     ; Код команды
;     MVI	A, 2
;     CALL	StartCommand
;
;     ; Имя файла
;     PUSH	H
;     CALL	SendString
;     POP	H
;
;     ; Ждем пока МК прочитает файл
;     ; МК должен ответить кодом ERR_OK_ADDR
;     CALL	SwitchRecvAndWait
;     CPI	ERR_OK_ADDR
;     JNZ	EndCommand
;
;     ; Сохраняем имя файла (HL-строка)
;     PUSH	D
;     XCHG
;     LXI	H, SELF_NAME
;     CALL	strcpy255
;     POP	D
;
;     ; Сохраняем командную строку (DE-строка)
;     LXI	H, CMD_LINE
;     CALL	strcpy255
;
;     ; *** Это точка невозврата. Любая ошибка приведет к перезагрузке. ***
;
;     ; Инициализация стека (аналогично стандартному монитору)
;     LXI	SP, INIT_STACK
;
;     ; Принимаем адрес загрузки в BC и сохраняем его в стек
;     CALL	RecvWord
;     PUSH	D
;     MOV 	B, D
;     MOV 	C, E
;
;     ; Загружаем файл
;     CALL	RecvBuf
;     JNZ 	Error
;
;     ; Очистка экрана
;     ; Сначала надо удалить из области экрана все спец символы, а то синхра сбивается
;     MVI	C, 1Fh
;     CALL	0F809h     
;     ; А теперь перезагрузить видеоконтроллер
;     CALL       INIT_VIDEO
;
;     ; Настройки для программы
;     MVI  A, 1		; Версия контроллера
;     LXI  B, BiosEntry  ; Точка входа SD BIOS
;     LXI  D, SELF_NAME  ; Собственное имя
;     LXI  H, CMD_LINE   ; Командная строка
;
;     ; Запуск загруженной программы
;     RET

;----------------------------------------------------------------------------
; Это была последняя команда. Дальше страница 8E00.
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; Начало любой команды. 
; A - код команды
;----------------------------------------------------------------------------
; Начало любой команды. 
; A - код команды
StartCommand:
     ; Первым этапом происходит синхронизация с контроллером
     ; Принимается 256 попыток, в каждой из которых пропускается 256+ байт
     ; То есть это максимальное кол-во данных, которое может передать контроллер
     PUSH	B
     PUSH	H
     PUSH	PSW
IFNDEF USE_DMA
     MVI	C, 0
ENDIF

StartCommand1:
     ; Режим передачи (освобождаем шину) и инициализируем HL
     CALL       SwitchRecv

IFNDEF USE_DMA
     ; Начало любой команды (это шина адреса)
     ;LXI	H, USER_PORT+1
     ;MVI       M,0
     XRA        A
     @out        USER_PORT+1
     ;MVI        M, 44h
     MVI        A,44h
     @out        USER_PORT+1
     ;MVI        M, 40h
     MVI        A,40h
     @out        USER_PORT+1
     ;MVI        M, 0h
     XRA        A
     @out        USER_PORT+1
ENDIF
     ; Если есть синхронизация, то контроллер ответит STA_START
     CALL	Recv
     CPI	STA_START
IFDEF USE_DMA
     JNZ	StartCommandErr2
ELSE
     JZ		StartCommand2

     ; Пауза. И за одно пропускаем 256 байт (в сумме будет 
     ; пропущено 64 Кб данных, максимальный размер пакета)
     PUSH	B
     MVI	C, 0
StartCommand3:
     CALL	Recv
     DCR	C
     JNZ	StartCommand3
     POP	B
        
     ; Попытки
     DCR	C
     JNZ	StartCommand1    

     ; Код ошибки
     MVI	A, STA_START
StartCommandErr2:
     POP	B ; Прошлое значение PSW
     POP	H ; Прошлое значение H
     POP	B ; Прошлое значение B     
     POP	B ; Выходим через функцию.
     RET

;----------------------------------------------------------------------------
; Синхронизация с контроллером есть. Контроллер должен ответить STA_OK_DISK

StartCommand2:
ENDIF
     ; Ответ         	
     CALL	WaitForReady
     CPI	STA_OK_DISK
     JNZ	StartCommandErr2

     ; Переключаемся в режим передачи
     CALL       SwitchSend

     POP        PSW
     POP        H
     POP        B

     ; Передаем код команды
     JMP        Send

IFDEF USE_DMA
StartCommandErr2:
     POP	B ; Прошлое значение PSW
     POP	H ; Прошлое значение H
     POP	B ; Прошлое значение B     
     POP	B ; Выходим через функцию.
     RET
ELSE

;----------------------------------------------------------------------------
; Переключиться в режим передачи

SwitchSend:
     CALL	Recv
SwitchSend0:
     MVI	A, SEND_MODE
     @out	USER_PORT+3
     RET
ENDIF
;----------------------------------------------------------------------------
; Успешное окончание команды 
; и дополнительный такт, что бы МК отпустил шину

Ret0:
     XRA	A

;----------------------------------------------------------------------------
; Окончание команды с ошибкой в A 
;EndCommand:
IFNDEF USE_DMA
; и дополнительный такт, что бы МК отпустил шину

EndCommand:
     PUSH	PSW
     CALL	Recv
     POP	PSW
ENDIF
     RET

;----------------------------------------------------------------------------
; Принять слово в DE 
; Портим A.

RecvWord:
    CALL Recv
    MOV  E, A
    CALL Recv
    MOV  D, A
    RET
    
;----------------------------------------------------------------------------
; Отправить слово из HL 
; Портим A.

SendWord:
    MOV		A, L
    CALL	Send
    MOV		A, H
    JMP		Send
    
;----------------------------------------------------------------------------
; Отправка строки
; HL - строка
; Портим A.

SendString:
     XRA	A
     ORA	M
     JZ		Send
     CALL	Send
     INX	H
     JMP	SendString
     
IFNDEF USE_DMA
;----------------------------------------------------------------------------
; Переключиться в режим приема

SwitchRecv:
     MVI	A, RECV_MODE
     @out	USER_PORT+3
     RET
ENDIF

;----------------------------------------------------------------------------
; Переключиться в режим приема и ожидание готовности МК.

SwitchRecvAndWait:
     CALL SwitchRecv

;----------------------------------------------------------------------------
; Ожидание готовности МК.

WaitForReady:
     CALL	Recv
     CPI	STA_WAIT
     JZ		WaitForReady
     RET

IFDEF USE_DMA
;----------------------------------------------------------------------------
; Отправить DE байт по адресу BC
; Портим A
SendBlock:
     MVI    A,80H
     JMP    RecvSendBlock

;----------------------------------------------------------------------------
; Принять DE байт по адресу BC
; Увеличить BC на размер блока
; Портим A

RecvBlock:
     MVI    A,40H
RecvSendBlock:
     PUSH   D

     ; Swap BC and DE
     PUSH   B
     PUSH   D
     POP    B
     POP    D

     PUSH   B
     ORA    B
     MOV    B,A
     CALL   SET_DMAW
     XCHG
     POP    B
     DAD    B
     XCHG
     MOV    C,E
     MOV    B,D
     POP    D
     RET

;RecvBlock2:
;    JMP    DmaReadVariable
ELSE
;----------------------------------------------------------------------------
; Принять DE байт по адресу BC
; Портим A
PPI_PG  EQU     0D0H
RecvBlock:
     PUSH	H
     ;MVI        H,20H
IFDEF  	USE_PRG_DC
     @SYSREG    0A0H
     MVI        A,1
     OUT        PPI_PG
     @SYSREG    80H
     LXI        H,PPI_PG*256+1
ELSE
     LXI 	H, USER_PORT+1
ENDIF
     ANA        A
     MOV        A,D
     RAR
     MOV        D,A
     MOV        A,E
     RAR
     MOV        E,A
     INR 	D
     XRA 	A
     ORA 	E
     JZ 	RecvBlock2

RecvBlock1:
    REPT        2
    MVI         M, 20h			; 10
    MVI         M, 0			; 10
  IFDEF  	USE_PRG_DC
     LDA        PPI_PG*256              ; 13
  ELSE
     LDA        USER_PORT               ; 13
  ENDIF
     STAX	B		        ; 7
     INX	B		        ; 5 = 51
     ENDM
     DCR	E		        ; 5
     JNZ	RecvBlock1		; 10 = 66
RecvBlock2:
     DCR	D
     JNZ	RecvBlock1
IFDEF  	USE_PRG_DC
     @SYSREG    0A0H
     MVI        A,MEM_HI+10h
     OUT        PPI_PG
     @SYSREG    80H
ENDIF
     POP	H
     RET

;----------------------------------------------------------------------------
; Загрузка данных по адресу BC. 
; На выходе HL сколько загрузили
; Портим A
; Если загружено без ошибок, на выходе Z=1

RecvBuf:
     LXI	H, 0
RecvBuf0:   
     ; Подождать
     CALL	WaitForReady
     CPI	STA_OK_READ
     JZ		Ret0		; на выходе Z (нет ошибки)
     CPI        STA_OK_BLOCK
     JNZ	EndCommand	; на выходе NZ (ошибка)

     ; Размер загруженных данных в DE
     CALL	RecvWord

     ; В HL общий размер
     DAD D

     ; Принять DE байт по адресу BC
     CALL	RecvBlock

     JMP	RecvBuf0
ENDIF
;----------------------------------------------------------------------------
; Скопировать строку с ограничением 256 символов (включая терминатор)

strcpy255:
     MVI  B, 255
strcpy255_1:
     LDAX D
     INX  D
     MOV  M, A
     INX  H
     ORA  A
     RZ
     DCR  B
     JNZ  strcpy255_1
     MVI  M, 0 ; Терминатор
     RET

;----------------------------------------------------------------------------
; Отправить байт из A.

Send:
IFDEF USE_DMA
    PUSH    H
    LHLD    BUF_PTR
    MOV     M,A
    INX     H
    SHLD    BUF_PTR
    POP H
    RET
ELSE
     @out	USER_PORT
ENDIF
;----------------------------------------------------------------------------
; Принять байт в А

Recv:
IFDEF USE_DMA
     LDA    BUF_SIZE
     ORA    A
     CZ     DmaReadVariable
     LDA    BUF_SIZE
     DCR    A
     STA    BUF_SIZE
     PUSH   H
     LHLD   BUF_PTR
     MOV    A,M
     INX    H
     SHLD   BUF_PTR
     POP    H
ELSE
     MVI	A, 20h
     @out	USER_PORT+1
     XRA	A
     @out	USER_PORT+1
     @in	USER_PORT
ENDIF
     RET
IFDEF USE_DMA
;----------------------------------------------------------------------------
SEND_MODE       EQU 0         ; Режим передачи
RECV_MODE       EQU 1         ; Режим приема

;----------------------------------------------------------------------------
; Установка режима приема или передачи

SwitchRecv:
     PUSH   H
     LDA    Mode
     ORA    A ; CPI SEND_MODE
     JNZ    RM01

     PUSH   D
     PUSH   B
     LXI    H,-BUF
     XCHG
     LHLD   BUF_PTR
     DAD    D
     MOV    A,H
     ORA    L
     JZ     RM02
     XCHG
     LXI    H,BUF-2
     MOV    M,E
     INX    H
     MOV    M,D
     DCX    H
     XCHG
     LXI    B,8002h
     ;RST    3
     CALL   SET_DMAW
     LDAX   D
     INX    D
     MOV    C,A
     LDAX   D
     INX    D
     ORI    80H
     MOV    B,A
     ;RST    3
     CALL   SET_DMAW
RM02:
     POP    B
     POP    D
RM01:
     MVI   A, RECV_MODE
     JMP   SetMode
SwitchSend:
     PUSH  H
     XRA   A ; MVI   A,SEND_MODE
SetMode:
     STA   Mode
     XRA    A
     STA   BUF_SIZE
     LXI   H, BUF
     SHLD  BUF_PTR
     ;MVI   C,0
     POP   H
     RET

; Read variable length DMA record - the first packet is 2 bytes length,
; the second - data with previosly transmitted length
DmaReadVariable:
     PUSH  D
     PUSH  B
     LXI   B,4002H
     LXI   D,BUF
     ;RST   3
     CALL  SET_DMAW
     LDAX  D
     INX   D
     MOV   C,A
     LDAX  D
     INX   D
     ORI   40H
     MOV   B,A
     CALL  SET_DMAW
     MOV   A,C
     STA   BUF_SIZE
     ;CPI    16
     ;JNC   $
     ;MOV   A,B
     ;ANI   3Fh
     ;JNZ   $
     XCHG
     SHLD  BUF_PTR
     XCHG
     POP   B
     POP   D
     RET

; Set DMA with waiting of the end of transfer
SET_DMAW:
; Program DMA controller
; DE - start address
; BC - packet length with MSB:
;   10 - read cycle (transfer from memory to device)
;   01 - write cycle (thansfer from device to memory)
     DI
     @IN    DMA+0Fh
     INR    A
     JZ     DVT37
     MVI    A,0F4H
     @OUT   DMA+8
     MOV    A,E
     @OUT   DMA+2
     MOV    A,D
     @OUT   DMA+2
     DCX    B
     MOV    A,C
     @OUT   DMA+3
     MOV    A,B
     @OUT   DMA+3
     INX    B
     MVI    A,0F6H
     @OUT   DMA+8
WD01:
     LDA    NO_EI
     ORA    A
     JNZ    WAIT_DMA
     EI
WAIT_DMA:
     @IN    DMA+8
     ANI   2
     JZ    WAIT_DMA
     RET
DVT37:
     MOV   A,B
     PUSH  PSW
     ANI   3Fh
     MOV   B,A
     @OUT  DMA+0Ch
     MVI   A,5 ; Stop channel 1
     @OUT  DMA+0Ah

     MOV   A,E
     @out  DMA+2
     MOV   A,D
     @OUT  DMA+2
     DCX   B
     MOV   A,C
     @OUT  DMA+3
     MOV   A,B
     @OUT  DMA+3
     INX   B

     POP   PSW
     ANI   0C0H
     RRC
     RRC
     RRC
     RRC
     ORI   1
     @OUT  DMA+0Bh
     MVI   A,20h
     @OUT  DMA+8
     MVI   A,1 ; Start channel 1
     @OUT  DMA+0Ah
     JMP   WD01



Mode: db RECV_MODE
BUF_PTR:    ds  2
BUF_SIZE:   ds  1
BUF:        ds  32
ENDIF
;.End
