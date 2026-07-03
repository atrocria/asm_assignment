.model small
.stack 100h

.data
; msg db 'Hello, World!$'

.code
main proc

    mov ax, @data
    mov ds, ax

    ; print msg
    ; mov ah, 09h
    ; lea dx, msg
    ; int 21h
    
    ; read input
    mov bh, 01h
    int 21h

    ; print input
    mov dl, al
    mov bh, 02h
    int 21h

    mov ax, 4C00h
    int 21h

main endp
end main
