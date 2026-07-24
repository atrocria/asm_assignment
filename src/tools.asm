.model small
.stack 100h

; tools.asm
;
; Procedures:
; - PrintLogo
; - PrintString
; - NewLine
; - ClearScreen
; - ReadString
; - ReadNum
; - ExitProgram

PUBLIC PrintLogo
PUBLIC PrintString
PUBLIC NewLine
PUBLIC ClearScreen
PUBLIC ReadString
PUBLIC ReadNum
PUBLIC ExitProgram

.data

logo db 13,10
     db '========================================',13,10
     db '       FOOD DELIVERY SYSTEM             ',13,10
     db '========================================',13,10
     db 13,10
     db '$'

.code

PrintLogo PROC NEAR
    push dx

    lea dx,logo
    call PrintString

    pop dx
    ret
PrintLogo ENDP


PrintString PROC NEAR
    ; Input:
    ; DS:DX = address of a string ending with '$'

    push ax

    mov ah,09h
    int 21h

    pop ax
    ret
PrintString ENDP


ReadString PROC NEAR
    ; Input:
    ; DS:DX = address of DOS input buffer
    ;
    ; Buffer:
    ; byte 0 = maximum length
    ; byte 1 = actual length
    ; byte 2 onward = entered characters
    ;
    ; Adds '$' after the entered text.

    push ax
    push bx
    push si

    mov bx,dx

    mov ah,0Ah
    int 21h

    xor ax,ax
    mov al,[bx+1]

    mov si,bx
    add si,2
    add si,ax

    mov byte ptr [si],'$'

    pop si
    pop bx
    pop ax
    ret
ReadString ENDP


ReadNum PROC NEAR
    ; Reads a positive decimal number.
    ;
    ; Output:
    ; AX = entered number

    push bx
    push cx
    push dx

    xor bx,bx

ReadNumLoop:
    mov ah,01h
    int 21h

    cmp al,13
    je ReadNumDone

    cmp al,'0'
    jb ReadNumLoop

    cmp al,'9'
    ja ReadNumLoop

    sub al,'0'

    xor ah,ah
    mov cx,ax

    mov ax,bx
    mov dx,10
    mul dx

    add ax,cx
    mov bx,ax

    jmp ReadNumLoop

ReadNumDone:
    mov ax,bx

    pop dx
    pop cx
    pop bx
    ret
ReadNum ENDP


NewLine PROC NEAR
    push ax
    push dx

    mov ah,02h

    mov dl,13
    int 21h

    mov dl,10
    int 21h

    pop dx
    pop ax
    ret
NewLine ENDP


ClearScreen PROC NEAR
    push ax
    push bx
    push cx
    push dx

    mov ax,0600h
    mov bh,07h
    mov cx,0000h
    mov dx,184Fh
    int 10h

    mov ah,02h
    mov bh,00h
    mov dx,0000h
    int 10h

    pop dx
    pop cx
    pop bx
    pop ax
    ret
ClearScreen ENDP


ExitProgram PROC NEAR
    mov ax,4C00h
    int 21h
ExitProgram ENDP

END