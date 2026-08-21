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

    ; =========================================================
    ; !TEMPORARY MODULE MESSAGES
    ; =========================================================

    order_msg       DB 0DH,0AH
                    DB '----------------------------------------',0DH,0AH
                    DB '             PLACE ORDER                ',0DH,0AH
                    DB '----------------------------------------',0DH,0AH
                    DB 'Order module is ready.',0DH,0AH
                    DB 'Press any key to return to Main Menu...$'

    cart_msg        DB 0DH,0AH
                    DB '----------------------------------------',0DH,0AH
                    DB '              VIEW CART                 ',0DH,0AH
                    DB '----------------------------------------',0DH,0AH
                    DB 'Cart module is ready.',0DH,0AH
                    DB 'Press any key to return to Main Menu...$'

    history_msg     DB 0DH,0AH
                    DB '----------------------------------------',0DH,0AH
                    DB '            ORDER HISTORY               ',0DH,0AH
                    DB '----------------------------------------',0DH,0AH
                    DB 'Order history module is ready.',0DH,0AH
                    DB 'Press any key to return to Main Menu...$'

.CODE

    ; Login module entry points.
    EXTRN LoginMenu:NEAR
    EXTRN Logout:NEAR

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
    INT 21H"""

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
    CALL CartModule
    JMP MENU_LOOP

; should loop history until the user said to quit
OPT_HISTORY:
    CALL HistoryModule
    JMP MENU_LOOP

OPT_LOGOUT:
    CALL Logout
    RET

OPT_QUIT:
    CALL ExitProgram
PostLoginMenu ENDP


; =============================================================
; !PLACEHOLDER MODULES
;
; Replace these calls with the completed order/cart/history modules
; when those modules expose their public procedures.
; =============================================================

OrderModule PROC NEAR
    CALL ClearScreen
    LEA DX, order_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 08H
    INT 21H
    RET
OrderModule ENDP


CartModule PROC NEAR
    CALL ClearScreen
    LEA DX, cart_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 08H
    INT 21H
    RET
CartModule ENDP


HistoryModule PROC NEAR
    CALL ClearScreen
    LEA DX, history_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 08H
    INT 21H
    RET
HistoryModule ENDP

END main
