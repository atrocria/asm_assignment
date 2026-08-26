; main.asm
.MODEL SMALL
.STACK 100H

.DATA
    ; =========================================================
    ; APPLICATION MENU
    ; =========================================================

    main_menu_msg   DB 0DH,0AH
                    DB '=============================================================',0DH,0AH
                    DB '     Welcome to DeliGo Food Delivery and Ordering System     ',0DH,0AH
                    DB '=============================================================',0DH,0AH
                    DB '1. Place Order',0DH,0AH
                    DB '2. View Cart',0DH,0AH
                    DB '3. Order History',0DH,0AH
                    DB '4. Logout',0DH,0AH
                    DB '5. Quit Program',0DH,0AH
                    DB '=============================================================',0DH,0AH
                    DB 'Choose an option: $'

    newline_msg     DB 0DH,0AH,'$'

.CODE

    ; Login module entry points.""
    EXTRN LoginMenu:NEAR
    EXTRN Logout:NEAR;

    ; Feature module entry points.
    EXTRN OrderModule:NEAR
    EXTRN CartModule:NEAR
    EXTRN HistoryModule:NEAR

    ; Shared utility module entry points.
    EXTRN ClearScreen:NEAR
    EXTRN ExitProgram:NEAR


; =============================================================
; MAIN PROGRAM
;
; main.asm owns only application navigation.  Login, registration,
; credential validation, and logout-state cleanup are in login.asm.
; =============================================================

main PROC
    MOV AX, @DATA
    MOV DS, AX

APPLICATION_LOOP:
    CALL LoginMenu                 ; returns only after a valid login
    CALL PostLoginMenu             ; returns when the user logs out
    JMP APPLICATION_LOOP
main ENDP


; =============================================================
; POST-LOGIN APPLICATION MENU
; =============================================================

PostLoginMenu PROC NEAR
MENU_LOOP:
    CALL ClearScreen

    LEA DX, main_menu_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    CMP AL, '1'
    JE OPT_ORDER

    CMP AL, '2'
    JE OPT_CART

    CMP AL, '3'
    JE OPT_HISTORY

    CMP AL, '4'
    JE OPT_LOGOUT

    CMP AL, '5'
    JE OPT_QUIT

    LEA DX, newline_msg
    MOV AH, 09H
    INT 21H
    JMP MENU_LOOP

OPT_ORDER:
    CALL OrderModule
    JMP MENU_LOOP

OPT_CART:
    CALL ClearScreen
    CALL CartModule
    JMP MENU_LOOP

; should loop history until the user said to quit
OPT_HISTORY:
    CALL ClearScreen
    CALL HistoryModule
    JMP MENU_LOOP

OPT_LOGOUT:
    CALL ClearScreen
    CALL Logout
    RET"""

OPT_QUIT:
    CALL ExitProgram    ; Calls cleanup/exit
    MOV AX, 4C00H       ; Terminate process completely
    INT 21H
PostLoginMenu ENDP


END main
