; Prints a string zascii to screen
; Input: Pointer to string in DS:SI
; Output: None
printstr:
	push ax

	; switch to 0x13 mode
	;mov ah, 0
	;mov al, 0x3	; text mode
	;int 0x10

.repeat:
	lodsb
	mov ah, 0xE
	int 0x10
	cmp al, 0
	jne .repeat

	pop ax
	iret
