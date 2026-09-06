; =================================================================
; cart.asm
;
; Owns the shopping cart: what's in it (qty_burger etc.), the
; running total (total_price), and - since it's the one place that
; knows what everything costs - the item prices themselves
; (PRICE_BURGER etc.) and the 10% "proximity discount" math
; (CALC_PRICE). menu.asm calls CALC_PRICE when adding an item so
; the discount is worked out exactly the same way everywhere it's
; used; checkout.asm reads DISCOUNT_TOTAL to show how much of the
; final bill was saved that way.
;
; The discount itself depends on CURRENT_DISCOUNT, a flag login.asm
; sets to 1 when the logged-in account's saved address is close
; enough to DeliGo (see login.asm for exactly which addresses
; qualify).
; =================================================================

.MODEL SMALL

PUBLIC qty_burger, qty_nasi, qty_rice, qty_chicken, total_price
PUBLIC PRICE_BURGER, PRICE_NASI, PRICE_RICE, PRICE_CHICKEN
PUBLIC DISCOUNT_TOTAL
PUBLIC CartModule, CALC_PRICE

EXTRN CheckoutModule:NEAR       ; from checkout.asm
EXTRN CURRENT_DISCOUNT:BYTE     ; from login.asm - does this session get 10% off?
EXTRN PRINT_STRING:NEAR, PRINT_NUM:NEAR   ; from tools.asm

.DATA
    cart_header   DB 0DH,0AH,'==================================',0DH,0AH
                  DB '           YOUR SHOPPING CART         ',0DH,0AH
                  DB '==================================',0DH,0AH,'$'
    str_burger    DB 0DH,0AH,'1. Burger $'
    str_nasi      DB 0DH,0AH,'2. Nasi Lemak $'
    str_rice      DB 0DH,0AH,'3. Egg Fried Rice $'
    str_chicken   DB 0DH,0AH,'4. 2pcs Fried Chicken $'
    str_x         DB ' x $'

    ; used by PRINT_ITEM_PRICE to build a line like "-RM5- -> RM4"
    RM_LABEL      DB 'RM$'
    DASH_LABEL    DB '-$'
    ARROW_LABEL   DB ' -> $'

    str_total     DB 0DH,0AH,0DH,0AH,'----------------------------------',0DH,0AH
                  DB 'TOTAL PRICE: RM $'

    pause_msg     DB 0DH,0AH,0DH,0AH,'Press any key to return...$',0DH,0AH
    checkout_prompt DB 0DH,0AH,0DH,0AH,'Checkout now? (Y/N): $'

    ; Shared cart state
    qty_burger    DB 0
    qty_nasi      DB 0
    qty_rice      DB 0
    qty_chicken   DB 0
    total_price   DW 0       ; Accumulated RM total (already has any discount applied)

    ; Item prices in whole ringgit - the ONE place these are defined.
    PRICE_BURGER    DW 5
    PRICE_NASI      DW 14
    PRICE_RICE      DW 7
    PRICE_CHICKEN   DW 6

    DISCOUNT_TOTAL  DW 0      ; running total of RM saved via the proximity discount

