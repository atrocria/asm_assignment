.MODEL SMALL

; checkout.asm
; Turns the cart from cart.asm into a saved order, and lets the
; user look back at everything they've ordered so far.
;
;   CheckoutModule  - called from CartModule (View Cart) after the
;                     user has already answered "Checkout now? (Y/N)"
;                     over there. It does not ask again - it shows a
;                     receipt with tax, takes payment (COD or card -
;                     card asks for the cardholder name, card number
;                     and 3-digit CVV, each re-asked until valid),
;                     then asks for a delivery location and shows an
;                     estimated delivery time, saves the order into
;                     history, then empties the cart.
;   HistoryModule   - called from main.asm's "3. Order History".
;                     Lists every order CheckoutModule has saved,
;                     then a grand total across all of them.

PUBLIC CheckoutModule, HistoryModule

; Cart state lives in cart.asm - we only borrow it here.
EXTRN qty_burger:BYTE, qty_nasi:BYTE, qty_rice:BYTE, qty_chicken:BYTE
EXTRN total_price:WORD

; from tools.asm
EXTRN ReadNum:NEAR, NewLine:NEAR, ReadString:NEAR

.DATA
    ; c++ equivalent: define MAX_HISTORY 10
    MAX_HISTORY      EQU 10          ; number of past orders to keep
    TAX_PERCENTAGE   EQU 6           ; flat tax rate applied to the subtotal

    ; ---------- input length limits (also used to validate input) ----------
    NAME_MAXLEN      EQU 30          ; max characters for cardholder name
    CARD_MINLEN      EQU 12          ; shortest card number we accept
    CARD_MAXLEN      EQU 16          ; longest card number we accept
    CVV_MAXLEN       EQU 3           ; CVV is always exactly 3 digits
    DELIVERY_MAXLEN  EQU 40          ; max characters for a delivery location

    ; ---------- checkout screen text ----------
    checkout_header  DB 0DH,0AH,0DH,0AH,'==================================',0DH,0AH
                     DB                 '             CHECKOUT             ',0DH,0AH
                     DB                 '==================================',0DH,0AH,'$'

    empty_cart_msg   DB 0DH,0AH,'Your cart is empty - add something first!',0DH,0AH,'$'
    history_full_msg DB 0DH,0AH,'(Order history is full, so this order will not be saved there.)',0DH,0AH,'$'
    success_msg      DB 0DH,0AH,'Order placed! Thanks for ordering.',0DH,0AH,'$'
    pause_msg        DB 0DH,0AH,0DH,0AH,'Press any key to continue...$'

    ; item lines shared by the checkout receipt and the order history list
    co_burger        DB 0DH,0AH,'Burger x $'
    co_nasi          DB 0DH,0AH,'Nasi Lemak x $'
    co_rice          DB 0DH,0AH,'Egg Fried Rice x $'
    co_chicken       DB 0DH,0AH,'2pcs Fried Chicken x $'
    co_total         DB 0DH,0AH,'Total: RM $'

    ; ---------- receipt: subtotal, tax, amount due ----------
    subtotal_label   DB 0DH,0AH,'Subtotal: RM $'
    tax_label        DB 0DH,0AH,'Tax (6%): RM $'
    total_due_label  DB 0DH,0AH,'Total due: RM $'

    order_tax        DW 0     ; tax on the order being checked out right now
    order_due        DW 0     ; subtotal + tax = what the customer must pay

    ; ---------- payment ----------
    payment_menu_msg    DB 0DH,0AH,0DH,0AH,'How will you pay?',0DH,0AH
                        DB '1. Cash on Delivery (COD)',0DH,0AH
                        DB '2. Card',0DH,0AH
                        DB 'Choose an option: $'
    invalid_payment_msg DB 0DH,0AH,'Invalid choice, try again.',0DH,0AH,'$'

    cash_prompt         DB 0DH,0AH,'Enter cash amount for COD (RM): $'
    change_label        DB 0DH,0AH,'Change: RM $'
    insufficient_msg    DB 0DH,0AH,'That is not enough cash - checkout cancelled.',0DH,0AH,'$'
    card_approved_msg   DB 0DH,0AH,'Card payment approved.',0DH,0AH,'$'

    cash_tendered       DW 0             ; cash the customer handed over
    change_due           DW 0             ; cash_tendered - order_due

    ; ---------- card details (asked for card payments only) ----------
    name_prompt          DB 0DH,0AH,'Enter cardholder name: $'
    invalid_name_msg     DB 0DH,0AH,'Invalid name - letters and spaces only, try again.',0DH,0AH,'$'
    card_number_prompt   DB 0DH,0AH,'Enter card number (12-16 digits): $'
    invalid_card_msg     DB 0DH,0AH,'Invalid card number - digits only, 12-16 of them, try again.',0DH,0AH,'$'
    cvv_prompt           DB 0DH,0AH,'Enter the 3-digit CVV (on the back of the card): $'
    invalid_cvv_msg      DB 0DH,0AH,'Invalid CVV - must be exactly 3 digits, try again.',0DH,0AH,'$'

    ; DOS buffered-input format: byte0 = max chars, byte1 = actual chars
    ; typed (filled in by ReadString), byte2.. = the characters.
    ; DOS needs room for the CR too, so the max byte is MAXLEN+1
    name_buf          DB NAME_MAXLEN+1, 0, NAME_MAXLEN+2 DUP(0)
    card_number_buf   DB CARD_MAXLEN+1, 0, CARD_MAXLEN+2 DUP(0)
    cvv_buf           DB CVV_MAXLEN+1, 0, CVV_MAXLEN+2 DUP(0)

    ; ---------- delivery (asked after either payment method) ----------
    delivery_prompt        DB 0DH,0AH,0DH,0AH,'Enter delivery location: $'
    invalid_delivery_msg   DB 0DH,0AH,'Delivery location cannot be empty, try again.',0DH,0AH,'$'
    delivery_estimate_msg  DB 0DH,0AH,'Estimation of delivery: 30min',0DH,0AH,'$'

    ; DOS needs room for the CR too, so the max byte is MAXLEN+1
    delivery_buf      DB DELIVERY_MAXLEN+1, 0, DELIVERY_MAXLEN+2 DUP(0)

    ; ---------- order history storage ----------
    ; slot i (0 .. history_count-1) holds one past checkout
    ; array type in asm, 
    hist_burger   DB MAX_HISTORY DUP(0)
    hist_nasi     DB MAX_HISTORY DUP(0)
    hist_rice     DB MAX_HISTORY DUP(0)
    hist_chicken  DB MAX_HISTORY DUP(0)
    hist_total    DW MAX_HISTORY DUP(0)     ; final amount actually paid (tax included)
    history_count DW 0

    ; ---------- order history screen text ----------
    history_header    DB 0DH,0AH,'==================================',0DH,0AH
                      DB          '           ORDER HISTORY          ',0DH,0AH
                      DB          '==================================',0DH,0AH,'$'
    history_empty_msg DB 0DH,0AH,'No orders yet - checkout your cart to see it here.',0DH,0AH,'$'
    order_label       DB 0DH,0AH,0DH,0AH,'Order #$'
    separator_msg     DB 0DH,0AH,'----------------------------------',0DH,0AH,'$'
    grand_total_msg   DB 0DH,0AH,'Grand total (all orders): RM $'

    grand_total       DW 0          ; sum of every past order's total, for HistoryModule

