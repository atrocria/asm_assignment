; =================================================================
; menu.asm
;
; The food menu screen: shows the 4 items, lets the user pick one
; to add to the cart, or "5" to go back. Prices and the proximity
; discount math both live in cart.asm (see CALC_PRICE there) - this
; file just calls into that so the discount is worked out the exact
; same way everywhere it shows up.
; =================================================================

.MODEL SMALL

PUBLIC OrderModule

EXTRN qty_burger:BYTE, qty_nasi:BYTE, qty_rice:BYTE, qty_chicken:BYTE
EXTRN total_price:WORD
EXTRN PRICE_BURGER:WORD, PRICE_NASI:WORD, PRICE_RICE:WORD, PRICE_CHICKEN:WORD
EXTRN DISCOUNT_TOTAL:WORD

EXTRN CALC_PRICE:NEAR, PRINT_NUM:NEAR   ; from cart.asm / tools.asm
EXTRN PRINT_STRING:NEAR                 ; from tools.asm
EXTRN ClearScreen:NEAR                  ; from tools.asm

.DATA
    FOOD_HEADER     DB 0DH,0AH,0DH,0AH,'=== FOOD MENU / PLACE ORDER ===',0DH,0AH,'$'
    ITEM_BURGER_MSG   DB '  1. BURGER (RM5)$'
    ITEM_NASI_MSG     DB '  2. NASI LEMAK (RM14)$'
    ITEM_RICE_MSG     DB '  3. EGG FRIED RICE (RM7)$'
    ITEM_CHICKEN_MSG  DB '  4. 2pcs FRIED CHICKEN (RM6)$'
    ; printed right after an item's line, only when it qualifies for
    ; the proximity discount - see PRINT_DISCOUNT_LINE below
    DISCOUNT_LINE_PREFIX DB ' -> RM$'
    DISCOUNT_LINE_SUFFIX DB ' (10% OFF)',0DH,0AH,'$'
    ; printed instead of the discount line when an item has no
    ; discount, so the cursor still moves to the next line
    NEWLINE_MSG          DB 0DH,0AH,'$'
    FOOD_FOOTER     DB '  5. Back to Main Menu',0DH,0AH,'Select an option: $'

    msg_burger      DB 0DH,0AH,'Burger added to cart!',0DH,0AH,'$'
    msg_nasi_lemak  DB 0DH,0AH,'Nasi Lemak added to cart!',0DH,0AH,'$'
    msg_fried_rice  DB 0DH,0AH,'Egg Fried Rice added to cart!',0DH,0AH,'$'
    msg_chicken     DB 0DH,0AH,'2pcs fried chicken added to cart',0DH,0AH,'$'
    msg_invalid     DB 0DH,0AH,'Invalid option! Try again.',0DH,0AH,'$'

    pause_msg       DB 0DH,0AH,'Press any key to continue...$',0DH,0AH

.CODE
OrderModule PROC NEAR
FOOD_LOOP:
    CALL ClearScreen
    LEA DX, FOOD_HEADER
    CALL PRINT_STRING

    LEA DX, ITEM_BURGER_MSG
    CALL PRINT_STRING
    MOV AX, PRICE_BURGER
    CALL PRINT_DISCOUNT_LINE

    LEA DX, ITEM_NASI_MSG
    CALL PRINT_STRING
    MOV AX, PRICE_NASI
    CALL PRINT_DISCOUNT_LINE

    LEA DX, ITEM_RICE_MSG
    CALL PRINT_STRING
    MOV AX, PRICE_RICE
    CALL PRINT_DISCOUNT_LINE

    LEA DX, ITEM_CHICKEN_MSG
    CALL PRINT_STRING
    MOV AX, PRICE_CHICKEN
    CALL PRINT_DISCOUNT_LINE

    LEA DX, FOOD_FOOTER
    CALL PRINT_STRING

    MOV AH, 01H
    INT 21H

    CMP AL, '1'
    JE ITEM_BURGER

    CMP AL, '2'
    JE ITEM_NASI_LEMAK     ; Make sure this goes to ITEM_NASI_LEMAK, NOT EXIT_FOOD_MENU!

    CMP AL, '3'
    JE ITEM_FRIED_RICE

    CMP AL, '4'
    JE ITEM_FRIED_CHICKEN

    CMP AL, '5'
    JNE FOOD_NOT_EXIT
    JMP EXIT_FOOD_MENU        ; JMP has no short-jump range limit, unlike JE
FOOD_NOT_EXIT:

    LEA DX, msg_invalid
    CALL PRINT_STRING
    CALL WAIT_KEY
    JMP FOOD_LOOP

ITEM_BURGER:
    MOV AX, PRICE_BURGER
    CALL CALC_PRICE             ; AX = price to charge, BX = amount saved
    ADD total_price, AX
    ADD DISCOUNT_TOTAL, BX
    INC qty_burger
    LEA DX, msg_burger
    CALL PRINT_STRING
    CALL WAIT_KEY
    JMP FOOD_LOOP

ITEM_NASI_LEMAK:
    MOV AX, PRICE_NASI
    CALL CALC_PRICE
    ADD total_price, AX
    ADD DISCOUNT_TOTAL, BX
    INC qty_nasi
    LEA DX, msg_nasi_lemak
    CALL PRINT_STRING
    CALL WAIT_KEY          ; Pauses so screen doesn't clear instantly
    JMP FOOD_LOOP          ; Loops back to Food Menu

ITEM_FRIED_RICE:
    MOV AX, PRICE_RICE
    CALL CALC_PRICE
    ADD total_price, AX
    ADD DISCOUNT_TOTAL, BX
    INC qty_rice
    LEA DX, msg_fried_rice
    CALL PRINT_STRING
    CALL WAIT_KEY
    JMP FOOD_LOOP

ITEM_FRIED_CHICKEN:
    MOV AX, PRICE_CHICKEN
    CALL CALC_PRICE
    ADD total_price, AX
    ADD DISCOUNT_TOTAL, BX
    INC qty_chicken
    LEA DX, msg_chicken
    CALL PRINT_STRING
    CALL WAIT_KEY
    JMP FOOD_LOOP

EXIT_FOOD_MENU:
    RET
OrderModule ENDP

; --- Prints the discounted price right after the item on the same
;     line, but only if this session qualifies for the proximity
;     discount. Either way, ends the line so the next item starts
;     on a fresh line. ---
; IN: AX = that item's base price
PRINT_DISCOUNT_LINE PROC NEAR
    CALL CALC_PRICE            ; AX = price to charge, BX = amount saved
    CMP BX, 0
    JE  PDL_NONE
    PUSH AX                     ; keep the discounted price safe
    LEA DX, DISCOUNT_LINE_PREFIX
    CALL PRINT_STRING
    POP AX
    CALL PRINT_NUM
    LEA DX, DISCOUNT_LINE_SUFFIX
    CALL PRINT_STRING
    RET
PDL_NONE:
    LEA DX, NEWLINE_MSG          ; no discount - still need to end the line
    CALL PRINT_STRING
    RET
PRINT_DISCOUNT_LINE ENDP

WAIT_KEY PROC NEAR
    LEA DX, pause_msg
    CALL PRINT_STRING
    MOV AH, 07H
    INT 21H
    RET
WAIT_KEY ENDP

END
