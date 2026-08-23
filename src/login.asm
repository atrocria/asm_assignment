.MODEL SMALL

PUBLIC LoginMenu
PUBLIC Logout

.DATA

    MAX_USERS   EQU 10
    FIELD_LEN   EQU 21
    REC_SIZE    EQU 42

    user_db     LABEL BYTE
                DB  'admin$', 15 DUP(0)
                DB  'pass123$', 13 DUP(0)
                DB  (MAX_USERS-1)*REC_SIZE DUP(0)

    user_count  DB  1

    ; ---------- Buffers ----------
    input_buf     DB  22 DUP('$')
    user_input    DB  21 DUP('$')
    pass_input    DB  21 DUP('$')

    new_user      DB  21 DUP('$')
    new_pass      DB  21 DUP('$')
    confirm_pass  DB  21 DUP('$')

    ; ---------- Screen text ----------
    main_menu_msg   DB  0DH,0AH
                    DB  '========================================',0DH,0AH
                    DB  '     FOOD DELIVERY SYSTEM               ',0DH,0AH
                    DB  '========================================',0DH,0AH
                    DB  '1. Login',0DH,0AH
                    DB  '2. Register New Account',0DH,0AH
                    DB  '3. Exit',0DH,0AH
                    DB  'Choose an option: $'

    title_msg       DB  0DH,0AH
                    DB  '----------------------------------------',0DH,0AH
                    DB  '               LOGIN                    ',0DH,0AH
                    DB  '----------------------------------------',0DH,0AH,'$'

    reg_title_msg   DB  0DH,0AH
                    DB  '----------------------------------------',0DH,0AH
                    DB  '        NEW ACCOUNT REGISTRATION        ',0DH,0AH
                    DB  '----------------------------------------',0DH,0AH,'$'

    prompt_user     DB  0DH,0AH,'Username : $'
    prompt_pass     DB  0DH,0AH,'Password : $'

    reg_prompt_user     DB  0DH,0AH,'Username : $'
    reg_prompt_pass     DB  0DH,0AH,'Password : $'
    reg_prompt_confirm  DB  0DH,0AH,'Confirm password  : $'

    success_msg     DB  0DH,0AH,'Login successful! Welcome to Food Delivery System.',0DH,0AH,'$'
    fail_msg        DB  0DH,0AH,'Invalid username or password. Try again.',0DH,0AH,'$'
    logout_msg      DB  0DH,0AH,'You have been logged out. Goodbye!',0DH,0AH,'$'

    reg_dup_msg       DB  0DH,0AH,'That username is already taken. Please try again.',0DH,0AH,'$'
    reg_full_msg      DB  0DH,0AH,'Registration is full - no more accounts can be added.',0DH,0AH,'$'
    reg_mismatch_msg  DB  0DH,0AH,'Passwords do not match. Please re-enter the password.',0DH,0AH,'$'
    reg_success_msg   DB  0DH,0AH,'Account created successfully! You can now log in.',0DH,0AH,'$'
    invalid_choice_msg DB 0DH,0AH,'Invalid choice, please try again.',0DH,0AH,'$'

    newline         DB  0DH,0AH,'$'

.CODE

EXTRN ClearScreen:NEAR

;-------------------------------------------------------------
; LOGIN_MENU
; Displays the Login / Register / Exit menu.  It returns to main.asm
; only after a successful login.
;-------------------------------------------------------------
LoginMenu PROC NEAR
LOGIN_MENU_LOOP:
    LEA DX, main_menu_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H                   ; read a single character (with echo)
    INT 21H

    CMP AL, '1'
    JE  GOTO_LOGIN
    CMP AL, '2'
    JE  GOTO_REGISTER
    CMP AL, '3'
    JE  GOTO_EXIT

    LEA DX, invalid_choice_msg
    MOV AH, 09H
    INT 21H
    JMP LOGIN_MENU_LOOP

GOTO_LOGIN:
    CALL DO_LOGIN                 ; loops internally until credentials are valid
    RET                           ; main.asm now shows the application menu

GOTO_REGISTER:
    CALL REGISTER
    JMP LOGIN_MENU_LOOP