.CODE

EXTRN ClearScreen:NEAR

; =============================================================
; CheckoutModule
; Shows a receipt (items, subtotal, tax, total due), takes
; payment, then copies the order into history and empties the
; cart. The caller (CartModule) is the one that already confirmed
; "Checkout now? (Y/N)" with the user.
; =============================================================
CheckoutModule PROC NEAR

    CMP WORD PTR total_price, 0
    JNE CO_SHOW_RECEIPT
    LEA DX, empty_cart_msg
    MOV AH, 09H
    INT 21H
    CALL CO_WAIT_KEY
    RET

CO_SHOW_RECEIPT:
    CALL ClearScreen
    LEA DX, checkout_header
    MOV AH, 09H
    INT 21H

    CALL CO_PRINT_ITEMS          ; prints the 4 live cart quantities

    LEA DX, subtotal_label
    MOV AH, 09H
    INT 21H
    MOV AX, total_price
    CALL CO_PRINT_NUM

    CALL CO_CALC_TAX             ; fills in order_tax and order_due

    LEA DX, tax_label
    MOV AH, 09H
    INT 21H
    MOV AX, order_tax
    CALL CO_PRINT_NUM

    LEA DX, total_due_label
    MOV AH, 09H
    INT 21H
    MOV AX, order_due
    CALL CO_PRINT_NUM

    CALL CO_TAKE_PAYMENT         ; asks COD/Card, shows change if paying COD
    CMP AL, 1                    ; AL = 1 if payment went through, 0 if not enough cash
    JE  CO_ASK_DELIVERY

    LEA DX, insufficient_msg
    MOV AH, 09H
    INT 21H
    CALL CO_WAIT_KEY
    RET

