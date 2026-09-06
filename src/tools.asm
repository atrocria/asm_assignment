; =================================================================
; TOOLS.ASM
;
; SHARED LOW-LEVEL HELPERS USED BY EVERY OTHER FILE IN THIS PROJECT.
; THIS IS THE FILE WHERE THE CODE TALKS DIRECTLY TO DOS (VIA "INT
; 21H") AND THE PC's VIDEO BIOS (VIA "INT 10H") TO DO KEYBOARD INPUT,
; SCREEN OUTPUT, AND SIMPLE STRING/NUMBER WORK. NOTHING IN HERE KNOWS
; ANYTHING ABOUT LOGIN, THE MENU, THE CART OR CHECKOUT - IT'S ALL
; GENERIC PLUMBING THAT ANY OF THOSE FILES CAN CALL.
;
; WHAT "INT 21H" AND "INT 10H" MEAN, IN SHORT: A REAL 8086 CPU HAS NO
; BUILT-IN WAY TO "PRINT TEXT" OR "READ A KEY" - THOSE ARE SERVICES
; THE OPERATING SYSTEM (DOS) AND THE PC's BIOS PROVIDE INSTEAD. "INT
; 21H" MEANS "INTERRUPT THE CPU AND HAND CONTROL TO DOS'S SERVICE
; ROUTINE" - YOU PUT A FUNCTION NUMBER IN THE AH REGISTER FIRST (E.G.
; AH=09H MEANS "PRINT A STRING"), PUT ANY EXTRA ARGUMENTS DOS NEEDS
; INTO OTHER REGISTERS, THEN "INT 21H" JUMPS INTO DOS, DOS DOES THE
; WORK, AND CONTROL COMES BACK TO THE LINE RIGHT AFTER INT 21H. "INT
; 10H" IS THE SAME IDEA BUT TALKS TO THE VIDEO BIOS INSTEAD OF DOS
; (USED ONLY BY CLEARSCREEN BELOW).
; =================================================================

.MODEL SMALL

; ---------- WHAT THIS FILE MAKES AVAILABLE TO OTHER .ASM FILES ----------
; PUBLIC MEANS "OTHER FILES ARE ALLOWED TO CALL THIS" - IT'S THE
; OPPOSITE OF EXTRN, WHICH IS HOW THOSE OTHER FILES THEN ASK FOR IT
; (E.G. LOGIN.ASM HAS "EXTRN PRINT_STRING:NEAR" NEAR ITS TOP).
PUBLIC NEWLINE          ; prints CR+LF (moves the cursor to a new line)
PUBLIC CLEARSCREEN      ; blanks the screen, cursor back to top-left
PUBLIC READSTRING       ; reads a whole typed line into a buffer
PUBLIC READNUM          ; reads typed digits, returns them as a number in AX
PUBLIC EXITPROGRAM      ; quits straight back to DOS
PUBLIC PRINT_STRING, PRINT_CHAR, PRINT_NUM   ; the 3 ways to print something
PUBLIC COPY_STRING, CLEAR_BUF, STR_COMPARE   ; basic '$'-string helpers
PUBLIC CHECK_ALPHA, CHECK_DIGITS             ; input-validation helpers

.CODE

