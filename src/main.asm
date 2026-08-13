.MODEL SMALL
.STACK 100h

.DATA

    ; =========================================================
    ; STORED CREDENTIALS
    ; =========================================================

    stored_user     DB 'admin$'
    stored_pass     DB 'pass123$'

    max_len         DB 20
    actual_len      DB ?

    ; DOS buffered input buffer
    ; [0] = maximum characters
    ; [1] = actual characters entered
    ; [2...] = input characters
    input_buf       DB 22 DUP('$')

    ; Cleaned username and password
    user_input      DB 21 DUP('$')
    pass_input      DB 21 DUP('$')


    ; =========================================================
    ; LOGIN SCREEN
    ; =========================================================

    title_msg       DB 0DH,0AH
                    DB '========================================',0DH,0AH
                    DB '     FOOD DELIVERY SYSTEM - LOGIN       ',0DH,0AH
                    DB '========================================',0DH,0AH
                    DB '$'

    prompt_user     DB 0DH,0AH,'Username : $'
    prompt_pass     DB 0DH,0AH,'Password : $'

    success_msg     DB 0DH,0AH
                    DB 'Login successful! Welcome to Food Delivery System.'
                    DB 0DH,0AH
                    DB '$'

    fail_msg        DB 0DH,0AH
                    DB 'Invalid username or password. Try again.'
                    DB 0DH,0AH
                    DB '$'

    logout_msg      DB 0DH,0AH
                    DB 'You have been logged out. Goodbye!'
                    DB 0DH,0AH
                    DB '$'

    newline_msg     DB 0DH,0AH,'$'


    ; =========================================================
    ; MAIN MENU
    ; =========================================================

    main_menu_msg   DB 0DH,0AH
                    DB '========================================',0DH,0AH
                    DB '          FOOD DELIVERY SYSTEM           ',0DH,0AH
                    DB '========================================',0DH,0AH
                    DB '1. Place Order',0DH,0AH
                    DB '2. View Cart',0DH,0AH
                    DB '3. Order History',0DH,0AH
                    DB '4. Logout',0DH,0AH
                    DB '5. Quit Program',0DH,0AH
                    DB '========================================',0DH,0AH
                    DB 'Choose an option: $'


    ; =========================================================
    ; MODULE MESSAGES
    ; =========================================================

    order_msg      DB 0DH,0AH
                   DB '----------------------------------------',0DH,0AH
                   DB '             PLACE ORDER                ',0DH,0AH
                   DB '----------------------------------------',0DH,0AH
                   DB 'Order module is ready.',0DH,0AH
                   DB 'Press any key to return to Main Menu...$'

    cart_msg       DB 0DH,0AH
                   DB '----------------------------------------',0DH,0AH
                   DB '              VIEW CART                 ',0DH,0AH
                   DB '----------------------------------------',0DH,0AH
                   DB 'Cart module is ready.',0DH,0AH
                   DB 'Press any key to return to Main Menu...$'

    history_msg    DB 0DH,0AH
                   DB '----------------------------------------',0DH,0AH
                   DB '            ORDER HISTORY               ',0DH,0AH
                   DB '----------------------------------------',0DH,0AH
                   DB 'Order history module is ready.',0DH,0AH
                   DB 'Press any key to return to Main Menu...$'


.CODE

    ; =========================================================
    ; EXTERNAL PROCEDURES
    ; =========================================================

    EXTRN ClearScreen:NEAR
    EXTRN NewLine:NEAR
    EXTRN ExitProgram:NEAR
    EXTRN PrintLogo:NEAR
    EXTRN PrintString:NEAR


; =============================================================
; MAIN PROGRAM
; =============================================================

main PROC

    ; ---------------------------------------------------------
    ; Initialize DS
    ; ---------------------------------------------------------

    MOV AX, @DATA
    MOV DS, AX


; =============================================================
; LOGIN LOOP
; =============================================================