CO_ASK_DELIVERY:                 ; payment went through - now get delivery details
    CALL CO_READ_DELIVERY

    LEA DX, delivery_estimate_msg
    MOV AH, 09H
    INT 21H

CO_SAVE_ORDER:
    MOV AX, history_count
    CMP AX, MAX_HISTORY
    JL  CO_STORE

    LEA DX, history_full_msg     ; history full - still checkout, just skip saving it
    MOV AH, 09H
    INT 21H
    JMP CO_CLEAR_CART

CO_STORE:
    MOV BX, history_count        ; BX = index of the new history slot

    LEA SI, hist_burger
    ADD SI, BX
    MOV AL, qty_burger
    MOV [SI], AL

    LEA SI, hist_nasi
    ADD SI, BX
    MOV AL, qty_nasi
    MOV [SI], AL

    LEA SI, hist_rice
    ADD SI, BX
    MOV AL, qty_rice
    MOV [SI], AL

    LEA SI, hist_chicken
    ADD SI, BX
    MOV AL, qty_chicken
    MOV [SI], AL

    MOV DI, BX
    SHL DI, 1                    ; hist_total holds WORDs, so index*2
    LEA SI, hist_total
    ADD SI, DI
    MOV AX, order_due            ; save what was actually charged (tax included)
    MOV [SI], AX

    INC history_count

CO_CLEAR_CART:
    MOV qty_burger, 0
    MOV qty_nasi, 0
    MOV qty_rice, 0
    MOV qty_chicken, 0
    MOV WORD PTR total_price, 0

    LEA DX, success_msg
    MOV AH, 09H
    INT 21H
    CALL CO_WAIT_KEY
    RET
CheckoutModule ENDP


; =============================================================
; HistoryModule
; Lists every order CheckoutModule has saved so far, oldest first,
; then a grand total added up across all of them.
; =============================================================
HistoryModule PROC NEAR
    MOV grand_total, 0           ; reset in case this gets shown more than once

    LEA DX, history_header
    MOV AH, 09H
    INT 21H

    MOV CX, history_count
    CMP CX, 0
    JNE HM_LIST
    LEA DX, history_empty_msg
    MOV AH, 09H
    INT 21H
    JMP HM_DONE

HM_LIST:
    MOV BX, 0                    ; BX = index of the order being printed

