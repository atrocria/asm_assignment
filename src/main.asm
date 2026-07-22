.model small
.stack 100h

.data
title db "Food Delivery System$"

.code

EXTRN ClearScreen:NEAR
EXTRN NewLine:NEAR
EXTRN ExitProgram:NEAR

main PROC

    mov ax,@data
    mov ds,ax

    call ClearScreen

    lea dx,title
    ; call PrintString

    call NewLine

    call ExitProgram

main ENDP

END main