LOGIN_LOOP:

    CALL ClearScreen

    ; Show login screen
    CALL SHOW_LOGIN_SCREEN

    ; Read username
    CALL READ_USERNAME

    ; Read password
    CALL READ_PASSWORD

    ; Validate credentials
    CALL VALIDATE_LOGIN

    ; AL = 1 -> valid
    ; AL = 0 -> invalid

    CMP AL, 1
    JE LOGIN_OK


    ; ---------------------------------------------------------
    ; Login failed
    ; ---------------------------------------------------------

    LEA DX, fail_msg
    MOV AH, 09H
    INT 21H

    JMP LOGIN_LOOP


; =============================================================
; LOGIN SUCCESS
; =============================================================

LOGIN_OK:

    LEA DX, success_msg
    MOV AH, 09H
    INT 21H

    ; Go to main menu
    CALL POST_LOGIN_MENU

    ; If POST_LOGIN_MENU returns,
    ; user selected Logout
    JMP LOGIN_LOOP


main ENDP


; =============================================================
; SHOW_LOGIN_SCREEN
;
; Displays the login banner.
; =============================================================

SHOW_LOGIN_SCREEN PROC

    LEA DX, title_msg
    MOV AH, 09H
    INT 21H

    RET

SHOW_LOGIN_SCREEN ENDP


; =============================================================
; READ_USERNAME
;
; Uses DOS function 0AH buffered keyboard input.
;
; input_buf:
;   byte 0 = maximum input length
;   byte 1 = actual input length
;   byte 2 onwards = characters
;
; Result:
;   user_input contains username terminated by '$'
; =============================================================

READ_USERNAME PROC

    ; Display username prompt
    LEA DX, prompt_user
    MOV AH, 09H
    INT 21H


    ; ---------------------------------------------------------
    ; Clear previous username buffer
    ; ---------------------------------------------------------

    LEA DI, user_input
    MOV CX, 21
    MOV AL, '$'

CLEAR_USERNAME_BUFFER:

    MOV [DI], AL
    INC DI

    LOOP CLEAR_USERNAME_BUFFER


    ; ---------------------------------------------------------
    ; Prepare DOS buffered input
    ; ---------------------------------------------------------

    MOV input_buf[0], 20
    MOV input_buf[1], 0

    LEA DX, input_buf
    MOV AH, 0AH
    INT 21H


    ; ---------------------------------------------------------
    ; Get number of characters entered
    ; ---------------------------------------------------------

    MOV CL, input_buf[1]
    MOV CH, 0

    MOV actual_len, CL


    ; ---------------------------------------------------------
    ; Copy input_buf+2 into user_input
    ; ---------------------------------------------------------

    LEA BX, input_buf+2
    LEA DI, user_input

    CMP CX, 0
    JE COPY_USER_DONE


COPY_USER_LOOP:

    MOV AL, [BX]
    MOV [DI], AL

    INC BX
    INC DI

    LOOP COPY_USER_LOOP


COPY_USER_DONE:

    ; Add '$' terminator
    MOV BYTE PTR [DI], '$'

    RET

READ_USERNAME ENDP


; =============================================================
; READ_PASSWORD
;
; Reads password one character at a time.
;
; DOS function 08H:
;   Read character without echo
;
; Each character is displayed as '*'.
;
; ENTER finishes the password.
;
; BACKSPACE removes the previous character.
; =============================================================

READ_PASSWORD PROC

    ; Display password prompt
    LEA DX, prompt_pass
    MOV AH, 09H
    INT 21H


    ; ---------------------------------------------------------
    ; Clear previous password buffer
    ; ---------------------------------------------------------

    LEA DI, pass_input
    MOV CX, 21
    MOV AL, '$'

CLEAR_PASSWORD_BUFFER:

    MOV [DI], AL
    INC DI

    LOOP CLEAR_PASSWORD_BUFFER


    ; ---------------------------------------------------------
    ; Prepare password input
    ; ---------------------------------------------------------

    LEA DI, pass_input

    XOR CX, CX


; =============================================================
; PASSWORD INPUT LOOP
; =============================================================

