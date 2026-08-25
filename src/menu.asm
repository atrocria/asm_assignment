.MODEL SMALL

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
    MOV AH, 09H
    INT 21H

    MOV AH, 01H
    INT 21H

    CMP AL, '1'
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

END