.CODE
CartModule PROC NEAR
    LEA DX, cart_header
    CALL PRINT_STRING

    ; --- Burger ---
    LEA DX, str_burger
    CALL PRINT_STRING
    MOV AX, PRICE_BURGER
    CALL PRINT_ITEM_PRICE
    LEA DX, str_x
    CALL PRINT_STRING
    MOV AL, qty_burger
    MOV AH, 0
    CALL PRINT_NUM

    ; --- Nasi Lemak ---
    LEA DX, str_nasi
    CALL PRINT_STRING
    MOV AX, PRICE_NASI
    CALL PRINT_ITEM_PRICE
    LEA DX, str_x
    CALL PRINT_STRING
    MOV AL, qty_nasi
    MOV AH, 0
    CALL PRINT_NUM

    ; --- Egg Fried Rice ---
    LEA DX, str_rice
    CALL PRINT_STRING
    MOV AX, PRICE_RICE
    CALL PRINT_ITEM_PRICE
    LEA DX, str_x
    CALL PRINT_STRING
    MOV AL, qty_rice
    MOV AH, 0
    CALL PRINT_NUM

    ; --- Fried Chicken ---
    LEA DX, str_chicken
    CALL PRINT_STRING
    MOV AX, PRICE_CHICKEN
    CALL PRINT_ITEM_PRICE
    LEA DX, str_x
    CALL PRINT_STRING
    MOV AL, qty_chicken
    MOV AH, 0
    CALL PRINT_NUM

    ; --- Display Total Price ---
    LEA DX, str_total
    CALL PRINT_STRING

    MOV AX, total_price
    CALL PRINT_NUM             ; Print multi-digit number stored in AX

    ; --- Offer to checkout right here ---
    LEA DX, checkout_prompt
    CALL PRINT_STRING

    MOV AH, 01H                ; read one key (Y/N)
    INT 21H
    AND AL, 0DFH                ; uppercase, so 'y' and 'Y' both work
    CMP AL, 'Y'
    JE  GO_CHECKOUT
    JMP SKIP_CHECKOUT

GO_CHECKOUT:
    CALL CheckoutModule         ; shows a receipt, saves to history, empties the cart
    RET

SKIP_CHECKOUT:
    ; Pause
    LEA DX, pause_msg
    CALL PRINT_STRING
    MOV AH, 07H
    INT 21H
    RET
CartModule ENDP

; --- Prints one cart line's price. If this session doesn't qualify
;     for the proximity discount, just prints "RM<price>". If it
;     does, prints "-RM<price>- -> RM<discounted price>" instead. ---
; IN: AX = base price for this item
PRINT_ITEM_PRICE PROC NEAR
    PUSH AX                      ; remember the original (undiscounted) price
    CALL CALC_PRICE               ; AX = price to charge, BX = amount saved
    CMP BX, 0
    JE  PIP_PLAIN

    MOV CX, AX                    ; CX = price to charge (save before AX is reused)
    POP AX                         ; AX = original price
    LEA DX, DASH_LABEL
    CALL PRINT_STRING
    LEA DX, RM_LABEL
    CALL PRINT_STRING
    CALL PRINT_NUM                  ; prints the original price
    LEA DX, DASH_LABEL
    CALL PRINT_STRING
    LEA DX, ARROW_LABEL
    CALL PRINT_STRING
    LEA DX, RM_LABEL
    CALL PRINT_STRING
    MOV AX, CX                      ; AX = price to charge
    CALL PRINT_NUM
    RET

PIP_PLAIN:
    POP AX                          ; AX = original price (nothing was saved)
    LEA DX, RM_LABEL
    CALL PRINT_STRING
    CALL PRINT_NUM
    RET
PRINT_ITEM_PRICE ENDP

; --- Works out the proximity discount for one item.
;     IN:  AX = base price (whole ringgit)
;     OUT: AX = price to actually charge
;          BX = amount saved (0 if CURRENT_DISCOUNT isn't set)
;     Rounds to the nearest ringgit instead of always rounding down
;     (adding half of 100 before dividing does that) - otherwise a
;     10% discount on a small whole-ringgit price like RM5 would
;     round all the way down to RM0 saved. ---
CALC_PRICE PROC NEAR
    CMP CURRENT_DISCOUNT, 1
    JNE CALC_PRICE_NONE

    PUSH AX                  ; keep the original price safe
    MOV BX, 10
    MUL BX                    ; DX:AX = price * 10
    ADD AX, 50                 ; round to nearest ringgit, not always down
    MOV BX, 100
    DIV BX                     ; AX = amount saved (10% of price, rounded)
    MOV BX, AX                  ; BX = amount saved
    POP AX                      ; AX = original price
    SUB AX, BX                   ; AX = price to charge
    RET

CALC_PRICE_NONE:
    XOR BX, BX
    RET
CALC_PRICE ENDP

; --- Routine to print 0-9 digits ---
; --- Routine to print multi-digit 16-bit numbers (AX) ---
END
