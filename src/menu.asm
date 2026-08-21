.MODEL SMALL
.STACK 100H

.DATA

; =============================================================
; ORDERING MENU
; =============================================================

ordering_menu_msg DB 0DH,0AH
                  DB '=============================================================',0DH,0AH
                  DB '                       PLACE ORDER                         ',0DH,0AH
                  DB '=============================================================',0DH,0AH
                  DB '1. View Food Menu',0DH,0AH
                  DB '2. Add Item to Cart',0DH,0AH
                  DB '3. Remove Item from Cart',0DH,0AH
                  DB '4. View Current Order',0DH,0AH
                  DB '5. Confirm Order',0DH,0AH
                  DB '6. Back to Main Menu',0DH,0AH
                  DB '=============================================================',0DH,0AH
                  DB 'Choose an option: $'


; =============================================================
; FOOD MENU
; =============================================================

food_menu_msg DB 0DH,0AH
              DB '=============================================================',0DH,0AH
              DB '                         FOOD MENU                         ',0DH,0AH
              DB '=============================================================',0DH,0AH
              DB '1. Chicken Rice       - RM 8',0DH,0AH
              DB '2. Nasi Lemak         - RM 7',0DH,0AH
              DB '3. Fried Rice         - RM 9',0DH,0AH
              DB '4. Chicken Burger     - RM 10',0DH,0AH
              DB '5. French Fries       - RM 5',0DH,0AH
              DB '6. Soft Drink         - RM 3',0DH,0AH
              DB '7. Back',0DH,0AH
              DB '=============================================================',0DH,0AH
              DB 'Choose an item: $'


; =============================================================
; OTHER MESSAGES
; =============================================================

quantity_msg DB 0DH,0AH
             DB 'Enter quantity (1-9): $'

added_msg DB 0DH,0AH
          DB 'Item added to cart.',0DH,0AH
          DB 'Press any key to continue...$'

removed_msg DB 0DH,0AH
            DB 'Item removed from cart.',0DH,0AH
            DB 'Press any key to continue...$'

invalid_msg DB 0DH,0AH
            DB 'Invalid option.',0DH,0AH
            DB 'Press any key to continue...$'

empty_cart_msg DB 0DH,0AH
               DB 'Your cart is empty.',0DH,0AH
               DB 'Press any key to continue...$'

confirm_msg DB 0DH,0AH
            DB 'Confirm this order? (Y/N): $'

order_confirmed_msg DB 0DH,0AH
                    DB 'Order confirmed successfully!',0DH,0AH
                    DB 'Press any key to continue...$'

current_order_msg DB 0DH,0AH
                  DB '=============================================================',0DH,0AH
                  DB '                     CURRENT ORDER                         ',0DH,0AH
                  DB '=============================================================',0DH,0AH

newline_msg DB 0DH,0AH,'$'


; =============================================================
; CART DATA
;
; Each item stores the quantity ordered.
;
; 0 = Chicken Rice
; 1 = Nasi Lemak
; 2 = Fried Rice
; 3 = Chicken Burger
; 4 = French Fries
; 5 = Soft Drink
; =============================================================

chicken_rice_qty   DB 0
nasi_lemak_qty     DB 0
fried_rice_qty     DB 0
chicken_burger_qty DB 0
fries_qty           DB 0
drink_qty           DB 0


.CODE

; =============================================================
; EXTERNAL PROCEDURES
; =============================================================

EXTRN ClearScreen:NEAR

PUBLIC OrderModule


; =============================================================
; ORDER MODULE
;
; This procedure is called from main.asm when the user selects
; "Place Order".
; =============================================================

OrderModule PROC NEAR

ORDER_MENU_LOOP:

    CALL ClearScreen

    LEA DX, ordering_menu_msg
    MOV AH, 09H
    INT 21H

    ; Get menu choice
    MOV AH, 01H
    INT 21H

    CMP AL, '1'
    JE VIEW_FOOD_MENU

    CMP AL, '2'
    JE ADD_ITEM

    CMP AL, '3'
    JE REMOVE_ITEM

    CMP AL, '4'
    JE VIEW_CURRENT_ORDER

    CMP AL, '5'
    JE CONFIRM_ORDER

    CMP AL, '6'
    JE BACK_TO_MAIN

    ; Invalid option
    CALL InvalidOption
    JMP ORDER_MENU_LOOP