PASS_LOOP:

    ; Read character without echo
    MOV AH, 08H
    INT 21H


    ; ---------------------------------------------------------
    ; ENTER
    ; ---------------------------------------------------------

    CMP AL, 0DH
    JE PASS_DONE


    ; ---------------------------------------------------------
    ; BACKSPACE
    ; ---------------------------------------------------------

    CMP AL, 08H
    JE PASS_BACKSPACE


    ; ---------------------------------------------------------
    ; Maximum length check
    ; ---------------------------------------------------------

    CMP CX, 20
    JAE PASS_LOOP


    ; ---------------------------------------------------------
    ; Store character
    ; ---------------------------------------------------------

    MOV [DI], AL
    INC DI
    INC CX


    ; ---------------------------------------------------------
    ; Display '*'
    ; ---------------------------------------------------------

    PUSH AX

    MOV DL, '*'
    MOV AH, 02H
    INT 21H

    POP AX

    JMP PASS_LOOP


; =============================================================
; PASSWORD BACKSPACE
; =============================================================

PASS_BACKSPACE:

    ; If there is nothing to delete
    CMP CX, 0
    JE PASS_LOOP


    ; Move pointer back
    DEC DI
    DEC CX


    ; ---------------------------------------------------------
    ; Erase '*' from screen
    ;
    ; Backspace
    ; Space
    ; Backspace
    ; ---------------------------------------------------------

    MOV DL, 08H
    MOV AH, 02H
    INT 21H

    MOV DL, ' '
    MOV AH, 02H
    INT 21H

    MOV DL, 08H
    MOV AH, 02H
    INT 21H

    JMP PASS_LOOP


; =============================================================
; PASSWORD DONE
; =============================================================

PASS_DONE:

    MOV BYTE PTR [DI], '$'

    LEA DX, newline_msg
    MOV AH, 09H
    INT 21H

    RET

READ_PASSWORD ENDP


; =============================================================
; VALIDATE_LOGIN
;
; Compares:
;
;   user_input  vs stored_user
;   pass_input  vs stored_pass
;
; Return:
;
;   AL = 1 -> valid
;   AL = 0 -> invalid
; =============================================================

VALIDATE_LOGIN PROC

    ; ---------------------------------------------------------
    ; Compare username
    ; ---------------------------------------------------------

    LEA SI, user_input
    LEA DI, stored_user

    CALL STR_COMPARE

    CMP AL, 0
    JE VALIDATE_FAIL


    ; ---------------------------------------------------------
    ; Compare password
    ; ---------------------------------------------------------

    LEA SI, pass_input
    LEA DI, stored_pass

    CALL STR_COMPARE

    CMP AL, 0
    JE VALIDATE_FAIL


    ; Both correct
    MOV AL, 1

    RET


VALIDATE_FAIL:

    MOV AL, 0

    RET

VALIDATE_LOGIN ENDP


; =============================================================
; STR_COMPARE
;
; Compare two '$'-terminated strings.
;
; Input:
;   DS:SI -> first string
;   DS:DI -> second string
;
; Return:
;   AL = 1 -> equal
;   AL = 0 -> not equal
; =============================================================

STR_COMPARE PROC

    ; Protect BX because BL is used
    PUSH BX


CMP_LOOP:

    MOV AL, [SI]
    MOV BL, [DI]

    CMP AL, BL
    JNE CMP_NOT_EQUAL


    ; If both reached '$',
    ; strings are equal
    CMP AL, '$'
    JE CMP_EQUAL


    INC SI
    INC DI

    JMP CMP_LOOP


CMP_EQUAL:

    POP BX

    MOV AL, 1

    RET


CMP_NOT_EQUAL:

    POP BX

    MOV AL, 0

    RET

STR_COMPARE ENDP


; =============================================================
; POST_LOGIN_MENU
;
; Main menu after successful login.
;
; 1. Place Order
; 2. View Cart
; 3. Order History
; 4. Logout
; 5. Quit Program
; =============================================================

POST_LOGIN_MENU PROC


