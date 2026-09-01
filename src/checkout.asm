.MODEL SMALL

; checkout.asm
; Turns the cart from cart.asm into a saved order, and lets the
; user look back at everything they've ordered so far.
;
;   CheckoutModule  - called from CartModule (View Cart) *after* the
;                     user has already answered "Checkout now? (Y/N)"
;                     over there. It does not ask again - it shows a
;                     receipt with tax, takes payment (cash or card),
;                     saves the order into history, then empties the
;                     cart.
;   HistoryModule   - called from main.asm's "3. Order History".
;                     Lists every order CheckoutModule has saved,
;                     then a grand total across all of them.

PUBLIC CheckoutModule, HistoryModule

; Cart state lives in cart.asm - we only borrow it here.
EXTRN qty_burger:BYTE, qty_nasi:BYTE, qty_rice:BYTE, qty_chicken:BYTE
EXTRN total_price:WORD

; Shared helpers from tools.asm - no need to reinvent number input.
EXTRN ReadNum:NEAR, NewLine:NEAR

.DATA
    MAX_HISTORY   EQU 10          ; how many past orders we can remember
    TAX_PERCENT   EQU 6           ; flat tax rate applied to the subtotal

    ; ---------- checkout screen text ----------
    checkout_header DB 0DH,0AH,0DH,0AH,'==================================',0DH,0AH
                    DB                 '             CHECKOUT             ',0DH,0AH
                    DB                 '==================================',0DH,0AH,'$'

    empty_cart_msg   DB 0DH,0AH,'Your cart is empty - add something first!',0DH,0AH,'$'
    history_full_msg DB 0DH,0AH,'(Order history is full, so this order will not be saved there.)',0DH,0AH,'$'
    success_msg      DB 0DH,0AH,'Order placed! Thanks for ordering.',0DH,0AH,'$'
    pause_msg        DB 0DH,0AH,0DH,0AH,'Press any key to continue...$'

    ; item lines shared by the checkout receipt and the order history list
    co_burger   DB 0DH,0AH,'Burger x $'
    co_nasi     DB 0DH,0AH,'Nasi Lemak x $'
    co_rice     DB 0DH,0AH,'Egg Fried Rice x $'
    co_chicken  DB 0DH,0AH,'2pcs Fried Chicken x $'
    co_total    DB 0DH,0AH,'Total: RM $'

    ; ---------- receipt: subtotal, tax, amount due ----------
    subtotal_label   DB 0DH,0AH,'Subtotal: RM $'
    tax_label        DB 0DH,0AH,'Tax (6%): RM $'
    total_due_label  DB 0DH,0AH,'Total due: RM $'

    order_tax   DW 0               ; tax on the order being checked out right now
    order_due   DW 0               ; subtotal + tax = what the customer must pay

    ; ---------- payment ----------
    payment_menu_msg DB 0DH,0AH,0DH,0AH,'How will you pay?',0DH,0AH
                     DB '1. Cash',0DH,0AH
                     DB '2. Card',0DH,0AH
                     DB 'Choose an option: $'
    invalid_payment_msg DB 0DH,0AH,'Invalid choice, try again.',0DH,0AH,'$'

    cash_prompt      DB 0DH,0AH,'Enter cash amount (RM): $'
    change_label     DB 0DH,0AH,'Change: RM $'
    insufficient_msg DB 0DH,0AH,'That is not enough cash - checkout cancelled.',0DH,0AH,'$'
    card_approved_msg DB 0DH,0AH,'Card payment approved.',0DH,0AH,'$'

    cash_tendered DW 0             ; cash the customer handed over
    change_due    DW 0             ; cash_tendered - order_due

    ; ---------- order history storage ----------
    ; slot i (0 .. history_count-1) holds one past checkout
    hist_burger   DB MAX_HISTORY DUP(0)
    hist_nasi     DB MAX_HISTORY DUP(0)
    hist_rice     DB MAX_HISTORY DUP(0)
    hist_chicken  DB MAX_HISTORY DUP(0)
    hist_total    DW MAX_HISTORY DUP(0)     ; final amount actually paid (tax included)
    history_count DW 0

    ; ---------- order history screen text ----------
    history_header DB 0DH,0AH,'==================================',0DH,0AH
                   DB          '           ORDER HISTORY          ',0DH,0AH
                   DB          '==================================',0DH,0AH,'$'
    history_empty_msg DB 0DH,0AH,'No orders yet - checkout your cart to see it here.',0DH,0AH,'$'
    order_label     DB 0DH,0AH,0DH,0AH,'Order #$'
    separator_msg   DB 0DH,0AH,'----------------------------------',0DH,0AH,'$'
    grand_total_msg DB 0DH,0AH,'Grand total (all orders): RM $'

    grand_total     DW 0          ; sum of every past order's total, for HistoryModule

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

    CALL CO_TAKE_PAYMENT         ; asks Cash/Card, shows change if paying cash
    CMP AL, 1                    ; AL = 1 if payment went through, 0 if not enough cash
    JE  CO_SAVE_ORDER

    LEA DX, insufficient_msg
    MOV AH, 09H
    INT 21H
    CALL CO_WAIT_KEY
    RET

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
    MOV BX, TAX_PERCENT
    MUL BX                       ; DX:AX = total_price * TAX_PERCENT
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

; --- Asks Cash or Card and collects payment.
;     Cash also asks for the amount and shows change.
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
