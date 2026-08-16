.MODEL SMALL
.STACK 200h

; Yap chun hong, Loo jun hao, Ong keng jin

.DATA
    MAX_ORDERS  EQU 10
    MAX_MENU    EQU 5

    ; ---------- Screen text ----------
    titleMsg    DB 13,10,"====================================",13,10
                DB "     FOOD DELIVERY ORDER SYSTEM",13,10
                DB "====================================",13,10,"$"

    menuHeader  DB 13,10,"---------- MENU ----------",13,10,"$"
    menuList    DB "1. Burger    - Php 50",13,10
                DB "2. Pizza     - Php 120",13,10
                DB "3. Fries     - Php 30",13,10
                DB "4. Soda      - Php 20",13,10
                DB "5. Salad     - Php 45",13,10,"$"

    ; fixed-length ($-terminated) item name table, 11 bytes per entry
    itemNames   DB "Burger    $"
                DB "Pizza     $"
                DB "Fries     $"
                DB "Soda      $"
                DB "Salad     $"
    ITEM_LEN    EQU 11

    itemPrices  DW 50,120,30,20,45

    promptName  DB 13,10,"Enter your username: $"
    promptItem  DB 13,10,"Enter item number (1-5): $"
    promptQty   DB 13,10,"Enter quantity: $"
    promptMore  DB 13,10,"Order more items? (Y/N): $"
    invalidMsg  DB 13,10,"Invalid input, try again.",13,10,"$"
    maxMsg      DB 13,10,"Maximum orders reached.",13,10,"$"

    reportHdr   DB 13,10,"====================================",13,10
                DB "            ORDER REPORT",13,10
                DB "====================================",13,10,"$"
    lblUser     DB 13,10,"username: $"
    lblTotal    DB 13,10,"total orders: $"
    lblGrand    DB 13,10,"Grand total: Php $"
    newline     DB 13,10,"$"
    xLabel      DB " x $"
    eqLabel     DB " = Php $"

    ; ---------- Input buffers (DOS buffered-input format) ----------
    nameBuf     DB 21
                DB ?
                DB 21 DUP('$')

    inputBuf    DB 7
                DB ?
                DB 7 DUP('$')

    ; ---------- Order storage ----------
    orderItem   DB MAX_ORDERS DUP(0)   ; menu index (1-5) per order line
    orderQty    DW MAX_ORDERS DUP(0)   ; quantity per order line
    orderCount  DW 0
    grandTotal  DW 0

.CODE
MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    CALL PRINT_TITLE
    CALL GET_USERNAME
    CALL SHOW_MENU
    CALL TAKE_ORDERS
    CALL CALC_TOTAL
    CALL PRINT_REPORT

    MOV AH, 4Ch
    INT 21h
MAIN ENDP

; =========================================================================
; MODULE: PRINT_TITLE
; =========================================================================
PRINT_TITLE PROC
    LEA DX, titleMsg
    MOV AH, 09h
    INT 21h
    RET
PRINT_TITLE ENDP

; =========================================================================
; MODULE: GET_USERNAME
; =========================================================================
GET_USERNAME PROC
    LEA DX, promptName
    MOV AH, 09h
    INT 21h

    LEA DX, nameBuf
    MOV AH, 0Ah
    INT 21h

    ; terminate the entered text with '$' so it can be printed later
    LEA BX, nameBuf
    MOV CL, [BX+1]
    MOV CH, 0
    LEA SI, nameBuf+2
    ADD SI, CX
    MOV BYTE PTR [SI], '$'
    RET
GET_USERNAME ENDP

; =========================================================================
; MODULE: SHOW_MENU
; =========================================================================
SHOW_MENU PROC
    LEA DX, menuHeader
    MOV AH, 09h
    INT 21h

    LEA DX, menuList
    MOV AH, 09h
    INT 21h
    RET
SHOW_MENU ENDP

; =========================================================================
; MODULE: TAKE_ORDERS
; =========================================================================
TAKE_ORDERS PROC
ORDER_LOOP:
    MOV AX, orderCount
    CMP AX, MAX_ORDERS
    JL  CONTINUE_ORDER
    LEA DX, maxMsg
    MOV AH, 09h
    INT 21h
    JMP DONE_ORDERS

CONTINUE_ORDER:
    LEA DX, promptItem
    MOV AH, 09h
    INT 21h
    CALL READ_NUMBER
    CMP AX, 1
    JL  BAD_ITEM
    CMP AX, MAX_MENU
    JG  BAD_ITEM
    MOV BX, AX
    JMP GET_QTY

BAD_ITEM:
    LEA DX, invalidMsg
    MOV AH, 09h
    INT 21h
    JMP ORDER_LOOP

GET_QTY:
    LEA DX, promptQty
    MOV AH, 09h
    INT 21h
    CALL READ_NUMBER
    CMP AX, 1
    JL  BAD_QTY
    JMP STORE_ORDER

BAD_QTY:
    LEA DX, invalidMsg
    MOV AH, 09h
    INT 21h
    JMP ORDER_LOOP

STORE_ORDER:
    PUSH AX                 ; quantity
    MOV DI, orderCount

    LEA SI, orderItem
    ADD SI, DI
    MOV [SI], BL            ; store item number (1-5)

    LEA SI, orderQty
    SHL DI, 1
    ADD SI, DI
    POP AX
    MOV [SI], AX            ; store quantity

    INC orderCount

    LEA DX, promptMore
    MOV AH, 09h
    INT 21h
    LEA DX, inputBuf
    MOV AH, 0Ah
    INT 21h

    LEA BX, inputBuf
    MOV AL, [BX+2]
    AND AL, 0DFh            ; uppercase
    CMP AL, 'Y'
    JNE DONE_ORDERS
    JMP ORDER_LOOP

