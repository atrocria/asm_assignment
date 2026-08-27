.MODEL SMALL

PUBLIC qty_burger, qty_nasi, qty_rice, qty_chicken, total_price
PUBLIC CartModule

.DATA
    cart_header   DB 0DH,0AH,'==================================',0DH,0AH
                  DB 		 '       YOUR SHOPPING CART         ',0DH,0AH
                  DB 		 '==================================',0DH,0AH,'$'
    str_burger    DB 0DH,0AH,'1. Burger (RM5) x $'
    str_nasi      DB 0DH,0AH,'2. Nasi Lemak (RM14) x $'
    str_rice      DB 0DH,0AH,'3. Egg Fried Rice (RM7) x $'
    str_chicken   DB 0DH,0AH,'4. 2pcs Fried Chicken (RM6) x $'
    
    str_total     DB 0DH,0AH,0DH,0AH,'----------------------------------',0DH,0AH
                  DB 'TOTAL PRICE: RM $'
                  
    pause_msg     DB 0DH,0AH,0DH,0AH,'Press any key to return...$',0DH,0AH
    checkout_prompt DB 0DH,0AH,0DH,0AH,'Checkout now? (Y/N): $'

    ; Shared cart state
    qty_burger    DB 0
    qty_nasi      DB 0
    qty_rice      DB 0
    qty_chicken   DB 0
    total_price   DW 0       ; Accumulated RM total

.CODE
CartModule PROC NEAR
EXTRN CheckoutModule:NEAR

    LEA DX, cart_header
    MOV AH, 09H
    INT 21H

    ; --- Burger ---
    LEA DX, str_burger
    MOV AH, 09H
    INT 21H
    MOV AL, qty_burger
    CALL PRINT_SINGLE_DIGIT

    ; --- Nasi Lemak ---
    LEA DX, str_nasi
    MOV AH, 09H
    INT 21H
    MOV AL, qty_nasi
    CALL PRINT_SINGLE_DIGIT

    ; --- Egg Fried Rice ---
    LEA DX, str_rice
    MOV AH, 09H
    INT 21H
    MOV AL, qty_rice
    CALL PRINT_SINGLE_DIGIT

    ; --- Fried Chicken ---
    LEA DX, str_chicken
    MOV AH, 09H
    INT 21H
    MOV AL, qty_chicken
    CALL PRINT_SINGLE_DIGIT

    ; --- Display Total Price ---
    LEA DX, str_total
    MOV AH, 09H
    INT 21H

    MOV AX, total_price
    CALL PRINT_NUM             ; Print multi-digit number stored in AX

    ; --- Offer to checkout right here ---
    LEA DX, checkout_prompt
    MOV AH, 09H
    INT 21H

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
    MOV AH, 09H
    INT 21H
    MOV AH, 07H
    INT 21H
    RET
CartModule ENDP

; --- Routine to print 0-9 digits ---
PRINT_SINGLE_DIGIT PROC NEAR
    ADD AL, '0'
    MOV DL, AL
    MOV AH, 02H
    INT 21H
    RET
PRINT_SINGLE_DIGIT ENDP

; --- Routine to print multi-digit 16-bit numbers (AX) ---
PRINT_NUM PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    XOR CX, CX                 ; Digit counter = 0
    MOV BX, 10

CONVERT_LOOP:
    XOR DX, DX
    DIV BX                     ; Divide AX by 10 (Remainder in DX)
    PUSH DX                    ; Push remainder onto stack
    INC CX
    CMP AX, 0
    JNE CONVERT_LOOP

PRINT_LOOP:
    POP DX
    ADD DL, '0'                ; Convert digit to ASCII
    MOV AH, 02H
    INT 21H
    LOOP PRINT_LOOP

    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_NUM ENDP

END