HM_LOOP:
    LEA DX, order_label
    MOV AH, 09H
    INT 21H
    MOV AX, BX
    INC AX                       ; show "Order #1", "Order #2", ... not #0
    CALL CO_PRINT_NUM

    ; --- Burger ---
    LEA DX, co_burger
    MOV AH, 09H
    INT 21H
    LEA SI, hist_burger
    ADD SI, BX
    MOV AL, [SI]
    MOV AH, 0                    ; AL is 0-255, so widen to AX before printing
    CALL CO_PRINT_NUM

    ; --- Nasi Lemak ---
    LEA DX, co_nasi
    MOV AH, 09H
    INT 21H
    LEA SI, hist_nasi
    ADD SI, BX
    MOV AL, [SI]
    MOV AH, 0
    CALL CO_PRINT_NUM

    ; --- Egg Fried Rice ---
    LEA DX, co_rice
    MOV AH, 09H
    INT 21H
    LEA SI, hist_rice
    ADD SI, BX
    MOV AL, [SI]
    MOV AH, 0
    CALL CO_PRINT_NUM

    ; --- Fried Chicken ---
    LEA DX, co_chicken
    MOV AH, 09H
    INT 21H
    LEA SI, hist_chicken
    ADD SI, BX
    MOV AL, [SI]
    MOV AH, 0
    CALL CO_PRINT_NUM

    ; --- Total (tax already included, since that is what was charged) ---
    LEA DX, co_total
    MOV AH, 09H
    INT 21H
    MOV DI, BX
    SHL DI, 1
    LEA SI, hist_total
    ADD SI, DI
    MOV AX, [SI]
    CALL CO_PRINT_NUM
    ADD grand_total, AX           ; fold this order into the running total

    LEA DX, separator_msg
    MOV AH, 09H
    INT 21H

    INC BX
    CMP BX, history_count
    JGE HM_TOTAL                 ; MASM can't reach HM_LOOP with a short JL from
    JMP HM_LOOP                  ; here (loop body is too long) - JMP has no such limit

HM_TOTAL:
    LEA DX, grand_total_msg
    MOV AH, 09H
    INT 21H
    MOV AX, grand_total
    CALL CO_PRINT_NUM

HM_DONE:
    CALL CO_WAIT_KEY
    RET
HistoryModule ENDP

; =============================================================
; Local helpers - same pattern as cart.asm's own print helpers,
; just kept private to this file (checkout.asm) so nothing outside
; needs to know they exist.
; =============================================================

; --- Prints the 4 live cart quantities (no total - CheckoutModule
;     prints subtotal/tax/total due itself, right after calling this) ---
CO_PRINT_ITEMS PROC NEAR
    LEA DX, co_burger
    MOV AH, 09H
    INT 21H
    MOV AL, qty_burger
    MOV AH, 0                    ; AL is 0-255, so widen to AX before printing
    CALL CO_PRINT_NUM

    LEA DX, co_nasi
    MOV AH, 09H
    INT 21H
    MOV AL, qty_nasi
    MOV AH, 0
    CALL CO_PRINT_NUM

    LEA DX, co_rice
    MOV AH, 09H
    INT 21H
    MOV AL, qty_rice
    MOV AH, 0
    CALL CO_PRINT_NUM

    LEA DX, co_chicken
    MOV AH, 09H
    INT 21H
    MOV AL, qty_chicken
    MOV AH, 0
    CALL CO_PRINT_NUM
    RET
CO_PRINT_ITEMS ENDP

; --- Works out tax and total due from the current subtotal
;     (total_price). Tax is rounded down to the nearest ringgit. ---
CO_CALC_TAX PROC NEAR
    PUSH BX
    PUSH DX

    MOV AX, total_price
    MOV BX, TAX_PERCENTAGE
    MUL BX                       ; DX:AX = total_price * TAX_PERCENTAGE
    MOV BX, 100
    DIV BX                       ; AX = tax amount
    MOV order_tax, AX

    MOV AX, total_price
    ADD AX, order_tax
    MOV order_due, AX

    POP DX
    POP BX
    RET
CO_CALC_TAX ENDP

