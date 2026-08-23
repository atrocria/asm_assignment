.MODEL SMALL

.DATA

; =============================================================
; FOOD MENU
; =============================================================

menu_title DB 0DH,0AH
           DB '=============================================================',0DH,0AH
           DB '                         FOOD MENU                           ',0DH,0AH
           DB '=============================================================',0DH,0AH
           DB '$'

menu_items DB '1. Chicken Rice              RM 8.00',0DH,0AH
           DB '2. Nasi Lemak                RM 7.00',0DH,0AH
           DB '3. Beef Burger               RM 10.00',0DH,0AH
           DB '4. Chicken Burger            RM 9.00',0DH,0AH
           DB '5. French Fries              RM 5.00',0DH,0AH
           DB '6. Fried Chicken             RM 8.00',0DH,0AH
           DB '7. Spaghetti                 RM 12.00',0DH,0AH
           DB '8. Iced Milo                 RM 4.00',0DH,0AH
           DB '9. Cola                      RM 3.00',0DH,0AH
           DB '10. Mineral Water            RM 2.00',0DH,0AH
           DB '$'

menu_footer DB '=============================================================',0DH,0AH
            DB '0. Back',0DH,0AH
            DB 'Choose an item: $'


; =============================================================
; SELECTION MESSAGES
; =============================================================

chicken_rice_msg DB 0DH,0AH
                 DB 'Chicken Rice selected.',0DH,0AH
                 DB '$'

nasi_lemak_msg DB 0DH,0AH
               DB 'Nasi Lemak selected.',0DH,0AH
               DB '$'

beef_burger_msg DB 0DH,0AH
                DB 'Beef Burger selected.',0DH,0AH
                DB '$'

chicken_burger_msg DB 0DH,0AH
                   DB 'Chicken Burger selected.',0DH,0AH
                   DB '$'

fries_msg DB 0DH,0AH
          DB 'French Fries selected.',0DH,0AH
          DB '$'

fried_chicken_msg DB 0DH,0AH
                  DB 'Fried Chicken selected.',0DH,0AH
                  DB '$'

spaghetti_msg DB 0DH,0AH
              DB 'Spaghetti selected.',0DH,0AH
              DB '$'

milo_msg DB 0DH,0AH
         DB 'Iced Milo selected.',0DH,0AH
         DB '$'

cola_msg DB 0DH,0AH
         DB 'Cola selected.',0DH,0AH
         DB '$'


; =============================================================
; CODE
; =============================================================

.CODE

EXTRN ClearScreen:NEAR

PUBLIC OrderModule


; =============================================================
; ORDER MODULE
; =============================================================

OrderModule PROC NEAR

CALL ClearScreen

ORDER_LOOP:

    ; ---------------------------------------------------------
    ; Display menu title
    ; ---------------------------------------------------------

    LEA DX, menu_title
    MOV AH, 09H
    INT 21H


    ; ---------------------------------------------------------
    ; Display menu items
    ; ---------------------------------------------------------

    LEA DX, menu_items
    MOV AH, 09H
    INT 21H


    ; ---------------------------------------------------------
    ; Display footer
    ; ---------------------------------------------------------

    LEA DX, menu_footer
    MOV AH, 09H
    INT 21H


    ; ---------------------------------------------------------
    ; Read user's choice
    ; AH = 01H
    ; AL = key pressed
    ; ---------------------------------------------------------

    MOV AH, 01H
    INT 21H


    ; ---------------------------------------------------------
    ; Check 0
    ; ---------------------------------------------------------

    CMP AL, '0'
    JNE CHECK_1

    JMP ORDER_EXIT


CHECK_1:

    ; ---------------------------------------------------------
    ; Check 1
    ; ---------------------------------------------------------

    CMP AL, '1'
    JNE CHECK_2

    JMP ITEM_1


CHECK_2:

    ; ---------------------------------------------------------
    ; Check 2
    ; ---------------------------------------------------------

    CMP AL, '2'
    JNE CHECK_3

    JMP ITEM_2


