.MODEL SMALL

<<<<<<< HEAD
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
FOOD_LOOP:
    LEA DX, food_menu_msg
=======
.DATA

ITEM_QUANTITY   DB 9 DUP(0)          ; quantity chosen per item (index 0 = item 1)
ITEM_PRICE      DW 800,700,1000,900,500,800,1200,400,300   ; price in cents (RM x100)
current_item    DB 0                 ; item number (1-9) currently being processed

menu_title DB 0DH,0AH
           DB '=============================================================',0DH,0AH
           DB '                         FOOD MENU                           ',0DH,0AH
           DB '=============================================================',0DH,0AH
           DB '$'

menu_items DB '         1. Chicken Rice              RM 8.00 x',0DH,0AH
           DB '         2. Nasi Lemak                RM 7.00 x',0DH,0AH
           DB '         3. Beef Burger               RM 10.00 x',0DH,0AH
           DB '         4. Chicken Burger            RM 9.00 x',0DH,0AH
           DB '         5. French Fries              RM 5.00 x',0DH,0AH
           DB '         6. Fried Chicken             RM 8.00 x',0DH,0AH
           DB '         7. Spaghetti                 RM 12.00 x',0DH,0AH
           DB '         8. Iced Milo                 RM 4.00 x',0DH,0AH
           DB '         9. Cola                      RM 3.00 x',0DH,0AH
           DB '$'

menu_footer DB '=============================================================',0DH,0AH
            DB '         0. Back',0DH,0AH

choose_itm DB '         Choose an item: $'

; ---- Per-item "selected" messages (data only) ----
msg1 DB 0DH,0AH,'Chicken Rice selected.',0DH,0AH,'$'
msg2 DB 0DH,0AH,'Nasi Lemak selected.',0DH,0AH,'$'
msg3 DB 0DH,0AH,'Beef Burger selected.',0DH,0AH,'$'
msg4 DB 0DH,0AH,'Chicken Burger selected.',0DH,0AH,'$'
msg5 DB 0DH,0AH,'French Fries selected.',0DH,0AH,'$'
msg6 DB 0DH,0AH,'Fried Chicken selected.',0DH,0AH,'$'
msg7 DB 0DH,0AH,'Spaghetti selected.',0DH,0AH,'$'
msg8 DB 0DH,0AH,'Iced Milo selected.',0DH,0AH,'$'
msg9 DB 0DH,0AH,'Cola selected.',0DH,0AH,'$'

; table of pointers, indexed by (item_number - 1)
item_msg_table DW OFFSET msg1, OFFSET msg2, OFFSET msg3
               DW OFFSET msg4, OFFSET msg5, OFFSET msg6
               DW OFFSET msg7, OFFSET msg8, OFFSET msg9

qty_prompt      DB 0DH,0AH,'         Enter quantity (1-9): $'
invalid_qty_msg DB 0DH,0AH,'         Invalid quantity! Please enter 1-9.',0DH,0AH,'$'
qty_set_msg     DB 0DH,0AH,'         Quantity updated. Press any key...',0DH,0AH,'$'

; ______________________________________________________________________________________________________________________ code
.CODE

EXTRN ClearScreen:NEAR

PUBLIC OrderModule

; ORDER MODULE
OrderModule PROC NEAR

CALL ClearScreen

ORDER_LOOP:

    ; Display menu title / items / footer / prompt
    LEA DX, menu_title
    MOV AH, 09H
    INT 21H

    LEA DX, menu_items
    MOV AH, 09H
    INT 21H

    LEA DX, menu_footer
    MOV AH, 09H
    INT 21H

    LEA DX, choose_itm
    MOV AH, 09H
    INT 21H

    ; Read user's choice
    MOV AH, 01H
    INT 21H

    ; --- Range check instead of a 9-way cascade ---
    CMP AL, '0'
    JE ORDER_EXIT

    CMP AL, '1'
    JB INVALID_CHOICE

    CMP AL, '9'
    JA INVALID_CHOICE

    ; AL is '1'..'9' -> convert to item number 1-9
    SUB AL, '0'
    MOV current_item, AL

    CALL ClearScreen

    ; --- Look up and display the "selected" message via the table ---
    MOV BL, AL
    DEC BL                  ; zero-based index
    MOV BH, 0
    SHL BX, 1                ; word-sized entries
    MOV DX, item_msg_table[BX]
    MOV AH, 09H
    INT 21H

    ; --- Get quantity (shared routine, no per-item duplication) ---
    CALL GetQuantity          ; returns validated quantity (1-9) in AL

    ; Store into ITEM_QUANTITY[current_item - 1]
    MOV BL, current_item
    DEC BL
    MOV BH, 0
    MOV ITEM_QUANTITY[BX], AL

    LEA DX, qty_set_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    CALL ClearScreen
    JMP ORDER_LOOP

INVALID_CHOICE:
    CALL ClearScreen
    JMP ORDER_LOOP

ORDER_EXIT:
    RET

OrderModule ENDP


; ---------------------------------------------------------------------
; GetQuantity: prompts and validates a quantity between 1 and 9.
; Reusable for every menu item -- eliminates per-item duplication.
; Returns: AL = quantity (1-9)
; ---------------------------------------------------------------------
GetQuantity PROC NEAR

GETQTY_LOOP:
    LEA DX, qty_prompt
>>>>>>> bb64b397b2df7367edf267ddd160c393501af2de
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    CMP AL, '1'
<<<<<<< HEAD
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
=======
    JB GETQTY_INVALID

    CMP AL, '9'
    JA GETQTY_INVALID

    SUB AL, '0'
    RET

GETQTY_INVALID:
    LEA DX, invalid_qty_msg
    MOV AH, 09H
    INT 21H
    JMP GETQTY_LOOP

GetQuantity ENDP
>>>>>>> bb64b397b2df7367edf267ddd160c393501af2de

END