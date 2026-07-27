.model small
.stack 100h

.data
    title db "Food Delivery System$"
    ; ---------- Stored credentials (hard-coded for demo) ----------
    stored_user     DB  'admin$'            ; '$' = DOS string terminator
    stored_pass     DB  'pass123$'

    max_len         DB  20                  ; max chars allowed
    actual_len      DB  ?
    input_buf       DB  22 DUP('$')          ; buffer for username (DOS buffered input format)

    user_input      DB  21 DUP('$')          ; cleaned username string
    pass_input      DB  21 DUP('$')          ; password string (typed masked)

    ; ---------- Screen text ----------
    title_msg       DB  0DH,0AH
                    DB  '========================================',0DH,0AH
                    DB  '     FOOD DELIVERY SYSTEM - LOGIN       ',0DH,0AH
                    DB  '========================================',0DH,0AH,'$'

    prompt_user     DB  0DH,0AH,'Username : $'
    prompt_pass     DB  0DH,0AH,'Password : $'

    success_msg     DB  0DH,0AH,'Login successful! Welcome to Food Delivery System.',0DH,0AH,'$'
    fail_msg        DB  0DH,0AH,'Invalid username or password. Try again.',0DH,0AH,'$'
    logout_msg      DB  0DH,0AH,'You have been logged out. Goodbye!',0DH,0AH,'$'
    menu_msg        DB  0DH,0AH,'1. Logout',0DH,0AH,'2. Exit Program',0DH,0AH
                    DB  'Choose an option: $'
    newline_msg     DB  0DH,0AH,'$'

.CODE

    EXTRN ClearScreen:NEAR
    EXTRN NewLine:NEAR
    EXTRN ExitProgram:NEAR
    EXTRN PrintLogo:NEAR
    EXTRN PrintString:NEAR

    main PROC

    ; main job: loop the whole program and print out logo and present modules

    ; 1. login/logout 
    ; 2. order 
    ; 3. cart 
    ; 4. checkout 
    ; 5. login/logout 
    ; 6. report (only show if atleast one order is made)
    ; 7. exit

    mov ax,@data
    mov ds,ax

    call ClearScreen

    LOGIN_LOOP:
        CALL SHOW_LOGIN_SCREEN
        CALL READ_USERNAME
        CALL READ_PASSWORD
        CALL VALIDATE_LOGIN

        CMP AL, 1                  ; AL = 1 if valid, 0 if invalid
        JE  LOGIN_OK

        LEA DX, fail_msg
        MOV AH, 09H
        INT 21H
        JMP LOGIN_LOOP

    LOGIN_OK:
        LEA DX, success_msg
        MOV AH, 09H
        INT 21H

        CALL POST_LOGIN_MENU        ; shows menu, waits for logout/exit choice
        JMP LOGIN_LOOP               ; after logout, go back to login screen

        MOV AH, 4CH                 ; (unreachable safety exit)
        INT 21H
    CALL ExitProgram


    ;-------------------------------------------------------------
    ; SHOW_LOGIN_SCREEN
    ; Prints the login banner and field prompts
    ;-------------------------------------------------------------
    SHOW_LOGIN_SCREEN PROC
        LEA DX, title_msg
        MOV AH, 09H
        INT 21H
        RET
    SHOW_LOGIN_SCREEN ENDP


    ;-------------------------------------------------------------
    ; READ_USERNAME
    ; Reads username using DOS buffered input (echoes as typed)
    ;-------------------------------------------------------------
    READ_USERNAME PROC
        LEA DX, prompt_user
        MOV AH, 09H
        INT 21H

        MOV input_buf[0], 20          ; max input length
        LEA DX, input_buf
        MOV AH, 0AH                   ; buffered keyboard input
        INT 21H

        ; copy actual characters into user_input, append '$'
        MOV CL, input_buf[1]          ; number of chars entered (byte)
        MOV CH, 0                     ; CX = count (word), 8086-safe zero-extend
        MOV actual_len, CL
        LEA BX, input_buf+2           ; entered chars start here (source pointer)
        LEA DI, user_input            ; destination pointer

        CMP CX, 0
        JE  COPY_USER_DONE

    COPY_USER_LOOP:
        MOV AL, [BX]                  ; base register only - valid addressing
        MOV [DI], AL                  ; DI alone as destination - valid addressing
        INC BX
        INC DI
        LOOP COPY_USER_LOOP           ; decrements CX, loops until CX = 0

    COPY_USER_DONE:
        MOV BYTE PTR [DI], '$'
        RET
    READ_USERNAME ENDP


    ;-------------------------------------------------------------
    ; READ_PASSWORD
    ; Reads password one character at a time (no echo), prints '*'
    ; Ends on ENTER (carriage return, ASCII 13)
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

        MOV [DI], AL
        INC DI
        INC CX

        ; echo '*' to screen
        PUSH AX
        MOV DL, '*'
        MOV AH, 02H
        INT 21H
        POP AX
        JMP PASS_LOOP

    PASS_BACKSPACE:
        CMP CX, 0
        JE  PASS_LOOP                 ; nothing to delete
        DEC DI
        DEC CX
        ; erase the '*' on screen
        MOV DL, 08H                   ; backspace
        MOV AH, 02H
        INT 21H
        MOV DL, ' '
        INT 21H
        MOV DL, 08H
        INT 21H
        JMP PASS_LOOP

    PASS_DONE:
        MOV BYTE PTR [DI], '$'
        LEA DX, newline_msg
        MOV AH, 09H
        INT 21H
        RET
    READ_PASSWORD ENDP


    ;-------------------------------------------------------------
    ; VALIDATE_LOGIN
    ; Compares user_input/pass_input against stored credentials.
    ; Returns: AL = 1 if match, AL = 0 if not
    ;-------------------------------------------------------------
    VALIDATE_LOGIN PROC
        LEA SI, user_input
        LEA DI, stored_user
        CALL STR_COMPARE
        CMP AL, 0
        JE  VALIDATE_FAIL

        LEA SI, pass_input
        LEA DI, stored_pass
        CALL STR_COMPARE
        CMP AL, 0
        JE  VALIDATE_FAIL

        MOV AL, 1
        RET

    VALIDATE_FAIL:
        MOV AL, 0
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

        CMP AL, '$'                   ; reached end of both strings?
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
    ; POST_LOGIN_MENU
    ; Simple menu so the user can trigger LOGOUT or EXIT
    ;-------------------------------------------------------------
    POST_LOGIN_MENU PROC
    MENU_LOOP:
        LEA DX, menu_msg
        MOV AH, 09H
        INT 21H

        MOV AH, 01H                   ; read a single character (with echo)
        INT 21H

        CMP AL, '1'
        JE  DO_LOGOUT
        CMP AL, '2'
        JE  DO_EXIT

        LEA DX, newline_msg
        MOV AH, 09H
        INT 21H
        JMP MENU_LOOP

    DO_LOGOUT:
        CALL LOGOUT
        RET                            ; back to MAIN -> LOGIN_LOOP

    DO_EXIT:
        MOV AH, 4CH
        INT 21H
    POST_LOGIN_MENU ENDP


    ;-------------------------------------------------------------
    ; LOGOUT
    ; Clears the stored input buffers and shows a logout message
    ;-------------------------------------------------------------
    LOGOUT PROC
        LEA DX, logout_msg
        MOV AH, 09H
        INT 21H

        ; wipe sensitive buffers from memory
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
    LOGOUT ENDP

    call NewLine

    call ExitProgram

main ENDP

END main