;-------------------------------------------------------------
; READSTRING  -  READS ONE LINE OF TYPED TEXT USING DOS'S OWN
; "BUFFERED KEYBOARD INPUT" FUNCTION, THEN TURNS THE RESULT INTO A
; NORMAL '$'-TERMINATED STRING (WHAT PRINT_STRING/COPY_STRING/
; STR_COMPARE ALL EXPECT TO WORK WITH).
;
; INPUT:  DS:DX = ADDRESS OF A BUFFER THAT THE CALLER MUST ALREADY
;         HAVE SET UP LIKE THIS BEFORE CALLING:
;             BYTE 0 = MAXIMUM NUMBER OF CHARACTERS DOS MAY ACCEPT
;             BYTE 1 = (DOS FILLS THIS IN) HOW MANY WERE ACTUALLY TYPED
;             BYTE 2 ONWARD = (DOS FILLS THIS IN) THE TYPED CHARACTERS
;         AFTER THIS PROC RETURNS, A '$' HAS BEEN ADDED RIGHT AFTER
;         THE TYPED TEXT, SO THE SAME BUFFER (STARTING AT BYTE 2) IS
;         NOW ALSO A NORMAL '$'-TERMINATED STRING.
;-------------------------------------------------------------
READSTRING PROC NEAR
    ; INPUT:
    ; DS:DX = ADDRESS OF DOS INPUT BUFFER
    ;
    ; BUFFER:
    ; BYTE 0 = MAXIMUM LENGTH
    ; BYTE 1 = ACTUAL LENGTH
    ; BYTE 2 ONWARD = ENTERED CHARACTERS
    ;
    ; ADDS '$' AFTER THE ENTERED TEXT.

    ; SAVE THE CALLER'S REGISTERS - THIS PROC BORROWS AX, BX AND SI AS
    ; SCRATCH SPACE, SO THEY'RE PUT BACK BEFORE RETURNING.
    PUSH AX
    PUSH BX
    PUSH SI

    MOV BX,DX                  ; KEEP THE BUFFER ADDRESS SAFE IN BX - DX
                                ; ITSELF IS ABOUT TO BE NEEDED BY INT 21H

    MOV AH,0AH                 ; DOS FUNCTION 0AH = "BUFFERED KEYBOARD
                                ; INPUT": READS CHARACTERS (ECHOING THEM TO
                                ; THE SCREEN AS THEY'RE TYPED) UNTIL ENTER
                                ; IS PRESSED
    INT 21H                    ; DS:DX STILL POINTS AT THE BUFFER - DOS
                                ; FILLS IN BYTE 1 (COUNT) AND BYTES 2..
                                ; (THE ACTUAL CHARACTERS)

    XOR AX,AX                  ; AX = 0, THEN...
    MOV AL,[BX+1]               ; ...AL = HOW MANY CHARACTERS DOS JUST READ
                                 ; (BYTE 1 OF THE BUFFER), SO AX NOW HOLDS
                                 ; THAT COUNT AS A FULL 16-BIT NUMBER

    MOV SI,BX                  ; SI = START OF THE BUFFER...
    ADD SI,2                   ; ...MOVED PAST THE 2 HEADER BYTES...
    ADD SI,AX                  ; ...AND PAST ALL THE TYPED CHARACTERS, SO SI
                                ; NOW POINTS EXACTLY ONE BYTE PAST THE LAST
                                ; CHARACTER DOS WROTE - THAT'S WHERE THE
                                ; TERMINATOR NEEDS TO GO

    MOV BYTE PTR [SI],'$'      ; DROP A '$' RIGHT THERE, TURNING THE TYPED
                                ; TEXT INTO A NORMAL '$'-TERMINATED STRING

    ; RESTORE THE CALLER'S REGISTERS, IN REVERSE ORDER OF HOW THEY WERE
    ; PUSHED (THAT'S JUST HOW A STACK WORKS - LAST IN, FIRST OUT)
    POP SI
    POP BX
    POP AX
    RET
READSTRING ENDP


;-------------------------------------------------------------
; READNUM  -  READS DIGITS TYPED ONE KEY AT A TIME (NOT DOS'S
; BUFFERED INPUT LIKE READSTRING - THIS PROC READS AND ECHOES EACH
; KEY ITSELF) UNTIL ENTER IS PRESSED, BUILDING THEM UP INTO A SINGLE
; NUMBER AS IT GOES. ANY NON-DIGIT KEY IS SIMPLY IGNORED.
;
; OUTPUT: AX = THE NUMBER THAT WAS TYPED (0 IF NOTHING VALID WAS)
;
; THE TRICK FOR TURNING TYPED DIGITS INTO A NUMBER: EVERY TIME A NEW
; DIGIT COMES IN, THE NUMBER SO FAR IS MULTIPLIED BY 10 AND THE NEW
; DIGIT IS ADDED ON. E.G. TYPING "1", THEN "2", THEN "3" DOES:
; 0*10+1=1, THEN 1*10+2=12, THEN 12*10+3=123. THIS IS THE STANDARD
; WAY ANY PROGRAM, IN ANY LANGUAGE, TURNS TYPED DIGITS INTO A NUMBER.
;-------------------------------------------------------------
READNUM PROC NEAR
    ; READS A POSITIVE DECIMAL NUMBER.
    ;
    ; OUTPUT:
    ; AX = ENTERED NUMBER

    PUSH BX
    PUSH CX
    PUSH DX

    XOR BX,BX                  ; BX = THE NUMBER BUILT UP SO FAR, STARTS AT 0

READNUMLOOP:
    MOV AH,01H                 ; DOS FUNCTION 01H = "READ ONE KEY, WITH ECHO"
    INT 21H                    ; AL = THE KEY THAT WAS JUST PRESSED

    CMP AL,13                  ; 13 = THE ENTER KEY'S CODE (CARRIAGE RETURN)
    JE READNUMDONE              ; ENTER WAS PRESSED - STOP, WE'RE DONE

    CMP AL,'0'                 ; IS THE TYPED CHARACTER BELOW '0'...
    JB READNUMLOOP              ; ...IF SO IT'S NOT A DIGIT - IGNORE IT, LOOP

    CMP AL,'9'                 ; ...OR ABOVE '9'...
    JA READNUMLOOP              ; ...ALSO NOT A DIGIT - IGNORE IT, LOOP

    SUB AL,'0'                  ; IT IS A DIGIT CHARACTER ('0'-'9') - SUBTRACT
                                 ; THE CODE FOR '0' TO TURN IT INTO THE REAL
                                 ; NUMBER 0-9 (E.G. THE CHARACTER '7' MINUS
                                 ; THE CHARACTER '0' GIVES THE NUMBER 7)

    XOR AH,AH                   ; AH = 0, SO AX = THAT DIGIT AS A CLEAN
                                 ; 16-BIT NUMBER (0-9), NOT JUST ONE BYTE
    MOV CX,AX                   ; STASH THE NEW DIGIT IN CX - AX IS ABOUT TO
                                 ; BE OVERWRITTEN BY THE MULTIPLY BELOW

    MOV AX,BX                   ; AX = THE NUMBER BUILT UP SO FAR
    MOV DX,10
    MUL DX                      ; DX:AX = AX * 10 (SHIFT THE NUMBER SO FAR
                                 ; ONE DECIMAL PLACE LEFT). THE RESULT ALWAYS
                                 ; FITS IN AX ALONE HERE (COD CASH AMOUNTS,
                                 ; CARD NUMBERS ETC. NEVER GET THAT BIG), SO
                                 ; DX (THE OVERFLOW HALF) IS SIMPLY IGNORED

    ADD AX,CX                   ; ADD THE NEW DIGIT BACK ON - THE "+3" PART
                                 ; OF "12*10+3=123" FROM THE COMMENT ABOVE
    MOV BX,AX                   ; SAVE THE UPDATED NUMBER BACK INTO BX

    JMP READNUMLOOP             ; GO READ THE NEXT KEY

READNUMDONE:
    MOV AX,BX                   ; RETURN THE FINISHED NUMBER IN AX

    POP DX
    POP CX
    POP BX
    RET
READNUM ENDP

;-------------------------------------------------------------
; NEWLINE  -  MOVES THE CURSOR TO THE START OF THE NEXT LINE, THE
; SAME WAY PRESSING ENTER WOULD. DOS TEXT OUTPUT NEEDS *BOTH* OF
; THESE CHARACTERS - CARRIAGE RETURN (MOVE TO COLUMN 0) AND LINE
; FEED (MOVE DOWN ONE ROW). PRINTING ONLY ONE OF THEM ON ITS OWN
; WOULD EITHER OVERWRITE THE CURRENT LINE OR INDENT THE NEXT ONE -
; THAT'S WHY EVERY STRING IN THIS PROJECT THAT ENDS A LINE ALSO USES
; BOTH (WRITTEN AS 0DH,0AH).
;-------------------------------------------------------------
NEWLINE PROC NEAR
    ; SAVING PREV REGISTERS TO JUMP BACK INTO
    PUSH AX
    PUSH DX

    ; PRINT INSTRUCTION
    MOV AH, 02H                 ; DOS FUNCTION 02H = "PRINT ONE CHARACTER" -
                                 ; THE CHARACTER ITSELF GOES IN DL

    ; CARRIAGE RETURN
    MOV DL, 13                  ; 13 = CARRIAGE RETURN - CURSOR TO COLUMN 0
    INT 21H

    ; LINE FEED
    MOV DL,10                   ; 10 = LINE FEED - CURSOR DOWN ONE ROW
    INT 21H

    ; RETURN VALUES BACK
    POP DX
    POP AX
    RET
NEWLINE ENDP


; CLEARSCREEN  -  BLANKS THE WHOLE SCREEN AND PUTS THE CURSOR BACK
; AT THE TOP-LEFT CORNER, USING THE BIOS VIDEO INTERRUPT (INT 10H)
; INSTEAD OF PRINTING A SCREEN'S WORTH OF BLANK LINES OURSELVES.
CLEARSCREEN PROC NEAR

    ; SAVING PREV REGISTERS TO JUMP BACK INTO - BOTH INT 10H CALLS BELOW
    ; OVERWRITE AX, BX, CX AND DX, SO ALL 4 ARE SAVED HERE
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; BIOS FUNCTION 06H = "SCROLL WINDOW UP". AX=0600H WITH CX/DX
    ; COVERING THE WHOLE 80x25 SCREEN (CX=TOP-LEFT 0,0 - DX=BOTTOM-
    ; RIGHT 79,24, I.E. HEX 18,4F) MEANS "SCROLL THE ENTIRE SCREEN BY
    ; 0 LINES" - WHICH DOS TREATS AS "BLANK THE WHOLE THING". BH IS
    ; THE COLOUR (07H = LIGHT GREY ON BLACK) USED TO FILL IT.
    MOV AX,0600H                ; AH=06H (SCROLL UP FUNCTION), AL=00H
                                 ; (SCROLL BY 0 LINES = CLEAR EVERYTHING)
    MOV BH,07H                  ; BH = FILL COLOUR FOR THE NOW-BLANK AREA
    MOV CX,0000H                ; CH,CL = ROW,COLUMN OF THE TOP-LEFT CORNER
    MOV DX,184FH                ; DH,DL = ROW,COLUMN OF THE BOTTOM-RIGHT
                                 ; CORNER (18H=24, 4FH=79 - THE LAST ROW/
                                 ; COLUMN OF AN 80x25 SCREEN)
    INT 10H

    ; BIOS FUNCTION 02H = "SET CURSOR POSITION". DX=0000H MOVES THE
    ; CURSOR BACK TO ROW 0, COLUMN 0 (TOP-LEFT) SO THE NEXT THING
    ; PRINTED STARTS FROM A CLEAN SCREEN.
    MOV AH,02H                  ; AH=02H = "SET CURSOR POSITION"
    MOV BH,00H                  ; BH = WHICH VIDEO PAGE (ALWAYS 0 HERE)
    MOV DX,0000H                ; DH,DL = ROW,COLUMN TO MOVE THE CURSOR TO
    INT 10H

    POP DX
    POP CX
    POP BX
    POP AX
    RET
CLEARSCREEN ENDP


;-------------------------------------------------------------
; EXITPROGRAM  -  IMMEDIATELY QUITS BACK TO DOS. (NOT CURRENTLY
; CALLED FROM ANYWHERE ELSE IN THIS PROJECT - MAIN.ASM'S OPT_QUIT
; DOES THE SAME THING DIRECTLY INSTEAD - BUT IT'S KEPT HERE AS A
; READY-TO-USE HELPER.)
;-------------------------------------------------------------
EXITPROGRAM PROC NEAR
    MOV AX,4C00H                ; AH=4CH IS DOS'S "TERMINATE PROGRAM"
                                 ; FUNCTION; AL (THE LOW BYTE, HERE 00H) IS
                                 ; THE EXIT CODE OTHER PROGRAMS/BATCH FILES
                                 ; CAN CHECK - 00H CONVENTIONALLY MEANS
                                 ; "FINISHED WITH NO ERROR"
    INT 21H
EXITPROGRAM ENDP

; =================================================================
; THE HELPERS BELOW ARE SHARED BY EVERY OTHER .ASM FILE IN THIS
; PROJECT - PRINTING TEXT/CHARACTERS/NUMBERS, COPYING OR CLEARING A
; '$'-TERMINATED STRING, COMPARING TWO OF THEM, AND CHECKING WHAT
; KIND OF CHARACTERS A TYPED-IN STRING CONTAINS. NOTHING HERE IS
; SPECIFIC TO LOGIN, CART, MENU OR CHECKOUT - THAT'S WHY THEY LIVE
; HERE INSTEAD OF BEING COPIED INTO EACH FILE THAT NEEDS THEM.
; =================================================================

PRINT_STRING PROC NEAR
    ; PRINTS A '$'-TERMINATED STRING.
    ; INPUT: DS:DX = ADDRESS OF THE STRING
    PUSH AX                      ; DOS FUNCTION 09H OVERWRITES AH, SO SAVE
                                  ; WHATEVER THE CALLER HAD IN AX FIRST
    MOV AH, 09H                  ; DOS FUNCTION 09H = "PRINT STRING": PRINTS
                                  ; EVERY CHARACTER STARTING AT DS:DX UNTIL
                                  ; IT HITS '$' - WHICH IS WHY EVERY STRING
                                  ; IN THIS PROJECT ENDS WITH '$' INSTEAD OF
                                  ; A NUL BYTE (THAT'S JUST HOW THIS ONE DOS
                                  ; FUNCTION MARKS "END OF STRING")
    INT 21H
    POP AX                       ; GIVE THE CALLER BACK THEIR ORIGINAL AX
    RET
PRINT_STRING ENDP


PRINT_CHAR PROC NEAR
    ; PRINTS ONE CHARACTER.
    ; INPUT: DL = THE CHARACTER
    PUSH AX                      ; SAME REASON AS PRINT_STRING ABOVE - DOS
                                  ; FUNCTION 02H OVERWRITES AH
    MOV AH, 02H                  ; DOS FUNCTION 02H = "PRINT ONE CHARACTER"
    INT 21H
    POP AX
    RET
PRINT_CHAR ENDP


; PRINT_NUM  -  PRINTS THE 16-BIT NUMBER IN AX IN DECIMAL.
;
; THE TRICK: DIVIDING BY 10 REPEATEDLY GIVES YOU THE DIGITS BACKWARDS
; (THE REMAINDER EACH TIME IS THE *LAST* DIGIT - E.G. 123 / 10 = 12
; REMAINDER 3, SO '3' COMES OUT FIRST, THEN '2', THEN '1'). BUT A
; NUMBER HAS TO BE PRINTED FIRST-DIGIT-FIRST. SO EACH DIGIT IS PUSHED
; ONTO THE STACK AS IT'S FOUND (CONVERT_LOOP), THEN POPPED BACK OFF
; (PRINT_LOOP) - AND SINCE A STACK IS LAST-IN-FIRST-OUT, POPPING
; REVERSES THE ORDER A SECOND TIME, WHICH PUTS THE DIGITS BACK THE
; RIGHT WAY ROUND. CX COUNTS HOW MANY DIGITS WERE PUSHED, SO
; PRINT_LOOP KNOWS EXACTLY HOW MANY TO POP.
PRINT_NUM PROC NEAR
    ; SAVE EVERY REGISTER THIS PROC USES, SO PRINTING A NUMBER NEVER
    ; DISTURBS WHATEVER THE CALLER WAS DOING WITH THEM
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    XOR CX, CX                 ; Digit counter = 0
    MOV BX, 10                 ; the divisor - always 10, since we're
                                ; printing in base 10 (decimal)

CONVERT_LOOP:
    XOR DX, DX                 ; DIV BX divides the 32-bit pair DX:AX by
                                ; BX, so DX (the upper half) must be
                                ; cleared first - otherwise it would divide
                                ; some leftover garbage number instead of
                                ; just the value in AX
    DIV BX                     ; Divide AX by 10 (Remainder in DX) - the
                                ; remainder is the last decimal digit of
                                ; whatever's currently left in AX
    PUSH DX                    ; Push remainder onto stack
    INC CX                     ; one more digit found - remember it so
                                ; PRINT_LOOP below knows how many to pop
    CMP AX, 0                  ; is there anything left of the number...
    JNE CONVERT_LOOP           ; ...if so, peel off another digit

PRINT_LOOP:
    POP DX                     ; take the digits back off in reverse order
                                ; - the LAST one pushed (the FIRST digit of
                                ; the actual number) comes off FIRST
    ADD DL, '0'                ; Convert digit to ASCII - the digits were
                                ; stored as plain numbers 0-9, not text, so
                                ; this turns e.g. the number 7 into the
                                ; character '7'
    MOV AH, 02H                ; print that one digit (DOS function 02H)
    INT 21H
    LOOP PRINT_LOOP            ; LOOP decrements CX and repeats while it's
                                ; not yet 0 - so this runs exactly once per
                                ; digit that CONVERT_LOOP pushed

    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_NUM ENDP


;-------------------------------------------------------------
; COPY_STRING  -  COPIES A '$'-TERMINATED STRING FROM SI TO DI,
; INCLUDING THE '$' ITSELF, SO THE COPY IS ALSO A VALID '$'-
; TERMINATED STRING AFTERWARDS.
; IN: SI = SOURCE ADDRESS, DI = DESTINATION ADDRESS
; (NEITHER ADDRESS IS SIZE-CHECKED - IT'S UP TO THE CALLER TO MAKE
; SURE THE DESTINATION HAS ENOUGH ROOM.)
;-------------------------------------------------------------
COPY_STRING PROC
CS_LOOP:
    MOV AL, [SI]                ; AL = the next character from the source
    MOV [DI], AL                ; write it to the destination
    INC SI                      ; move both pointers along one byte...
    INC DI                      ; ...ready for the next character
    CMP AL, '$'                 ; was the character we just copied the '$'
                                 ; terminator?
    JE  CS_DONE                 ; yes - that was the last byte, stop here
    JMP CS_LOOP                 ; no - there's more string left, keep going
CS_DONE:
    RET
COPY_STRING ENDP


;-------------------------------------------------------------
; CLEAR_BUF  -  WRITES CX ZERO BYTES STARTING AT DI. USED TO WIPE A
; BUFFER (E.G. LOGIN.ASM'S LOGOUT USES THIS TO ERASE THE TYPED
; USERNAME/PASSWORD SO THE NEXT PERSON CAN'T SEE THEM).
; IN: DI = START ADDRESS, CX = HOW MANY BYTES TO ZERO
;-------------------------------------------------------------
CLEAR_BUF PROC
    XOR AL, AL                  ; AL = 0 - the value we're going to write
                                 ; over and over
CB_LOOP:
    MOV [DI], AL                ; zero out this byte
    INC DI                      ; move to the next byte
    LOOP CB_LOOP                ; LOOP decrements CX and repeats while it's
                                 ; not yet 0 - so this runs exactly CX times
    RET
CLEAR_BUF ENDP


;-------------------------------------------------------------
; STR_COMPARE  -  SI, DI = '$'-TERMINATED STRINGS. AL=1 IF EQUAL.
;
; ON PURPOSE, THIS USES DL (NOT BL) AS SCRATCH SPACE FOR THE
; CHARACTER IT'S CURRENTLY LOOKING AT. BX IS VERY OFTEN USED BY
; THE *CALLER* TO HOLD A POINTER (SEE FIND_USER BELOW, WHICH KEEPS
; A USER_DB RECORD ADDRESS IN BX ACROSS A CALL TO THIS ROUTINE) -
; BL IS JUST THE BOTTOM HALF OF BX, SO TOUCHING IT HERE WOULD
; SILENTLY CORRUPT THAT POINTER. DL DOESN'T HAVE THAT PROBLEM
; ANYWHERE IN THIS FILE.
;
; IN:  SI, DI = the two strings to compare
; OUT: AL = 1 if they match exactly (same length, same characters),
;      AL = 0 if they don't
;-------------------------------------------------------------
STR_COMPARE PROC
CMP_LOOP:
    MOV AL, [SI]                 ; AL = next character from the 1st string
    MOV DL, [DI]                 ; DL = next character from the 2nd string
    CMP AL, DL                   ; are they the same character?
    JNE CMP_NOT_EQUAL             ; no - the strings differ, stop here
    CMP AL, '$'                  ; they match - but is this the '$' that
                                  ; ends both strings?
    JE  CMP_EQUAL                 ; yes - matched all the way to the end of
                                   ; both strings, so they're equal
    INC SI                        ; not the end yet - move both pointers
    INC DI                        ; along one character...
    JMP CMP_LOOP                  ; ...and compare the next pair
CMP_EQUAL:
    MOV AL, 1
    RET
CMP_NOT_EQUAL:
    MOV AL, 0
    RET
STR_COMPARE ENDP


;-------------------------------------------------------------
; CHECK_ALPHA  -  CHECKS THAT CX CHARACTERS STARTING AT DS:SI ARE
; ALL LETTERS (A-Z, a-z) OR SPACES - USED BY CHECKOUT.ASM TO
; VALIDATE THE TYPED CARDHOLDER NAME.
; IN:  SI = START OF THE TEXT, CX = HOW MANY CHARACTERS TO CHECK
; OUT: AL = 1 IF ALL CX CHARACTERS ARE LETTERS/SPACES (AND CX > 0),
;      AL = 0 OTHERWISE (INCLUDING WHEN CX WAS 0 - AN EMPTY NAME
;      IS TREATED AS INVALID)
;
; HOW THE RANGE CHECKS WORK: CHARACTERS ARE JUST NUMBERS UNDER THE
; HOOD (ASCII CODES), AND THE LETTERS OF THE ALPHABET HAVE CODES
; THAT RUN IN ORDER - 'a' THROUGH 'z' ARE ONE CONSECUTIVE BLOCK OF
; NUMBERS, AND 'A' THROUGH 'Z' ARE ANOTHER, SEPARATE BLOCK. SO "IS
; THIS CHARACTER A LOWERCASE LETTER" IS JUST "IS ITS CODE BETWEEN
; 'a' AND 'z' INCLUSIVE" - EXACTLY WHAT THE CMP/JB/JBE PAIRS BELOW
; ARE CHECKING.
;-------------------------------------------------------------
CHECK_ALPHA PROC NEAR
    PUSH CX
    PUSH SI
    CMP CX, 0                    ; if we were asked to check 0 characters...
    JE  CCA_BAD                  ; ...treat that as invalid (empty = bad)

CCA_LOOP:
    MOV AL, [SI]                 ; AL = the character we're checking now
    CMP AL, 'a'                  ; is it below 'a' in the alphabet...
    JB  CCA_CHECK_UPPER          ; ...if so it can't be lowercase - go
                                  ; check whether it's uppercase instead
    CMP AL, 'z'                  ; is it at or below 'z' too?
    JBE CCA_OK_CHAR              ; yes - it's between 'a' and 'z', so it's
                                  ; a valid lowercase letter
    ; (falls through when AL > 'z' - not lowercase, so check uppercase next)

CCA_CHECK_UPPER:
    CMP AL, 'A'                  ; same idea, now for uppercase 'A'-'Z'
    JB  CCA_SPACE                ; below 'A' - can't be a letter at all, so
                                  ; the only other thing we'll accept is a
                                  ; space
    CMP AL, 'Z'
    JBE CCA_OK_CHAR              ; between 'A' and 'Z' - valid uppercase
    ; (falls through when AL > 'Z' - not a letter, so check for a space next)

CCA_SPACE:
    CMP AL, ' '                  ; is it exactly a space character?
    JE  CCA_OK_CHAR              ; yes - spaces are allowed (for names like
                                  ; "JOHN SMITH")
    JMP CCA_BAD                  ; not a letter or a space - the whole
                                  ; string fails the check

CCA_OK_CHAR:
    INC SI                       ; this character passed - move to the next
    LOOP CCA_LOOP                ; LOOP decrements CX and repeats while
                                  ; there are still characters left to check

    MOV AL, 1                    ; got all the way through without
                                  ; failing - every character was valid
    JMP CCA_DONE

CCA_BAD:
    MOV AL, 0                    ; something failed (or CX was 0)

CCA_DONE:
    POP SI
    POP CX
    RET
CHECK_ALPHA ENDP


;-------------------------------------------------------------
; CHECK_DIGITS  -  CHECKS THAT CX CHARACTERS STARTING AT DS:SI ARE
; ALL '0'-'9' - USED BY CHECKOUT.ASM TO VALIDATE THE TYPED CARD
; NUMBER AND CVV.
; IN:  SI = START OF THE TEXT, CX = HOW MANY CHARACTERS TO CHECK
; OUT: AL = 1 IF ALL CX CHARACTERS ARE DIGITS (AND CX > 0),
;      AL = 0 OTHERWISE
;
; SAME "CHARACTERS ARE JUST NUMBERS" IDEA AS CHECK_ALPHA ABOVE:
; '0' THROUGH '9' ARE ONE CONSECUTIVE RUN OF ASCII CODES, SO "IS
; THIS A DIGIT" IS JUST "IS IT BETWEEN '0' AND '9' INCLUSIVE".
;-------------------------------------------------------------
CHECK_DIGITS PROC NEAR
    PUSH CX
    PUSH SI
    CMP CX, 0                    ; 0 characters to check = treat as invalid
    JE  CCD_BAD

CCD_LOOP:
    MOV AL, [SI]                 ; AL = the character we're checking now
    CMP AL, '0'                  ; below '0'? not a digit.
    JB  CCD_BAD
    CMP AL, '9'                  ; above '9'? also not a digit.
    JA  CCD_BAD
    INC SI                       ; it's a digit - move to the next character
    LOOP CCD_LOOP                ; repeat for all CX characters

    MOV AL, 1                    ; every character was a digit
    JMP CCD_DONE

CCD_BAD:
    MOV AL, 0

CCD_DONE:
    POP SI
    POP CX
    RET
CHECK_DIGITS ENDP

END