GOTO_EXIT:
    MOV AH, 4CH
    INT 21H
LoginMenu ENDP


;-------------------------------------------------------------
; DO_LOGIN
; Repeats the login screen until credentials are valid.
;-------------------------------------------------------------
DO_LOGIN PROC
LOGIN_LOOP:
    CALL ClearScreen
    CALL SHOW_LOGIN_SCREEN
    CALL READ_USERNAME
    CALL READ_PASSWORD
    CALL VALIDATE_LOGIN

    CMP AL, 1                     ; AL = 1 if valid, 0 if invalid
    JE  LOGIN_OK

    LEA DX, fail_msg
    MOV AH, 09H
    INT 21H
    JMP LOGIN_LOOP

LOGIN_OK:
    LEA DX, success_msg
    MOV AH, 09H
    INT 21H

    RET                             ; return control to main.asm
DO_LOGIN ENDP


;-------------------------------------------------------------
; SHOW_LOGIN_SCREEN
;-------------------------------------------------------------
SHOW_LOGIN_SCREEN PROC
    LEA DX, title_msg
    MOV AH, 09H
    INT 21H
    RET
SHOW_LOGIN_SCREEN ENDP


;-------------------------------------------------------------
; READ_USERNAME
; Reads username using DOS buffered input, converts DOS's
; length-prefixed format into a '$'-terminated string.
;-------------------------------------------------------------
READ_USERNAME PROC
    LEA DX, prompt_user
    MOV AH, 09H
    INT 21H

    MOV input_buf[0], 20          ; max input length
    LEA DX, input_buf
    MOV AH, 0AH                   ; buffered keyboard input
    INT 21H

    MOV CL, input_buf[1]          ; number of chars actually entered
    MOV CH, 0
    LEA BX, input_buf+2           ; source: entered chars
    LEA DI, user_input            ; destination

    CMP CX, 0
    JE  COPY_USER_DONE

COPY_USER_LOOP:
    MOV AL, [BX]
    MOV [DI], AL
    INC BX
    INC DI
    LOOP COPY_USER_LOOP

COPY_USER_DONE:
    MOV BYTE PTR [DI], '$'
    RET
READ_USERNAME ENDP


;-------------------------------------------------------------
; READ_PASSWORD
; Reads password one character at a time (no echo), prints '*'.
; Capped at 20 characters so it can never overflow its 21-byte
; buffer (or spill into whatever data follows it in memory).
;-------------------------------------------------------------
READ_PASSWORD PROC
    LEA DX, prompt_pass
    MOV AH, 09H
    INT 21H

    LEA DI, pass_input
    XOR CX, CX                    ; character counter

PASS_LOOP:
    MOV AH, 08H                   ; read char, no echo
    INT 21H
    CMP AL, 0DH                   ; ENTER pressed?
    JE  PASS_DONE

    CMP AL, 08H                   ; backspace?
    JE  PASS_BACKSPACE

    CMP CX, 20                    ; already at max length?
    JGE PASS_LOOP                 ; ignore extra keystrokes

    MOV [DI], AL
    INC DI
    INC CX

    PUSH AX
    MOV DL, '*'
    MOV AH, 02H
    INT 21H
    POP AX
    JMP PASS_LOOP

PASS_BACKSPACE:
    CMP CX, 0
    JE  PASS_LOOP
    DEC DI
    DEC CX
    MOV DL, 08H
    MOV AH, 02H
    INT 21H
    MOV DL, ' '
    INT 21H
    MOV DL, 08H
    INT 21H
    JMP PASS_LOOP

PASS_DONE:
    MOV BYTE PTR [DI], '$'
    LEA DX, newline
    MOV AH, 09H
    INT 21H
    RET
READ_PASSWORD ENDP


;-------------------------------------------------------------
; VALIDATE_LOGIN
; Searches every stored account (0 .. user_count-1) for one
; whose username AND password both match what was typed.
; Returns: AL = 1 if a matching account is found, else AL = 0
;-------------------------------------------------------------
VALIDATE_LOGIN PROC
    MOV CL, user_count
    MOV CH, 0
    CMP CX, 0
    JE  VALIDATE_FAIL

    LEA BX, user_db                ; BX = base of current record