MENU_LOOP:

    CALL ClearScreen


    ; ---------------------------------------------------------
    ; Display main menu
    ; ---------------------------------------------------------

    LEA DX, main_menu_msg
    MOV AH, 09H
    INT 21H


    ; ---------------------------------------------------------
    ; Read menu option
    ; ---------------------------------------------------------

    MOV AH, 01H
    INT 21H


    ; ---------------------------------------------------------
    ; Option 1 - Place Order
    ; ---------------------------------------------------------

    CMP AL, '1'
    JE OPT_ORDER


    ; ---------------------------------------------------------
    ; Option 2 - View Cart
    ; ---------------------------------------------------------

    CMP AL, '2'
    JE OPT_CART


    ; ---------------------------------------------------------
    ; Option 3 - Order History
    ; ---------------------------------------------------------

    CMP AL, '3'
    JE OPT_HISTORY


    ; ---------------------------------------------------------
    ; Option 4 - Logout
    ; ---------------------------------------------------------

    CMP AL, '4'
    JE OPT_LOGOUT


    ; ---------------------------------------------------------
    ; Option 5 - Quit
    ; ---------------------------------------------------------

    CMP AL, '5'
    JE OPT_QUIT


    ; ---------------------------------------------------------
    ; Invalid option
    ; ---------------------------------------------------------

    LEA DX, newline_msg
    MOV AH, 09H
    INT 21H

    JMP MENU_LOOP


; =============================================================
; OPTION 1
; =============================================================

OPT_ORDER:

    CALL ORDER_MODULE

    JMP MENU_LOOP


; =============================================================
; OPTION 2
; =============================================================

OPT_CART:

    CALL CART_MODULE

    JMP MENU_LOOP


; =============================================================
; OPTION 3
; =============================================================

OPT_HISTORY:

    CALL HISTORY_MODULE

    JMP MENU_LOOP


; =============================================================
; OPTION 4
; =============================================================

OPT_LOGOUT:

    CALL LOGOUT

    ; Return to MAIN
    ; MAIN will JMP LOGIN_LOOP
    RET


; =============================================================
; OPTION 5
; =============================================================

OPT_QUIT:

    CALL ExitProgram

    ; Safety fallback
    MOV AX, 4C00H
    INT 21H


POST_LOGIN_MENU ENDP


; =============================================================
; ORDER_MODULE
;
; Temporary module.
;
; Replace this with your actual Place Order module
; if you already have one in another ASM file.
; =============================================================

ORDER_MODULE PROC

    CALL ClearScreen

    LEA DX, order_msg
    MOV AH, 09H
    INT 21H


    ; Wait for key
    MOV AH, 08H
    INT 21H

    RET

ORDER_MODULE ENDP


; =============================================================
; CART_MODULE
;
; Temporary module.
;
; Replace this with your actual Cart module
; if you already have one in another ASM file.
; =============================================================

CART_MODULE PROC

    CALL ClearScreen

    LEA DX, cart_msg
    MOV AH, 09H
    INT 21H


    ; Wait for key
    MOV AH, 08H
    INT 21H

    RET

CART_MODULE ENDP


; =============================================================
; HISTORY_MODULE
;
; Temporary module.
;
; Replace this with your actual Order History module
; if you already have one in another ASM file.
; =============================================================

HISTORY_MODULE PROC

    CALL ClearScreen

    LEA DX, history_msg
    MOV AH, 09H
    INT 21H


    ; Wait for key
    MOV AH, 08H
    INT 21H

    RET

HISTORY_MODULE ENDP


; =============================================================
; LOGOUT
;
; Clears:
;
;   user_input
;   pass_input
;
; Then returns to MAIN.
; =============================================================

LOGOUT PROC

    ; ---------------------------------------------------------
    ; Display logout message
    ; ---------------------------------------------------------

    LEA DX, logout_msg
    MOV AH, 09H
    INT 21H


    ; ---------------------------------------------------------
    ; Clear username buffer
    ; ---------------------------------------------------------

    LEA DI, user_input

    MOV CX, 21
    XOR AL, AL


CLEAR_USER:

    MOV [DI], AL

    INC DI

    LOOP CLEAR_USER


    ; ---------------------------------------------------------
    ; Clear password buffer
    ; ---------------------------------------------------------

    LEA DI, pass_input

    MOV CX, 21


CLEAR_PASS:

    MOV [DI], AL

    INC DI

    LOOP CLEAR_PASS


    RET

LOGOUT ENDP


; =============================================================
; END PROGRAM
; =============================================================

END main