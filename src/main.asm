.model small
.stack 100h

.data
title db "Food Delivery System$"

.code

EXTRN ClearScreen:NEAR
EXTRN NewLine:NEAR
EXTRN ExitProgram:NEAR
EXTRN PrintLogo:NEAR
EXTRN PrintString:NEAR

main PROC

; main job: loop the whole program and print out logo and present modules

; 1. login/logout 
; 2. order 
; 3. cart 
; 4. checkout 
; 5. login/logout 
; 6. report (only show if atleast one order is made)
; 7. exit

    mov ax,@data
    mov ds,ax

    call ClearScreen

    call PrintLogo

    call NewLine

    call ExitProgram

main ENDP

END main