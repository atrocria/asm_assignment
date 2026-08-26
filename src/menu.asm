.MODEL SMALL

PUBLIC OrderModule

EXTRN qty_burger:BYTE, qty_nasi:BYTE, qty_rice:BYTE, qty_chicken:BYTE
EXTRN total_price:WORD

.DATA
    ; Added 0DH, 0AH at the top to clear edge artifacts
    food_menu_msg   DB 0DH,0AH
                    DB 0DH,0AH,'=== FOOD MENU / PLACE ORDER ===',0DH,0AH
                    DB '  1. BURGER (RM5)',0DH,0AH
                    DB '  2. NASI LEMAK (RM14)',0DH,0AH
                    DB '  3. EGG FRIED RICE (RM7)',0DH,0AH
                    DB '  4. 2pcs FRIED CHICKEN (RM6)',0DH,0AH
                    DB '  5. Back to Main Menu',0DH,0AH
                    DB 'Select an option: $'
                    
    msg_burger      DB 0DH,0AH,'Burger added to cart!',0DH,0AH,'$'
    msg_nasi_lemak  DB 0DH,0AH,'Nasi Lemak added to cart!',0DH,0AH,'$'
    msg_fried_rice  DB 0DH,0AH,'Egg Fried Rice added to cart!',0DH,0AH,'$'
    msg_chicken     DB 0DH,0AH,'2pcs fried chicken added to cart',0DH,0AH,'$'
    msg_invalid     DB 0DH,0AH,'Invalid option! Try again.',0DH,0AH,'$'
    
    pause_msg       DB 0DH,0AH,'Press any key to continue...$',0DH,0AH

.CODE
OrderModule PROC NEAR
EXTRN ClearScreen:NEAR

FOOD_LOOP:

    CALL ClearScreen
    LEA DX, food_menu_msg
    MOV AH, 09H
    INT 21H

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
    JE EXIT_FOOD_MENU

    LEA DX, msg_invalid
    MOV AH, 09H
    INT 21H
    CALL WAIT_KEY
    JMP FOOD_LOOP

ITEM_BURGER:
    INC qty_burger
    ADD WORD PTR total_price, 5
    LEA DX, msg_burger
    MOV AH, 09H
    INT 21H
    CALL WAIT_KEY
    JMP FOOD_LOOP

ITEM_NASI_LEMAK:
    INC qty_nasi
    ADD WORD PTR total_price, 14
    LEA DX, msg_nasi_lemak
    MOV AH, 09H
    INT 21H
    CALL WAIT_KEY          ; Pauses so screen doesn't clear instantly
    JMP FOOD_LOOP          ; Loops back to Food Menu

ITEM_FRIED_RICE:
    INC qty_rice
    ADD WORD PTR total_price, 7
    LEA DX, msg_fried_rice
    MOV AH, 09H
    INT 21H
    CALL WAIT_KEY
    JMP FOOD_LOOP

ITEM_FRIED_CHICKEN:
    INC qty_chicken
    ADD WORD PTR total_price, 6
    LEA DX, msg_chicken
    MOV AH, 09H
    INT 21H
    CALL WAIT_KEY
    JMP FOOD_LOOP

EXIT_FOOD_MENU:
    RET
OrderModule ENDP

WAIT_KEY PROC NEAR
    LEA DX, pause_msg
    MOV AH, 09H
    INT 21H
    MOV AH, 07H
    INT 21H
    RET
WAIT_KEY ENDP

END