VALIDATE_LOOP:
    PUSH CX
    PUSH BX
    LEA SI, user_input
    MOV DI, BX                     ; username field of this record
    CALL STR_COMPARE
    POP BX
    POP CX
    CMP AL, 1
    JNE VALIDATE_NEXT

    ; username matched this record - now check its password field
    PUSH CX
    PUSH BX
    LEA SI, pass_input
    MOV DI, BX
    ADD DI, FIELD_LEN               ; password field starts 21 bytes in
    CALL STR_COMPARE
    POP BX
    POP CX
    CMP AL, 1
    JE  VALIDATE_SUCCESS
    JMP VALIDATE_FAIL               ; right username, wrong password

VALIDATE_NEXT:
    ADD BX, REC_SIZE                ; move to next record
    LOOP VALIDATE_LOOP

VALIDATE_FAIL:
    MOV AL, 0
    RET

VALIDATE_SUCCESS:
    MOV AL, 1
    RET
VALIDATE_LOGIN ENDP


;-------------------------------------------------------------
; STR_COMPARE
; Compares two '$'-terminated strings pointed to by DS:SI, DS:DI
; Returns: AL = 1 if equal, AL = 0 if not equal
;-------------------------------------------------------------
STR_COMPARE PROC
CMP_LOOP:
    MOV AL, [SI]
    MOV BL, [DI]
    CMP AL, BL
    JNE CMP_NOT_EQUAL

    CMP AL, '$'
    JE  CMP_EQUAL

    INC SI
    INC DI
    JMP CMP_LOOP

CMP_EQUAL:
    MOV AL, 1
    RET

CMP_NOT_EQUAL:
    MOV AL, 0
    RET
STR_COMPARE ENDP


;-------------------------------------------------------------
; COPY_STRING
; Copies a '$'-terminated string from DS:SI to DS:DI, inclusive
; of the terminating '$'. Used when writing into fixed-width
; record fields (caller positions DI first).
;-------------------------------------------------------------
COPY_STRING PROC
CS_LOOP:
    MOV AL, [SI]
    MOV [DI], AL
    INC SI
    INC DI
    CMP AL, '$'
    JE  CS_DONE
    JMP CS_LOOP
CS_DONE:
    RET
COPY_STRING ENDP


;-------------------------------------------------------------
; REGISTER
; Creates a new account: reads a username, rejects duplicates,
; reads + confirms a password, then appends the record.
;-------------------------------------------------------------
REGISTER PROC
REG_START:
    LEA DX, reg_title_msg
    MOV AH, 09H
    INT 21H

    CMP user_count, MAX_USERS
    JL  REG_ROOM_OK
    LEA DX, reg_full_msg
    MOV AH, 09H
    INT 21H
    RET

REG_ROOM_OK:
    ; --- read desired username ---
    LEA DX, reg_prompt_user
    MOV AH, 09H
    INT 21H

    MOV input_buf[0], 20
    LEA DX, input_buf
    MOV AH, 0AH
    INT 21H

    MOV CL, input_buf[1]
    MOV CH, 0
    LEA BX, input_buf+2
    LEA DI, new_user
    CMP CX, 0
    JE  REG_USER_COPY_DONE
REG_USER_COPY_LOOP:
    MOV AL, [BX]
    MOV [DI], AL
    INC BX
    INC DI
    LOOP REG_USER_COPY_LOOP
REG_USER_COPY_DONE:
    MOV BYTE PTR [DI], '$'

    ; --- reject if username already exists ---
    MOV CL, user_count
    MOV CH, 0
    LEA BX, user_db
REG_DUP_LOOP:
    PUSH CX
    PUSH BX
    LEA SI, new_user
    MOV DI, BX
    CALL STR_COMPARE
    POP BX
    POP CX
    CMP AL, 1
    JE  REG_DUPLICATE
    ADD BX, REC_SIZE
    LOOP REG_DUP_LOOP
    JMP REG_READ_PASSWORD