CHECK_3:

    ; ---------------------------------------------------------
    ; Check 3
    ; ---------------------------------------------------------

    CMP AL, '3'
    JNE CHECK_4

    JMP ITEM_3


CHECK_4:

    ; ---------------------------------------------------------
    ; Check 4
    ; ---------------------------------------------------------

    CMP AL, '4'
    JNE CHECK_5

    JMP ITEM_4


CHECK_5:

    ; ---------------------------------------------------------
    ; Check 5
    ; ---------------------------------------------------------

    CMP AL, '5'
    JNE CHECK_6

    JMP ITEM_5


CHECK_6:

    ; ---------------------------------------------------------
    ; Check 6
    ; ---------------------------------------------------------

    CMP AL, '6'
    JNE CHECK_7

    JMP ITEM_6


CHECK_7:

    ; ---------------------------------------------------------
    ; Check 7
    ; ---------------------------------------------------------

    CMP AL, '7'
    JNE CHECK_8

    JMP ITEM_7


CHECK_8:

    ; ---------------------------------------------------------
    ; Check 8
    ; ---------------------------------------------------------

    CMP AL, '8'
    JNE CHECK_9

    JMP ITEM_8


CHECK_9:

    ; ---------------------------------------------------------
    ; Check 9
    ; ---------------------------------------------------------

    CMP AL, '9'
    JNE INVALID_CHOICE

    JMP ITEM_9


; =============================================================
; INVALID INPUT
; =============================================================

INVALID_CHOICE:

    CALL ClearScreen
    JMP ORDER_LOOP


; =============================================================
; ITEM 1 - CHICKEN RICE
; =============================================================

ITEM_1:

    CALL ClearScreen
    LEA DX, chicken_rice_msg
    MOV AH, 09H
    INT 21H

    JMP ORDER_LOOP


; =============================================================
; ITEM 2 - NASI LEMAK
; =============================================================

ITEM_2:

    CALL ClearScreen
    LEA DX, nasi_lemak_msg
    MOV AH, 09H
    INT 21H

    JMP ORDER_LOOP


; =============================================================
; ITEM 3 - BEEF BURGER
; =============================================================

ITEM_3:

    CALL ClearScreen
    LEA DX, beef_burger_msg
    MOV AH, 09H
    INT 21H

    JMP ORDER_LOOP


; =============================================================
; ITEM 4 - CHICKEN BURGER
; =============================================================

ITEM_4:

    CALL ClearScreen
    LEA DX, chicken_burger_msg
    MOV AH, 09H
    INT 21H

    JMP ORDER_LOOP


; =============================================================
; ITEM 5 - FRENCH FRIES
; =============================================================

ITEM_5:

    CALL ClearScreen
    LEA DX, fries_msg
    MOV AH, 09H
    INT 21H

    JMP ORDER_LOOP


; =============================================================
; ITEM 6 - FRIED CHICKEN
; =============================================================

ITEM_6:

    CALL ClearScreen
    LEA DX, fried_chicken_msg
    MOV AH, 09H
    INT 21H

    JMP ORDER_LOOP


; =============================================================
; ITEM 7 - SPAGHETTI
; =============================================================

ITEM_7:

    CALL ClearScreen
    LEA DX, spaghetti_msg
    MOV AH, 09H
    INT 21H

    JMP ORDER_LOOP


; =============================================================
; ITEM 8 - ICED MILO
; =============================================================

ITEM_8:

    CALL ClearScreen
    LEA DX, milo_msg
    MOV AH, 09H
    INT 21H

    JMP ORDER_LOOP


; =============================================================
; ITEM 9 - COLA
; =============================================================

ITEM_9:

    CALL ClearScreen
    LEA DX, cola_msg
    MOV AH, 09H
    INT 21H

    JMP ORDER_LOOP


; =============================================================
; RETURN TO MAIN MENU
; =============================================================

ORDER_EXIT:

    RET


OrderModule ENDP

END