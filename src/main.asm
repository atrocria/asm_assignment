.model small
.stack 100h

.data
prompt db 'Select your order: $'
pressed db 13, 10, 'Your order is ready: $'
newline db 13, 10, '$'

.code
main proc

    mov ax, @data
    mov ds, ax

    ; print prompt
    mov ah, 09h
    lea dx, prompt
    int 21h

    ; read one key and keep the key on cmd
    mov ah, 01h
    int 21h

    mov bl, al

    ; print result label
    mov ah, 09h
    lea dx, pressed
    int 21h

    ; print the key back
    mov dl, bl
    mov ah, 02h
    int 21h

    ; print newline
    mov ah, 09h
    lea dx, newline
    int 21h

    mov ax, 4C00h
    int 21h

main endp
end main