; =============================================================
; VIEW FOOD MENU
; =============================================================

VIEW_FOOD_MENU:

    CALL ClearScreen

    LEA DX, food_menu_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    CMP AL, '7'
    JE ORDER_MENU_LOOP

    ; Simply return to ordering menu for now
    JMP ORDER_MENU_LOOP


; =============================================================
; ADD ITEM
; =============================================================

ADD_ITEM:

    CALL ClearScreen

    LEA DX, food_menu_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    CMP AL, '1'
    JE ADD_CHICKEN_RICE

    CMP AL, '2'
    JE ADD_NASI_LEMAK

    CMP AL, '3'
    JE ADD_FRIED_RICE

    CMP AL, '4'
    JE ADD_CHICKEN_BURGER

    CMP AL, '5'
    JE ADD_FRIES

    CMP AL, '6'
    JE ADD_DRINK

    CMP AL, '7'
    JE ORDER_MENU_LOOP

    CALL InvalidOption
    JMP ORDER_MENU_LOOP


; =============================================================
; ADD CHICKEN RICE
; =============================================================

ADD_CHICKEN_RICE:

    LEA DX, quantity_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    SUB AL, '0'
    MOV chicken_rice_qty, AL

    CALL ItemAdded
    JMP ORDER_MENU_LOOP


; =============================================================
; ADD NASI LEMAK
; =============================================================

ADD_NASI_LEMAK:

    LEA DX, quantity_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    SUB AL, '0'
    MOV nasi_lemak_qty, AL

    CALL ItemAdded
    JMP ORDER_MENU_LOOP


; =============================================================
; ADD FRIED RICE
; =============================================================

ADD_FRIED_RICE:

    LEA DX, quantity_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    SUB AL, '0'
    MOV fried_rice_qty, AL

    CALL ItemAdded
    JMP ORDER_MENU_LOOP


; =============================================================
; ADD CHICKEN BURGER
; =============================================================

ADD_CHICKEN_BURGER:

    LEA DX, quantity_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    SUB AL, '0'
    MOV chicken_burger_qty, AL

    CALL ItemAdded
    JMP ORDER_MENU_LOOP


; =============================================================
; ADD FRIES
; =============================================================

ADD_FRIES:

    LEA DX, quantity_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    SUB AL, '0'
    MOV fries_qty, AL

    CALL ItemAdded
    JMP ORDER_MENU_LOOP


; =============================================================
; ADD DRINK
; =============================================================

ADD_DRINK:

    LEA DX, quantity_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    SUB AL, '0'
    MOV drink_qty, AL

    CALL ItemAdded
    JMP ORDER_MENU_LOOP


; =============================================================
; REMOVE ITEM
; =============================================================

REMOVE_ITEM:

    CALL ClearScreen

    LEA DX, food_menu_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    CMP AL, '1'
    JE REMOVE_CHICKEN_RICE

    CMP AL, '2'
    JE REMOVE_NASI_LEMAK

    CMP AL, '3'
    JE REMOVE_FRIED_RICE

    CMP AL, '4'
    JE REMOVE_CHICKEN_BURGER

    CMP AL, '5'
    JE REMOVE_FRIES

    CMP AL, '6'
    JE REMOVE_DRINK

    CMP AL, '7'
    JE ORDER_MENU_LOOP

    CALL InvalidOption
    JMP ORDER_MENU_LOOP


REMOVE_CHICKEN_RICE:

    MOV chicken_rice_qty, 0
    CALL ItemRemoved
    JMP ORDER_MENU_LOOP


REMOVE_NASI_LEMAK:

    MOV nasi_lemak_qty, 0
    CALL ItemRemoved
    JMP ORDER_MENU_LOOP


REMOVE_FRIED_RICE:

    MOV fried_rice_qty, 0
    CALL ItemRemoved
    JMP ORDER_MENU_LOOP