DONE_ORDERS:
    RET
TAKE_ORDERS ENDP

; =========================================================================
; MODULE: READ_NUMBER  -> returns unsigned value in AX
; =========================================================================
READ_NUMBER PROC
    LEA DX, inputBuf
    MOV AH, 0Ah
    INT 21h

    LEA BX, inputBuf
    MOV CL, [BX+1]
    MOV CH, 0
    LEA SI, inputBuf+2
    MOV AX, 0

RN_LOOP:
    CMP CX, 0
    JE  RN_DONE
    MOV DL, [SI]
    CMP DL, '0'
    JL  RN_DONE
    CMP DL, '9'
    JG  RN_DONE

    SUB DL, '0'
    MOV DH, 0
    PUSH DX
    MOV DX, 10
    MUL DX
    POP DX
    ADD AX, DX

    INC SI
    DEC CX
    JMP RN_LOOP

RN_DONE:
    RET
READ_NUMBER ENDP

; =========================================================================
; MODULE: CALC_TOTAL
; =========================================================================
CALC_TOTAL PROC
    MOV grandTotal, 0
    MOV CX, orderCount
    CMP CX, 0
    JE  CT_DONE
    MOV DI, 0

CT_LOOP:
    LEA SI, orderItem
    ADD SI, DI
    MOV AL, [SI]
    DEC AL
    MOV AH, 0
    SHL AX, 1
    LEA BX, itemPrices
    ADD BX, AX
    MOV AX, [BX]             ; unit price

    MOV DX, DI
    SHL DX, 1
    LEA BX, orderQty
    ADD BX, DX
    MOV BX, [BX]             ; quantity

    MUL BX
    ADD grandTotal, AX

    INC DI
    LOOP CT_LOOP

CT_DONE:
    RET
CALC_TOTAL ENDP

; =========================================================================
; MODULE: PRINT_REPORT
;   username: {username}
;   total orders: {count}
;   {item} x {qty} = Php {line total}   (repeated)
;   Grand total: Php {grandTotal}
; =========================================================================
PRINT_REPORT PROC
    LEA DX, reportHdr
    MOV AH, 09h
    INT 21h

    LEA DX, lblUser
    MOV AH, 09h
    INT 21h
    LEA DX, nameBuf+2
    MOV AH, 09h
    INT 21h

    LEA DX, lblTotal
    MOV AH, 09h
    INT 21h
    MOV AX, orderCount
    CALL PRINT_NUMBER

    LEA DX, newline
    MOV AH, 09h
    INT 21h

    MOV CX, orderCount
    CMP CX, 0
    JNE PR_HAS_ORDERS
    JMP PR_TOTAL
PR_HAS_ORDERS:
    MOV DI, 0

PR_LOOP:
    ; ---- item name ----
    LEA SI, orderItem
    ADD SI, DI
    MOV AL, [SI]
    DEC AL
    MOV AH, 0
    MOV BL, ITEM_LEN
    MUL BL
    LEA BX, itemNames
    ADD BX, AX
    MOV DX, BX
    MOV AH, 09h
    INT 21h

    ; ---- " x " ----
    LEA DX, xLabel
    MOV AH, 09h
    INT 21h

    ; ---- quantity ----
    MOV DX, DI
    SHL DX, 1
    LEA BX, orderQty
    ADD BX, DX
    MOV AX, [BX]
    CALL PRINT_NUMBER

    ; ---- " = Php " ----
    LEA DX, eqLabel
    MOV AH, 09h
    INT 21h

    ; ---- line total = price * qty ----
    LEA SI, orderItem
    ADD SI, DI
    MOV AL, [SI]
    DEC AL
    MOV AH, 0
    SHL AX, 1
    LEA BX, itemPrices
    ADD BX, AX
    MOV AX, [BX]

    MOV DX, DI
    SHL DX, 1
    LEA BX, orderQty
    ADD BX, DX
    MOV BX, [BX]
    MUL BX
    CALL PRINT_NUMBER

    LEA DX, newline
    MOV AH, 09h
    INT 21h

    INC DI
    DEC CX
    JZ  PR_LOOP_END
    JMP PR_LOOP
PR_LOOP_END:

PR_TOTAL:
    LEA DX, lblGrand
    MOV AH, 09h
    INT 21h
    MOV AX, grandTotal
    CALL PRINT_NUMBER
    LEA DX, newline
    MOV AH, 09h
    INT 21h
    RET
PRINT_REPORT ENDP

; =========================================================================
; MODULE: PRINT_NUMBER  -> prints unsigned word in AX as decimal digits
; =========================================================================
PRINT_NUMBER PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV CX, 0
    MOV BX, 10

    CMP AX, 0
    JNE PN_CONVERT
    MOV DL, '0'
    MOV AH, 02h
    INT 21h
    JMP PN_DONE

PN_CONVERT:
    CMP AX, 0
    JE  PN_PRINT
    MOV DX, 0
    DIV BX
    PUSH DX
    INC CX
    JMP PN_CONVERT

PN_PRINT:
    CMP CX, 0
    JE  PN_DONE
    POP DX
    ADD DL, '0'
    MOV AH, 02h
    INT 21h
    DEC CX
    JMP PN_PRINT

PN_DONE:
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_NUMBER ENDP

END MAIN