REG_DUPLICATE:
    LEA DX, reg_dup_msg
    MOV AH, 09H
    INT 21H
    JMP REG_START                   ; start registration over

    ; --- read desired password (masked) ---
REG_READ_PASSWORD:
    LEA DX, reg_prompt_pass
    MOV AH, 09H
    INT 21H
    LEA DI, new_pass
    XOR CX, CX
REG_PASS_LOOP:
    MOV AH, 08H
    INT 21H
    CMP AL, 0DH
    JE  REG_PASS_DONE
    CMP AL, 08H
    JE  REG_PASS_BACK
    CMP CX, 20
    JGE REG_PASS_LOOP
    MOV [DI], AL
    INC DI
    INC CX
    PUSH AX
    MOV DL, '*'
    MOV AH, 02H
    INT 21H
    POP AX
    JMP REG_PASS_LOOP
REG_PASS_BACK:
    CMP CX, 0
    JE  REG_PASS_LOOP
    DEC DI
    DEC CX
    MOV DL, 08H
    MOV AH, 02H
    INT 21H
    MOV DL, ' '
    INT 21H
    MOV DL, 08H
    INT 21H
    JMP REG_PASS_LOOP
REG_PASS_DONE:
    MOV BYTE PTR [DI], '$'
    LEA DX, newline
    MOV AH, 09H
    INT 21H

    ; --- confirm password ---
    LEA DX, reg_prompt_confirm
    MOV AH, 09H
    INT 21H
    LEA DI, confirm_pass
    XOR CX, CX
REG_CONFIRM_LOOP:
    MOV AH, 08H
    INT 21H
    CMP AL, 0DH
    JE  REG_CONFIRM_DONE
    CMP AL, 08H
    JE  REG_CONFIRM_BACK
    CMP CX, 20
    JGE REG_CONFIRM_LOOP
    MOV [DI], AL
    INC DI
    INC CX
    PUSH AX
    MOV DL, '*'
    MOV AH, 02H
    INT 21H
    POP AX
    JMP REG_CONFIRM_LOOP
REG_CONFIRM_BACK:
    CMP CX, 0
    JE  REG_CONFIRM_LOOP
    DEC DI
    DEC CX
    MOV DL, 08H
    MOV AH, 02H
    INT 21H
    MOV DL, ' '
    INT 21H
    MOV DL, 08H
    INT 21H
    JMP REG_CONFIRM_LOOP
REG_CONFIRM_DONE:
    MOV BYTE PTR [DI], '$'
    LEA DX, newline
    MOV AH, 09H
    INT 21H

    ; --- passwords must match ---
    LEA SI, new_pass
    LEA DI, confirm_pass
    CALL STR_COMPARE
    CMP AL, 1
    JE  REG_SAVE
    LEA DX, reg_mismatch_msg
    MOV AH, 09H
    INT 21H
    JMP REG_READ_PASSWORD           ; retry password (username already confirmed unique)

    ; --- write the new record into user_db ---
REG_SAVE:
    MOV AL, user_count
    MOV BL, REC_SIZE
    MUL BL                          ; AX = user_count * REC_SIZE
    LEA BX, user_db
    ADD BX, AX                      ; BX = base of the new record

    MOV DI, BX
    LEA SI, new_user
    CALL COPY_STRING                ; write username into field 1

    MOV DI, BX
    ADD DI, FIELD_LEN
    LEA SI, new_pass
    CALL COPY_STRING                ; write password into field 2

    INC user_count

    LEA DX, reg_success_msg
    MOV AH, 09H
    INT 21H
    RET
REGISTER ENDP


;-------------------------------------------------------------
; LOGOUT
;-------------------------------------------------------------
Logout PROC NEAR
    LEA DX, logout_msg
    MOV AH, 09H
    INT 21H

    LEA DI, user_input
    MOV CX, 21
    MOV AL, 0
CLEAR_USER:
    MOV [DI], AL
    INC DI
    LOOP CLEAR_USER

    LEA DI, pass_input
    MOV CX, 21
CLEAR_PASS:
    MOV [DI], AL
    INC DI
    LOOP CLEAR_PASS

    RET
Logout ENDP

END
