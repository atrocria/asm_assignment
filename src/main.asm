.MODEL SMALL
.STACK 100H

.DATA

heading DB "Food Delivery System$"

menu DB 13,10
     DB "========== FOOD DELIVERY SYSTEM ==========",13,10
     DB "1. Login / Logout",13,10
     DB "2. Order",13,10
     DB "3. Cart",13,10
     DB "4. Checkout",13,10
     DB "5. Report",13,10
     DB "6. Exit",13,10
     DB "==========================================",13,10
     DB "Enter your choice: $"

invalidMsg DB 13,10,"Invalid choice!$"

.CODE

main PROC
    mov ax, @data
    mov ds, ax

MainLoop:
    call ClearScreen

    lea dx, heading
    call PrintString
    call NewLine

    lea dx, menu
    call PrintString

    ;等待按键输入
    mov ah, 01h
    int 21h

    call NewLine

    cmp al, '1'
    je LoginFunction
    cmp al, '2'
    je OrderFunction
    cmp al, '3'
    je CartFunction
    cmp al, '4'
    je CheckoutFunction
    cmp al, '5'
    je ReportFunction
    cmp al, '6'
    je ExitFunction

    lea dx, invalidMsg
    call PrintString
    call NewLine
    jmp MainLoop

;====================功能页面入口【在这里添加call】====================
LoginFunction:
    ;call LoginPage
    jmp MainLoop

OrderFunction:
    ;call OrderPage
    jmp MainLoop

CartFunction:
    ;call CartPage
    jmp MainLoop

CheckoutFunction:
    ;call CheckoutPage
    jmp MainLoop

ReportFunction:
    ;call ReportPage
    jmp MainLoop
;======================================================================

ExitFunction:
    call ExitProgram

main ENDP

;====================通用工具函数====================
ClearScreen PROC
    push ax
    push bx
    push cx
    push dx

    mov ah,06h
    mov al,0
    mov bh,07h
    mov ch,0
    mov cl,0
    mov dh,24
    mov dl,79
    int 10h

    mov ah,02h
    mov bh,0
    mov dh,0
    mov dl,0
    int 10h

    pop dx
    pop cx
    pop bx
    pop ax
    ret
ClearScreen ENDP

NewLine PROC
    push dx
    mov ah,02h
    mov dl,13
    int 21h
    mov dl,10
    int 21h
    pop dx
    ret
NewLine ENDP

PrintString PROC
    push ax
    push dx
    mov ah,09h
    int 21h
    pop dx
    pop ax
    ret
PrintString ENDP

ExitProgram PROC
    mov ah,4Ch
    int 21h
    ret
ExitProgram ENDP

;====================各个页面子程序写在下方====================
;LoginPage PROC
;
;LoginPage ENDP

;OrderPage PROC
;
;OrderPage ENDP

END main
