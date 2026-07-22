.model small
.stack 100h

; tools.asm
; │
; ├── PrintString
; ├── NewLine
; ├── ClearScreen
; ├── WaitKey
; ├── ReadChar
; ├── ReadString
; ├── PrintChar
; ├── PrintNumber
; ├── SetCursor
; ├── PrintAt
; ├── Delay
; └── ExitProgram

PUBLIC NewLine
PUBLIC ClearScreen
PUBLIC ExitProgram

.code
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

ExitProgram PROC NEAR
    mov ax,4C00h
    int 21h
ExitProgram ENDP

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
END