REMOVE_CHICKEN_BURGER:

    MOV chicken_burger_qty, 0
    CALL ItemRemoved
    JMP ORDER_MENU_LOOP


REMOVE_FRIES:

    MOV fries_qty, 0
    CALL ItemRemoved
    JMP ORDER_MENU_LOOP


REMOVE_DRINK:

    MOV drink_qty, 0
    CALL ItemRemoved
    JMP ORDER_MENU_LOOP


; =============================================================
; VIEW CURRENT ORDER
; =============================================================

VIEW_CURRENT_ORDER:

    CALL ClearScreen

    LEA DX, current_order_msg
    MOV AH, 09H
    INT 21H

    ; Chicken Rice
    CMP chicken_rice_qty, 0
    JE CHECK_NASI_LEMAK

    MOV AL, chicken_rice_qty
    CALL DisplayQuantity

    LEA DX, newline_msg
    MOV AH, 09H
    INT 21H


CHECK_NASI_LEMAK:

    CMP nasi_lemak_qty, 0
    JE CHECK_FRIED_RICE

    MOV AL, nasi_lemak_qty
    CALL DisplayQuantity

    LEA DX, newline_msg
    MOV AH, 09H
    INT 21H


CHECK_FRIED_RICE:

    CMP fried_rice_qty, 0
    JE CHECK_BURGER

    MOV AL, fried_rice_qty
    CALL DisplayQuantity

    LEA DX, newline_msg
    MOV AH, 09H
    INT 21H


CHECK_BURGER:

    CMP chicken_burger_qty, 0
    JE CHECK_FRIES

    MOV AL, chicken_burger_qty
    CALL DisplayQuantity

    LEA DX, newline_msg
    MOV AH, 09H
    INT 21H


CHECK_FRIES:

    CMP fries_qty, 0
    JE CHECK_DRINK

    MOV AL, fries_qty
    CALL DisplayQuantity

    LEA DX, newline_msg
    MOV AH, 09H
    INT 21H


CHECK_DRINK:

    CMP drink_qty, 0
    JE ORDER_MENU_LOOP

    MOV AL, drink_qty
    CALL DisplayQuantity

    LEA DX, newline_msg
    MOV AH, 09H
    INT 21H

    JMP ORDER_MENU_LOOP


; =============================================================
; CONFIRM ORDER
; =============================================================

CONFIRM_ORDER:

    LEA DX, confirm_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    CMP AL, 'Y'
    JE CONFIRM_YES

    CMP AL, 'y'
    JE CONFIRM_YES

    JMP ORDER_MENU_LOOP


CONFIRM_YES:

    CALL ClearCart

    LEA DX, order_confirmed_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 08H
    INT 21H

    JMP ORDER_MENU_LOOP


; =============================================================
; BACK TO MAIN MENU
; =============================================================

BACK_TO_MAIN:

    RET


; =============================================================
; ITEM ADDED MESSAGE
; =============================================================

ItemAdded PROC NEAR

    LEA DX, added_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 08H
    INT 21H

    RET

ItemAdded ENDP


; =============================================================
; ITEM REMOVED MESSAGE
; =============================================================

ItemRemoved PROC NEAR

    LEA DX, removed_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 08H
    INT 21H

    RET

ItemRemoved ENDP


; =============================================================
; INVALID OPTION
; =============================================================

InvalidOption PROC NEAR

    LEA DX, invalid_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 08H
    INT 21H

    RET

InvalidOption ENDP


; =============================================================
; CLEAR CART
; =============================================================

ClearCart PROC NEAR

    MOV chicken_rice_qty, 0
    MOV nasi_lemak_qty, 0
    MOV fried_rice_qty, 0
    MOV chicken_burger_qty, 0
    MOV fries_qty, 0
    MOV drink_qty, 0

    RET

ClearCart ENDP


; =============================================================
; DISPLAY QUANTITY
;
; AL = quantity
; =============================================================

DisplayQuantity PROC NEAR

    ADD AL, '0'

    MOV DL, AL
    MOV AH, 02H
    INT 21H

    RET

DisplayQuantity ENDP


OrderModule ENDP

END