; --- Asks COD or Card and collects payment.
;     COD also asks for the cash amount and shows change. Card asks
;     for the cardholder name, card number and CVV (each re-asked
;     until valid).
;     Returns: AL = 1 if payment went through, AL = 0 if the cash
;              handed over was not enough (checkout is cancelled). ---
CO_TAKE_PAYMENT PROC NEAR
CO_ASK_METHOD:
    LEA DX, payment_menu_msg
    MOV AH, 09H
    INT 21H

    MOV AH, 01H                  ; read one key (1 or 2)
    INT 21H

    CMP AL, '1'
    JE  CO_PAY_CASH
    CMP AL, '2'
    JE  CO_PAY_CARD

    LEA DX, invalid_payment_msg
    MOV AH, 09H
    INT 21H
    JMP CO_ASK_METHOD

CO_PAY_CARD:
    CALL CO_READ_NAME             ; cardholder name (letters/spaces only)
    CALL CO_READ_CARDNUM          ; card number (12-16 digits)
    CALL CO_READ_CVV              ; CVV (exactly 3 digits)

    LEA DX, card_approved_msg
    MOV AH, 09H
    INT 21H
    MOV AL, 1
    RET

CO_PAY_CASH:
    LEA DX, cash_prompt
    MOV AH, 09H
    INT 21H
    CALL ReadNum                 ; AX = cash amount typed in (from tools.asm)
    CALL NewLine
    MOV cash_tendered, AX

    CMP AX, order_due
    JGE CO_CASH_OK
    MOV AL, 0                    ; not enough cash
    RET

CO_CASH_OK:
    SUB AX, order_due
    MOV change_due, AX

    LEA DX, change_label
    MOV AH, 09H
    INT 21H
    MOV AX, change_due
    CALL CO_PRINT_NUM

    MOV AL, 1
    RET
CO_TAKE_PAYMENT ENDP

; --- Asks for the cardholder name and re-asks until it is not
;     empty and contains only letters and spaces. Fills name_buf. ---
CO_READ_NAME PROC NEAR
CO_READ_NAME_AGAIN:
    LEA DX, name_prompt
    MOV AH, 09H
    INT 21H
    LEA DX, name_buf
    CALL ReadString
    CALL NewLine

    MOV CL, name_buf+1           ; actual number of characters typed
    XOR CH, CH
    LEA SI, name_buf+2
    CALL CO_CHECK_ALPHA
    CMP AL, 1
    JE  CO_READ_NAME_OK

    LEA DX, invalid_name_msg
    MOV AH, 09H
    INT 21H
    JMP CO_READ_NAME_AGAIN

CO_READ_NAME_OK:
    RET
CO_READ_NAME ENDP

; --- Asks for a card number and re-asks until it is CARD_MINLEN to
;     CARD_MAXLEN digits, digits only. Fills card_number_buf. ---
CO_READ_CARDNUM PROC NEAR
CO_READ_CARDNUM_AGAIN:
    LEA DX, card_number_prompt
    MOV AH, 09H
    INT 21H
    LEA DX, card_number_buf
    CALL ReadString
    CALL NewLine

    MOV CL, card_number_buf+1    ; actual number of characters typed
    XOR CH, CH
    CMP CX, CARD_MINLEN
    JB  CO_CARDNUM_INVALID

    LEA SI, card_number_buf+2
    CALL CO_CHECK_DIGITS
    CMP AL, 1
    JE  CO_READ_CARDNUM_OK

CO_CARDNUM_INVALID:
    LEA DX, invalid_card_msg
    MOV AH, 09H
    INT 21H
    JMP CO_READ_CARDNUM_AGAIN

CO_READ_CARDNUM_OK:
    RET
CO_READ_CARDNUM ENDP

; --- Asks for the 3-digit CVV and re-asks until it is exactly
;     CVV_MAXLEN digits, digits only. Fills cvv_buf. ---
CO_READ_CVV PROC NEAR
CO_READ_CVV_AGAIN:
    LEA DX, cvv_prompt
    MOV AH, 09H
    INT 21H
    LEA DX, cvv_buf
    CALL ReadString
    CALL NewLine

    MOV CL, cvv_buf+1            ; actual number of characters typed
    XOR CH, CH
    CMP CX, CVV_MAXLEN
    JNE CO_CVV_INVALID

    LEA SI, cvv_buf+2
    CALL CO_CHECK_DIGITS
    CMP AL, 1
    JE  CO_READ_CVV_OK

