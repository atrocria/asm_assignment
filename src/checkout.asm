;===============================================================
; QUICK REFERENCE - INT 21H FUNCTIONS AND INSTRUCTIONS USED HERE
; (FOR VIVA/INTERVIEW REVIEW - NOT PART OF THE ORIGINAL PROGRAM)
;===============================================================
;
; --- DOS INTERRUPT (INT 21H) FUNCTIONS, SELECTED VIA AH ---
;   AH=01H  READ ONE KEY, WITH ECHO       - waits for a keypress, prints
;                                           it, returns it in AL
;                                           (used: payment menu choice)
;   AH=02H  PRINT ONE CHARACTER           - prints whatever is in DL
;                                           (used inside NEWLINE/PRINT_NUM,
;                                           TOOLS.ASM)
;   AH=07H  READ ONE KEY, NO ECHO         - waits for a keypress but does
;                                           NOT print it
;                                           (used: CO_WAIT_KEY, "press
;                                           any key to continue")
;   AH=09H  PRINT STRING                  - prints DS:DX until it hits
;                                           '$' (why every message here
;                                           ends in '$', not a null byte)
;                                           (used inside PRINT_STRING,
;                                           TOOLS.ASM)
;   AH=0AH  BUFFERED KEYBOARD INPUT       - reads a whole line into a
;                                           buffer until ENTER; buffer
;                                           byte 1 = count, byte 2+ =
;                                           the raw characters typed
;                                           (used inside READSTRING,
;                                           TOOLS.ASM)
;
; --- CORE INSTRUCTIONS USED IN THIS FILE ---
;   JE/JNE     jump if the last CMP found the two values equal / not
;              equal (i.e. zero flag set / clear)
;   JB         jump if below - the last CMP found the first value
;              LESS than the second, treating both as UNSIGNED numbers
;   JL/JGE     jump if less / greater-or-equal - like JB, but treating
;              both values as SIGNED numbers
;   JMP        unconditional jump - always taken, no CMP needed
;   XOR        bitwise XOR - XOR reg,reg (e.g. XOR CH,CH) is the
;              standard cheap way to zero a register, equivalent to
;              MOV reg,0
;   AND        bitwise AND - used elsewhere in this project to mask
;              off bits (e.g. forcing a letter to uppercase)
;===============================================================

.MODEL SMALL

; CHECKOUT.ASM
; TURNS THE CART FROM CART.ASM INTO A SAVED ORDER, AND LETS THE
; USER LOOK BACK AT EVERYTHING THEY'VE ORDERED SO FAR.
;
;   CHECKOUTMODULE  - CALLED FROM CARTMODULE (VIEW CART) AFTER THE
;                     USER HAS ALREADY ANSWERED "CHECKOUT NOW? (Y/N)"
;                     OVER THERE. IT DOES NOT ASK AGAIN - IT SHOWS A
;                     RECEIPT WITH TAX AND ANY PROXIMITY DISCOUNT,
;                     TAKES PAYMENT (COD OR CARD - CARD ASKS FOR THE
;                     CARDHOLDER NAME, CARD NUMBER AND 3-DIGIT CVV,
;                     EACH RE-ASKED UNTIL VALID), SHOWS THE ADDRESS
;                     ON FILE FOR THE LOGGED-IN ACCOUNT (SEE
;                     CURRENT_ADDR IN LOGIN.ASM) WITH AN ESTIMATED
;                     DELIVERY TIME, SAVES THE ORDER INTO HISTORY,
;                     THEN EMPTIES THE CART.
;   HISTORYMODULE   - CALLED FROM MAIN.ASM'S "3. ORDER HISTORY".
;                     LISTS EVERY ORDER CHECKOUTMODULE HAS SAVED,
;                     THEN A GRAND TOTAL ACROSS ALL OF THEM.

PUBLIC CHECKOUTMODULE, HISTORYMODULE

; CART ITEMS ORDER QUANTITY LIVES IN CART.ASM ITEM'S QUANTITY IS ONLY BORROW IT HERE.
EXTRN QTY_BURGER:BYTE, QTY_NASI:BYTE, QTY_RICE:BYTE, QTY_CHICKEN:BYTE
EXTRN TOTAL_PRICE:WORD
EXTRN DISCOUNT_TOTAL:WORD           ; FROM CART.ASM - RM SAVED VIA THE PROXIMITY DISCOUNT
EXTRN PRINT_NUM:NEAR                ; FROM TOOLS.ASM - SHARED NUMBER-PRINTING HELPER
EXTRN PRINT_STRING:NEAR             ; FROM TOOLS.ASM - SHARED STRING-PRINTING HELPER
EXTRN CHECK_ALPHA:NEAR, CHECK_DIGITS:NEAR   ; FROM TOOLS.ASM
                                             ; CHECK_DIGITS: checks that CX
                                             ; characters starting at DS:SI
                                             ; are all '0'-'9'; AL=1 if so
                                             ; (and CX>0), AL=0 otherwise
                                             ; CHECK_ALPHA: same idea but
                                             ; checks A-Z/a-z or spaces
                                             ; instead of digits. Both PROCs
                                             ; actually live in TOOLS.ASM -
                                             ; this file only ever CALLs them

; FROM LOGIN.ASM
EXTRN CURRENT_ADDR:BYTE             ; THE LOGGED-IN ACCOUNT'S SAVED DELIVERY ADDRESS

; FROM TOOLS.ASM
EXTRN READNUM:NEAR, NEWLINE:NEAR, READSTRING:NEAR

.DATA
    ; C++ EQUIVALENT: #DEFINE MAX_HISTORY 10
    MAX_HISTORY      EQU 10          ; NUMBER OF PAST ORDERS TO KEEP
    TAX_PERCENTAGE   EQU 6           ; FLAT % TAX RATE APPLIED TO THE SUBTOTAL

    ; ---------- INPUT LENGTH LIMITS (ALSO USED TO VALIDATE INPUT) ----------
    NAME_MAXLEN      EQU 30          ; MAX CHARACTERS FOR CARDHOLDER NAME

    ;! just only card length of 12 digits total no need to do 16 digits
    CARD_MINLEN      EQU 12          ; SHORTEST CARD NUMBER WE ACCEPT
    CARD_MAXLEN      EQU 16          ; LONGEST CARD NUMBER WE ACCEPT
    CVV_MAXLEN       EQU 3           ; CVV IS ALWAYS EXACTLY 3 DIGITS

    ; ---------- CHECKOUT SCREEN TEXT ----------
    CHECKOUT_HEADER  DB 0DH,0AH,0DH,0AH,'==================================',0DH,0AH
                     DB                 '             CHECKOUT             ',0DH,0AH
                     DB                 '==================================',0DH,0AH,'$'

    EMPTY_CART_MSG   DB 0DH,0AH,'YOUR CART IS EMPTY - ADD SOMETHING FIRST!',0DH,0AH,'$'
    HISTORY_FULL_MSG DB 0DH,0AH,'(ORDER HISTORY IS FULL, SO THIS ORDER WILL NOT BE SAVED THERE.)',0DH,0AH,'$'
    SUCCESS_MSG      DB 0DH,0AH,'ORDER PLACED! THANKS FOR ORDERING.',0DH,0AH,'$'
    PAUSE_MSG        DB 0DH,0AH,0DH,0AH,'PRESS ANY KEY TO CONTINUE...$'

    ; ITEM LINES SHARED BY THE CHECKOUT RECEIPT AND THE ORDER HISTORY LIST
    CO_BURGER        DB 0DH,0AH,'BURGER X $'
    CO_NASI          DB 0DH,0AH,'NASI LEMAK X $'
    CO_RICE          DB 0DH,0AH,'EGG FRIED RICE X $'
    CO_CHICKEN       DB 0DH,0AH,'2PCS FRIED CHICKEN X $'
    CO_TOTAL         DB 0DH,0AH,'TOTAL: RM $'

    ; ---------- RECEIPT: SUBTOTAL, DISCOUNT, TAX, AMOUNT DUE ----------
    ; SEPARATES THE ITEM LIST ABOVE FROM THE SUBTOTAL/DISCOUNT/TAX/TOTAL
    ; SUMMARY BELOW, SAME DASHED-LINE STYLE AS CART.ASM'S TOTAL PRICE LINE
    RECEIPT_SEPARATOR DB 0DH,0AH,0DH,0AH,'----------------------------------',0DH,0AH,'$'
    SUBTOTAL_LABEL   DB 'SUBTOTAL: RM $'
    DISCOUNT_LABEL   DB 0DH,0AH,'PROX. DISCOUNT: -RM $'
    TAX_LABEL        DB 0DH,0AH,'TAX (6%): RM $'
    TOTAL_DUE_LABEL  DB 0DH,0AH,'TOTAL DUE: RM $'

    ORDER_SUBTOTAL   DW 0     ; ITEM TOTAL BEFORE ANY TAX OR DISCOUNT
    ORDER_TAX        DW 0     ; TAX ON THE ORDER BEING CHECKED OUT RIGHT NOW
    ORDER_DUE        DW 0     ; SUBTOTAL - DISCOUNT + TAX = WHAT THE CUSTOMER MUST PAY

    ; ---------- PAYMENT ----------
    PAYMENT_MENU_MSG    DB 0DH,0AH,'----------------------------------',0DH,0AH
                        DB 0DH,0AH,'HOW WILL YOU PAY?',0DH,0AH
                        DB '1. CASH ON DELIVERY (COD)',0DH,0AH
                        DB '2. CARD',0DH,0AH
                        DB 'CHOOSE AN OPTION: $'
    INVALID_PAYMENT_MSG DB 0DH,0AH,'INVALID CHOICE, TRY AGAIN.',0DH,0AH,'$'

    CASH_PROMPT         DB 0DH,0AH,'ENTER CASH AMOUNT FOR COD (RM): $'

    CHANGE_LABEL        DB 'CHANGE: RM $'
    INSUFFICIENT_MSG    DB 0DH,0AH,'THAT IS NOT ENOUGH CASH - CHECKOUT CANCELLED.',0DH,0AH,'$'

    CARD_APPROVED_MSG   DB 'CARD PAYMENT APPROVED.$'

    CASH_TENDERED       DW 0             ; CASH THE CUSTOMER HANDED OVER
    CHANGE_DUE           DW 0             ; CASH_TENDERED - ORDER_DUE

    ; ---------- CARD DETAILS (ASKED FOR CARD PAYMENTS ONLY) ----------
    NAME_PROMPT          DB 0DH,0AH,'ENTER CARDHOLDER NAME: $'
    INVALID_NAME_MSG     DB 0DH,0AH,'INVALID NAME - LETTERS AND SPACES ONLY, TRY AGAIN.',0DH,0AH,'$'

    CARD_NUMBER_PROMPT   DB 'ENTER CARD NUMBER (12-16 DIGITS): $'
    INVALID_CARD_MSG     DB 0DH,0AH,'INVALID CARD NUMBER - DIGITS ONLY, 12-16 OF THEM, TRY AGAIN.',0DH,0AH,'$'

    CVV_PROMPT           DB 'ENTER THE 3-DIGIT CVV (ON THE BACK OF THE CARD): $'
    INVALID_CVV_MSG      DB 0DH,0AH,'INVALID CVV - MUST BE EXACTLY 3 DIGITS, TRY AGAIN.',0DH,0AH,'$'

    ; DOS BUFFERED-INPUT FORMAT: BYTE0 = MAX CHARS, BYTE1 = TOTAL_TYPED, BYTE3-MAXLEN = RESERVED FOR USER INPUT
    NAME_BUF          DB NAME_MAXLEN+1, 0, NAME_MAXLEN+2 DUP(0)
    CARD_NUMBER_BUF   DB CARD_MAXLEN+1, 0, CARD_MAXLEN+2 DUP(0)
    CVV_BUF           DB CVV_MAXLEN+1, 0, CVV_MAXLEN+2 DUP(0)

    DELIVERY_TO_MSG         DB 0DH,0AH,0DH,0AH,'DELIVERING TO: $'
    DELIVERY_ESTIMATE_MSG  DB 0DH,0AH,'ESTIMATION OF DELIVERY: 30MIN',0DH,0AH,'$'

    ; ---------- ORDER HISTORY STORAGE ----------
    ; SLOT I (0 .. HISTORY_COUNT-1) HOLDS ONE PAST CHECKOUT
    ; ARRAY TYPE IN ASM,
    HIST_BURGER   DB MAX_HISTORY DUP(0)
    HIST_NASI     DB MAX_HISTORY DUP(0)
    HIST_RICE     DB MAX_HISTORY DUP(0)
    HIST_CHICKEN  DB MAX_HISTORY DUP(0)
    HIST_TOTAL    DW MAX_HISTORY DUP(0)     ; FINAL AMOUNT ACTUALLY PAID (TAX INCLUDED)
    HISTORY_COUNT DW 0

    ; ---------- ORDER HISTORY SCREEN TEXT ----------
    HISTORY_HEADER    DB 0DH,0AH,'==================================',0DH,0AH
                      DB          '           ORDER HISTORY          ',0DH,0AH
                      DB          '==================================',0DH,0AH,'$'
    HISTORY_EMPTY_MSG DB 0DH,0AH,'NO ORDERS YET - CHECKOUT YOUR CART TO SEE IT HERE.',0DH,0AH,'$'
    ORDER_LABEL       DB 0DH,0AH,0DH,0AH,'ORDER #$'
    SEPARATOR_MSG     DB 0DH,0AH,'----------------------------------',0DH,0AH,'$'
    GRAND_TOTAL_MSG   DB 0DH,0AH,'GRAND TOTAL (ALL ORDERS): RM $'

    GRAND_TOTAL       DW 0          ; SUM OF EVERY PAST ORDER'S TOTAL, FOR HISTORYMODULE

.CODE

EXTRN CLEARSCREEN:NEAR

; =============================================================
; CHECKOUTMODULE
; SHOWS A RECEIPT (ITEMS, SUBTOTAL, DISCOUNT, TAX, TOTAL DUE),
; TAKES PAYMENT, THEN COPIES THE ORDER INTO HISTORY AND EMPTIES
; THE CART. THE CALLER (CARTMODULE) IS THE ONE THAT ALREADY
; CONFIRMED "CHECKOUT NOW? (Y/N)" WITH THE USER.
; =============================================================
CHECKOUTMODULE PROC NEAR

    ; PTR is just a type cast telling dos to treat var as 2 byte
    CMP WORD PTR TOTAL_PRICE, 0  ; is the cart's running total still zero
                                  ; (nothing in the cart)?
    JNE CO_SHOW_RECEIPT          ; total isn't zero -> there's something to
                                  ; check out -> jump ahead to CO_SHOW_RECEIPT
    LEA DX, EMPTY_CART_MSG
    CALL PRINT_STRING
    CALL CO_WAIT_KEY
    RET                           ; cart was empty - return here straight back
                                  ; to whoever called CHECKOUTMODULE
                                  ; (CartModule, in cart.asm)

CO_SHOW_RECEIPT:
    CALL CLEARSCREEN
    LEA DX, CHECKOUT_HEADER
    CALL PRINT_STRING

    CALL CO_PRINT_ITEMS          ; PRINTS THE 4 LIVE CART QUANTITIES

    LEA DX, RECEIPT_SEPARATOR
    CALL PRINT_STRING

    CALL CO_CALC_TAX             ; FILLS IN ORDER_SUBTOTAL, ORDER_TAX AND ORDER_DUE

    LEA DX, SUBTOTAL_LABEL       ; RAW ITEM TOTAL - NO TAX, NO DISCOUNT YET
    CALL PRINT_STRING
    MOV AX, ORDER_SUBTOTAL
    CALL PRINT_NUM

    CMP WORD PTR DISCOUNT_TOTAL, 0  ; was any proximity discount actually
                                     ; applied to this order?
    JE  CO_NO_DISCOUNT_LINE         ; DISCOUNT_TOTAL is 0 (zero flag set) ->
                                     ; nothing was saved -> skip this line
                                     ; entirely
    LEA DX, DISCOUNT_LABEL
    CALL PRINT_STRING
    MOV AX, DISCOUNT_TOTAL
    CALL PRINT_NUM
CO_NO_DISCOUNT_LINE:

    LEA DX, TAX_LABEL
    CALL PRINT_STRING
    MOV AX, ORDER_TAX
    CALL PRINT_NUM

    LEA DX, TOTAL_DUE_LABEL      ; SUBTOTAL - DISCOUNT + TAX, ALL ADDED TOGETHER
    CALL PRINT_STRING
    MOV AX, ORDER_DUE
    CALL PRINT_NUM

    CALL CO_TAKE_PAYMENT         ; ASKS COD/CARD, SHOWS CHANGE IF PAYING COD
    CMP AL, 1                    ; AL = 1 IF PAYMENT WENT THROUGH, 0 IF NOT ENOUGH CASH
    JE  CO_SHOW_DELIVERY         ; AL was 1 -> payment succeeded -> jump ahead;
                                  ; otherwise fall through to the "not enough
                                  ; cash" branch right below

    LEA DX, INSUFFICIENT_MSG
    CALL PRINT_STRING
    CALL CO_WAIT_KEY
    RET                           ; payment failed - return here straight back
                                  ; to the caller (CartModule); the cart is
                                  ; left untouched so checkout can be retried

CO_SHOW_DELIVERY:                 ; PAYMENT WENT THROUGH - SHOW WHERE IT'S GOING
    LEA DX, DELIVERY_TO_MSG
    CALL PRINT_STRING
    LEA DX, CURRENT_ADDR
    CALL PRINT_STRING

    LEA DX, DELIVERY_ESTIMATE_MSG
    CALL PRINT_STRING

CO_SAVE_ORDER:
    MOV AX, HISTORY_COUNT
    CMP AX, MAX_HISTORY           ; is there still a free slot left in the
                                   ; history arrays (count < MAX_HISTORY)?
    JL  CO_STORE                  ; count is (signed) less than MAX_HISTORY ->
                                   ; there's room -> jump to CO_STORE and save
                                   ; it; otherwise fall through and skip saving

    LEA DX, HISTORY_FULL_MSG     ; HISTORY FULL - STILL CHECKOUT, JUST SKIP SAVING IT
    CALL PRINT_STRING
    JMP CO_CLEAR_CART             ; unconditionally skip over CO_STORE (no room
                                   ; to save this order) straight to
                                   ; CO_CLEAR_CART

CO_STORE:
    ; BX = WHICH HISTORY SLOT (0, 1, 2, ...) THIS ORDER GOES INTO.
    ; HIST_BURGER/NASI/RICE/CHICKEN ARE 1 BYTE PER SLOT, SO "SLOT
    ; NUMBER" AND "BYTE OFFSET" ARE THE SAME THING FOR THEM - JUST
    ; ADD BX. HIST_TOTAL IS DIFFERENT (SEE THE SHL BELOW).
    MOV BX, HISTORY_COUNT        ; BX = INDEX OF THE NEW HISTORY SLOT

    LEA SI, HIST_BURGER
    ADD SI, BX
    MOV AL, QTY_BURGER
    MOV [SI], AL

    LEA SI, HIST_NASI
    ADD SI, BX
    MOV AL, QTY_NASI
    MOV [SI], AL

    LEA SI, HIST_RICE
    ADD SI, BX
    MOV AL, QTY_RICE
    MOV [SI], AL

    LEA SI, HIST_CHICKEN
    ADD SI, BX
    MOV AL, QTY_CHICKEN
    MOV [SI], AL

    ; HIST_TOTAL HOLDS 2-BYTE NUMBERS (DW), NOT 1-BYTE (DB) LIKE THE
    ; ITEM COUNTS ABOVE, SO SLOT NUMBER 2 STARTS AT BYTE 4, NOT BYTE
    ; 2. "SHL DI, 1" IS JUST A FAST WAY OF WRITING "DI = DI * 2".
    MOV DI, BX
    SHL DI, 1                    ; DI = DI * 2 in one instruction - shifting
                                  ; left by 1 bit doubles the value (same
                                  ; trick as multiplying by 2 in decimal by
                                  ; adding a 0), needed because HIST_TOTAL
                                  ; holds words, so index*2
    LEA SI, HIST_TOTAL
    ADD SI, DI
    MOV AX, ORDER_DUE            ; SAVE WHAT WAS ACTUALLY CHARGED (TAX INCLUDED)
    MOV [SI], AX

    INC HISTORY_COUNT            ; one more order saved - bump the count of
                                  ; used history slots by 1

CO_CLEAR_CART:
    MOV QTY_BURGER, 0
    MOV QTY_NASI, 0
    MOV QTY_RICE, 0
    MOV QTY_CHICKEN, 0
    MOV WORD PTR TOTAL_PRICE, 0
    MOV WORD PTR DISCOUNT_TOTAL, 0

    LEA DX, SUCCESS_MSG
    CALL PRINT_STRING
    CALL CO_WAIT_KEY
    RET                           ; order placed - return here all the way
                                  ; back to the caller (CartModule), which
                                  ; then returns to the main menu
CHECKOUTMODULE ENDP


; =============================================================
; HISTORYMODULE
; LISTS EVERY ORDER CHECKOUTMODULE HAS SAVED SO FAR, OLDEST FIRST,
; THEN A GRAND TOTAL ADDED UP ACROSS ALL OF THEM.
; =============================================================
HISTORYMODULE PROC NEAR
    MOV GRAND_TOTAL, 0           ; RESET IN CASE THIS GETS SHOWN MORE THAN ONCE

    LEA DX, HISTORY_HEADER
    CALL PRINT_STRING

    MOV CX, HISTORY_COUNT
    CMP CX, 0                    ; is there at least one saved order to list?
    JNE HM_LIST                  ; count isn't zero -> jump to HM_LIST
    LEA DX, HISTORY_EMPTY_MSG
    CALL PRINT_STRING
    JMP HM_DONE                  ; no orders saved - unconditionally skip the
                                  ; whole listing loop below and finish up

HM_LIST:
    MOV BX, 0                    ; BX = INDEX OF THE ORDER BEING PRINTED

HM_LOOP:
    LEA DX, ORDER_LABEL
    CALL PRINT_STRING
    MOV AX, BX
    INC AX                       ; SHOW "ORDER #1", "ORDER #2", ... NOT #0
    CALL PRINT_NUM

    ; --- BURGER ---
    LEA DX, CO_BURGER
    CALL PRINT_STRING
    LEA SI, HIST_BURGER
    ADD SI, BX
    MOV AL, [SI]
    MOV AH, 0                    ; AL IS 0-255, SO WIDEN TO AX BEFORE PRINTING
    CALL PRINT_NUM

    ; --- NASI LEMAK ---
    LEA DX, CO_NASI
    CALL PRINT_STRING
    LEA SI, HIST_NASI
    ADD SI, BX
    MOV AL, [SI]
    MOV AH, 0
    CALL PRINT_NUM

    ; --- EGG FRIED RICE ---
    LEA DX, CO_RICE
    CALL PRINT_STRING
    LEA SI, HIST_RICE
    ADD SI, BX
    MOV AL, [SI]
    MOV AH, 0
    CALL PRINT_NUM

    ; --- FRIED CHICKEN ---
    LEA DX, CO_CHICKEN
    CALL PRINT_STRING
    LEA SI, HIST_CHICKEN
    ADD SI, BX
    MOV AL, [SI]
    MOV AH, 0
    CALL PRINT_NUM

    ; --- TOTAL (TAX ALREADY INCLUDED, SINCE THAT IS WHAT WAS CHARGED) ---
    LEA DX, CO_TOTAL
    CALL PRINT_STRING
    MOV DI, BX
    SHL DI, 1                    ; DI = BX * 2 - same word-index trick as in
                                  ; CO_STORE above
    LEA SI, HIST_TOTAL
    ADD SI, DI
    MOV AX, [SI]
    CALL PRINT_NUM
    ADD GRAND_TOTAL, AX           ; FOLD THIS ORDER INTO THE RUNNING TOTAL

    LEA DX, SEPARATOR_MSG
    CALL PRINT_STRING

    INC BX                        ; move on to the next history slot
    CMP BX, HISTORY_COUNT         ; have we now printed every saved order
                                   ; (BX == count)?
    JGE HM_TOTAL                 ; MASM CAN'T REACH HM_LOOP WITH A SHORT JL FROM
    JMP HM_LOOP                  ; HERE (LOOP BODY IS TOO LONG) - JMP HAS NO SUCH LIMIT

HM_TOTAL:
    LEA DX, GRAND_TOTAL_MSG
    CALL PRINT_STRING
    MOV AX, GRAND_TOTAL
    CALL PRINT_NUM

HM_DONE:
    CALL CO_WAIT_KEY
    RET                           ; back to whoever called HISTORYMODULE
                                  ; (MAIN.ASM's "3. ORDER HISTORY" option)
HISTORYMODULE ENDP

; =============================================================
; LOCAL HELPERS - SAME PATTERN AS CART.ASM'S OWN PRINT HELPERS,
; JUST KEPT PRIVATE TO THIS FILE (CHECKOUT.ASM) SO NOTHING OUTSIDE
; NEEDS TO KNOW THEY EXIST.
; =============================================================

; --- PRINTS THE 4 LIVE CART QUANTITIES (NO TOTAL - CHECKOUTMODULE
;     PRINTS SUBTOTAL/DISCOUNT/TAX/TOTAL DUE ITSELF, RIGHT AFTER
;     CALLING THIS) ---
CO_PRINT_ITEMS PROC NEAR
    LEA DX, CO_BURGER
    CALL PRINT_STRING
    MOV AL, QTY_BURGER
    MOV AH, 0                    ; AL IS 0-255, SO WIDEN TO AX BEFORE PRINTING
    CALL PRINT_NUM

    LEA DX, CO_NASI
    CALL PRINT_STRING
    MOV AL, QTY_NASI
    MOV AH, 0
    CALL PRINT_NUM

    LEA DX, CO_RICE
    CALL PRINT_STRING
    MOV AL, QTY_RICE
    MOV AH, 0
    CALL PRINT_NUM

    LEA DX, CO_CHICKEN
    CALL PRINT_STRING
    MOV AL, QTY_CHICKEN
    MOV AH, 0
    CALL PRINT_NUM
    RET                           ; back to CHECKOUTMODULE, right after its
                                  ; "CALL CO_PRINT_ITEMS" line
CO_PRINT_ITEMS ENDP

; --- WORKS OUT THE PRE-DISCOUNT SUBTOTAL, TAX AND TOTAL DUE.
;     TOTAL_PRICE (FROM CART.ASM) ALREADY HAS THE PROXIMITY DISCOUNT
;     BAKED IN (SEE CALC_PRICE IN CART.ASM), SO ADDING BACK
;     DISCOUNT_TOTAL RECOVERS THE ORIGINAL, UNDISCOUNTED SUBTOTAL.
;     TAX IS 6% OF THE POST-DISCOUNT AMOUNT (TOTAL_PRICE), ROUNDED
;     DOWN TO THE NEAREST RINGGIT. TOTAL DUE IS SUBTOTAL - DISCOUNT
;     + TAX, WHICH SINCE TOTAL_PRICE = SUBTOTAL - DISCOUNT, IS JUST
;     TOTAL_PRICE + TAX.
;
;     THIS ONE STILL HAS TO BE A REAL CALCULATION (NOT HARDCODED)
;     BECAUSE THE ORDER TOTAL CHANGES DEPENDING ON WHAT WAS ORDERED -
;     UNLIKE THE DISCOUNT IN CART.ASM, THERE'S NO FIXED LIST OF
;     "POSSIBLE TOTALS" TO PRE-CALCULATE.
;
;     WORKED EXAMPLE: 2 BURGERS AT A DISCOUNTED RM4 EACH (SEE
;     CALC_PRICE) MEANS TOTAL_PRICE = 8 AND DISCOUNT_TOTAL = 2
;     (RM1 SAVED PER BURGER). SO: SUBTOTAL = 8+2 = RM10, TAX = 8*6/100
;     = RM0 (ROUNDS DOWN), TOTAL DUE = 8+0 = RM8. ---
CO_CALC_TAX PROC NEAR
    PUSH BX                       ; save the caller's BX and DX - this proc
    PUSH DX                       ; uses BX as the MUL/DIV operand and DX as
                                  ; the top half of DX:AX during MUL/DIV, so
                                  ; both must be restored before returning

    MOV AX, TOTAL_PRICE
    ADD AX, DISCOUNT_TOTAL        ; AX = ORIGINAL, PRE-DISCOUNT SUBTOTAL
    MOV ORDER_SUBTOTAL, AX

    MOV AX, TOTAL_PRICE
    MOV BX, TAX_PERCENTAGE
    MUL BX                       ; DX:AX = TOTAL_PRICE * TAX_PERCENTAGE
                                  ; (E.G. RM8 * 6 = 48 - "6% OF RM8" AS A
                                  ; WHOLE NUMBER BEFORE WE DIVIDE BACK DOWN)
    MOV BX, 100
    DIV BX                       ; divides the 32-bit DX:AX by BX (100) - the
                                  ; quotient (the actual tax, rounded down)
                                  ; lands in AX, the remainder lands in DX and
                                  ; is simply not used (E.G. 48 / 100 = 0 IN
                                  ; AX, REMAINDER 48 IN DX, ROUNDED DOWN)
    MOV ORDER_TAX, AX

    MOV AX, TOTAL_PRICE
    ADD AX, ORDER_TAX
    MOV ORDER_DUE, AX

    POP DX                        ; restore the caller's original DX and BX,
    POP BX                        ; in the reverse order they were pushed
    RET                            ; back to CHECKOUTMODULE, right after its
                                  ; "CALL CO_CALC_TAX" line
CO_CALC_TAX ENDP

; --- ASKS COD OR CARD AND COLLECTS PAYMENT.
;     COD ALSO ASKS FOR THE CASH AMOUNT AND SHOWS CHANGE. CARD ASKS
;     FOR THE CARDHOLDER NAME, CARD NUMBER AND CVV (EACH RE-ASKED
;     UNTIL VALID).
;     RETURNS: AL = 1 IF PAYMENT WENT THROUGH, AL = 0 IF THE CASH
;              HANDED OVER WAS NOT ENOUGH (CHECKOUT IS CANCELLED). ---

;?    WHOLE SCRIPT STARTS HERE
CO_TAKE_PAYMENT PROC NEAR
CO_ASK_METHOD:
    LEA DX, PAYMENT_MENU_MSG
    CALL PRINT_STRING

    MOV AH, 01H                  ; READ ONE KEY (1 OR 2)
    INT 21H

    CMP AL, '1'                  ; was the key pressed the character '1'?
    JE  CO_PAY_CASH              ; yes -> jump to CO_PAY_CASH
    CMP AL, '2'                  ; wasn't '1' - was it '2' instead?
    JE  CO_PAY_CARD              ; yes -> jump to CO_PAY_CARD

    LEA DX, INVALID_PAYMENT_MSG
    CALL PRINT_STRING
    JMP CO_ASK_METHOD             ; neither '1' nor '2' - unconditionally loop
                                  ; back and ask again

CO_PAY_CARD:
    CALL CO_READ_NAME             ; CARDHOLDER NAME (LETTERS/SPACES ONLY)
    CALL CO_READ_CARDNUM          ; CARD NUMBER (12-16 DIGITS)
    CALL CO_READ_CVV              ; CVV (EXACTLY 3 DIGITS)

    LEA DX, CARD_APPROVED_MSG
    CALL PRINT_STRING
    MOV AL, 1
    RET                            ; back to CHECKOUTMODULE with AL=1 (success)
                                  ; - this is the value the "CMP AL,1" right
                                  ; after "CALL CO_TAKE_PAYMENT" there checks

CO_PAY_CASH:
    LEA DX, CASH_PROMPT
    CALL PRINT_STRING
    CALL READNUM                 ; AX = CASH AMOUNT TYPED IN (FROM TOOLS.ASM)
    CALL NEWLINE
    MOV CASH_TENDERED, AX

    CMP AX, ORDER_DUE             ; did the customer hand over at least as
                                  ; much as ORDER_DUE?
    JGE CO_CASH_OK                ; AX >= ORDER_DUE (signed) -> enough cash ->
                                  ; jump to CO_CASH_OK
    MOV AL, 0                    ; NOT ENOUGH CASH
    RET                            ; back to CHECKOUTMODULE with AL=0 (fail) -
                                  ; sends it down the "insufficient cash,
                                  ; cancel checkout" path

CO_CASH_OK:
    SUB AX, ORDER_DUE             ; AX = cash handed over minus what was owed
                                  ; = the change to give back
    MOV CHANGE_DUE, AX

    LEA DX, CHANGE_LABEL
    CALL PRINT_STRING
    MOV AX, CHANGE_DUE
    CALL PRINT_NUM

    MOV AL, 1
    RET                            ; back to CHECKOUTMODULE with AL=1 (success)
CO_TAKE_PAYMENT ENDP

; --- ASKS FOR THE CARDHOLDER NAME AND RE-ASKS UNTIL IT IS NOT
;     EMPTY AND CONTAINS ONLY LETTERS AND SPACES. FILLS NAME_BUF. ---
CO_READ_NAME PROC NEAR
CO_READ_NAME_AGAIN:
    LEA DX, NAME_PROMPT
    CALL PRINT_STRING
    LEA DX, NAME_BUF
    CALL READSTRING
    CALL NEWLINE

    MOV CL, NAME_BUF+1           ; ACTUAL NUMBER OF CHARACTERS TYPED
    XOR CH, CH                   ; zero CH so CX holds exactly CL (0-255), not
                                  ; CL plus whatever leftover junk was sitting
                                  ; in CH - CHECK_ALPHA needs the real count
                                  ; in the full CX register
    LEA SI, NAME_BUF+2
    CALL CHECK_ALPHA
    CMP AL, 1                    ; CHECK_ALPHA returns AL=1 only if every
                                  ; character was a letter/space AND there was
                                  ; at least one - was that the case?
    JE  CO_READ_NAME_OK          ; yes -> jump to CO_READ_NAME_OK, done here

    LEA DX, INVALID_NAME_MSG
    CALL PRINT_STRING
    JMP CO_READ_NAME_AGAIN        ; invalid - unconditionally loop back and
                                  ; re-ask

CO_READ_NAME_OK:
    RET                            ; valid name obtained - back to whoever
                                  ; called CO_READ_NAME (CO_TAKE_PAYMENT's
                                  ; card branch)
CO_READ_NAME ENDP

; --- ASKS FOR A CARD NUMBER AND RE-ASKS UNTIL IT IS CARD_MINLEN TO
;     CARD_MAXLEN DIGITS, DIGITS ONLY. FILLS CARD_NUMBER_BUF. ---
CO_READ_CARDNUM PROC NEAR
CO_READ_CARDNUM_AGAIN:
    LEA DX, CARD_NUMBER_PROMPT
    CALL PRINT_STRING
    LEA DX, CARD_NUMBER_BUF
    CALL READSTRING
    CALL NEWLINE

    MOV CL, CARD_NUMBER_BUF+1    ; ACTUAL NUMBER OF CHARACTERS TYPED
    XOR CH, CH                   ; zero CH - same reason as CO_READ_NAME above
    CMP CX, CARD_MINLEN           ; is the number of characters typed at
                                  ; least CARD_MINLEN (12)?
    JB  CO_CARDNUM_INVALID        ; CX is (unsigned) below CARD_MINLEN -> too
                                  ; short -> jump straight to the error,
                                  ; without even checking the digits

    LEA SI, CARD_NUMBER_BUF+2
    CALL CHECK_DIGITS
    CMP AL, 1                    ; did CHECK_DIGITS confirm every character
                                  ; typed was a digit?
    JE  CO_READ_CARDNUM_OK        ; yes -> jump to CO_READ_CARDNUM_OK, done

CO_CARDNUM_INVALID:
    LEA DX, INVALID_CARD_MSG
    CALL PRINT_STRING
    JMP CO_READ_CARDNUM_AGAIN     ; unconditionally loop back and re-ask

CO_READ_CARDNUM_OK:
    RET                            ; valid card number obtained - back to
                                  ; CO_TAKE_PAYMENT's card branch
CO_READ_CARDNUM ENDP

; --- ASKS FOR THE 3-DIGIT CVV AND RE-ASKS UNTIL IT IS EXACTLY
;     CVV_MAXLEN DIGITS, DIGITS ONLY. FILLS CVV_BUF. ---
CO_READ_CVV PROC NEAR
CO_READ_CVV_AGAIN:
    LEA DX, CVV_PROMPT
    CALL PRINT_STRING
    LEA DX, CVV_BUF
    CALL READSTRING
    CALL NEWLINE

    MOV CL, CVV_BUF+1            ; ACTUAL NUMBER OF CHARACTERS TYPED
    XOR CH, CH                   ; zero CH - same reason as above
    CMP CX, CVV_MAXLEN             ; does the typed length exactly equal
                                  ; CVV_MAXLEN (3)? Unlike the card number,
                                  ; the CVV has no range - it must be exactly
                                  ; 3 digits, hence JNE (not JB) below
    JNE CO_CVV_INVALID             ; not exactly 3 -> invalid -> jump straight
                                  ; to the error message

    LEA SI, CVV_BUF+2
    CALL CHECK_DIGITS
    CMP AL, 1                    ; did CHECK_DIGITS confirm all 3 characters
                                  ; were digits?
    JE  CO_READ_CVV_OK            ; yes -> jump to CO_READ_CVV_OK, done

CO_CVV_INVALID:
    LEA DX, INVALID_CVV_MSG
    CALL PRINT_STRING
    JMP CO_READ_CVV_AGAIN         ; unconditionally loop back and re-ask

CO_READ_CVV_OK:
    RET                            ; valid CVV obtained - back to
                                  ; CO_TAKE_PAYMENT's card branch
CO_READ_CVV ENDP

; --- WAITS FOR A KEYPRESS SO THE SCREEN DOESN'T FLY BY ---
CO_WAIT_KEY PROC NEAR
    LEA DX, PAUSE_MSG
    CALL PRINT_STRING
    MOV AH, 07H                   ; DOS function 07H = read one key, no echo
                                  ; (see the QUICK REFERENCE at the top of
                                  ; this file) - the key itself is discarded,
                                  ; this call exists purely to pause
    INT 21H
    RET                            ; back to whoever called CO_WAIT_KEY (used
                                  ; throughout this file right before ITS
                                  ; caller in turn returns)
CO_WAIT_KEY ENDP

END