CO_CVV_INVALID:
    LEA DX, invalid_cvv_msg
    MOV AH, 09H
    INT 21H
    JMP CO_READ_CVV_AGAIN

CO_READ_CVV_OK:
    RET
CO_READ_CVV ENDP

; --- Asks for the delivery location and re-asks if left empty.
;     Fills delivery_buf. ---
CO_READ_DELIVERY PROC NEAR
CO_READ_DELIVERY_AGAIN:
    LEA DX, delivery_prompt
    MOV AH, 09H
    INT 21H
    LEA DX, delivery_buf
    CALL ReadString
    CALL NewLine

    CMP delivery_buf+1, 0        ; actual number of characters typed
    JNE CO_READ_DELIVERY_OK

    LEA DX, invalid_delivery_msg
    MOV AH, 09H
    INT 21H
    JMP CO_READ_DELIVERY_AGAIN

CO_READ_DELIVERY_OK:
    RET
CO_READ_DELIVERY ENDP

; --- Checks that CX characters starting at DS:SI are all '0'-'9'.
;     Returns AL = 1 if so (and CX > 0), AL = 0 otherwise. ---
CO_CHECK_DIGITS PROC NEAR
    PUSH CX
    PUSH SI
    CMP CX, 0
    JE  CCD_BAD

CCD_LOOP:
    MOV AL, [SI]
    CMP AL, '0'
    JB  CCD_BAD
    CMP AL, '9'
    JA  CCD_BAD
    INC SI
    LOOP CCD_LOOP

    MOV AL, 1
    JMP CCD_DONE

CCD_BAD:
    MOV AL, 0

CCD_DONE:
    POP SI
    POP CX
    RET
CO_CHECK_DIGITS ENDP

; --- Checks that CX characters starting at DS:SI are all letters
;     (A-Z, a-z) or spaces. Returns AL = 1 if so (and CX > 0),
;     AL = 0 otherwise. ---
CO_CHECK_ALPHA PROC NEAR
    PUSH CX
    PUSH SI
    CMP CX, 0
    JE  CCA_BAD

CCA_LOOP:
    MOV AL, [SI]
    CMP AL, 'A'
    JB  CCA_SPACE
    CMP AL, 'Z'
    JBE CCA_OK_CHAR
    CMP AL, 'a'
    JB  CCA_SPACE
    CMP AL, 'z'
    JBE CCA_OK_CHAR

CCA_SPACE:
    CMP AL, ' '
    JE  CCA_OK_CHAR
    JMP CCA_BAD

CCA_OK_CHAR:
    INC SI
    LOOP CCA_LOOP

    MOV AL, 1
    JMP CCA_DONE

CCA_BAD:
    MOV AL, 0

CCA_DONE:
    POP SI
    POP CX
    RET
CO_CHECK_ALPHA ENDP

; --- Prints AX as a decimal number (any number of digits) ---
CO_PRINT_NUM PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    XOR CX, CX                   ; digit counter = 0
    MOV BX, 10

CO_NUM_SPLIT:
    XOR DX, DX
    DIV BX                       ; divide AX by 10, remainder in DX
    PUSH DX                      ; stack the digits so they print MSB-first
    INC CX
    CMP AX, 0
    JNE CO_NUM_SPLIT

CO_NUM_PRINT:
    POP DX
    ADD DL, '0'
    MOV AH, 02H
    INT 21H
    LOOP CO_NUM_PRINT

    POP DX
    POP CX
    POP BX
    POP AX
    RET
CO_PRINT_NUM ENDP

; --- Waits for a keypress so the screen doesn't fly by ---
CO_WAIT_KEY PROC NEAR
    LEA DX, pause_msg
    MOV AH, 09H
    INT 21H
    MOV AH, 07H
    INT 21H
    RET
CO_WAIT_KEY ENDP

END
