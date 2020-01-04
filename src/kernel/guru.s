; Megha Operating System Panic/Debug module.
; The functions in this file is called by the kernel, drivers or application
; programs.
; It also containts the PANIC routine (INT 0x42) - Previously it was a separate
; module.

; Build version: 0.11 (240819)

; Initial release: 10th Aug 2019
; -------------------------------
; Changes in 0.11 (24th Aug 2019)
; -------------------------------
; * No longer uses despatcher module for despatching. Uses its own despatcher
; * Contain the PANIC method. Previously it was separate module.
; * Detailed PANIC routine. It shows the stack and MDA dump, and registers
;   values.
; * printstr is not copy_to_screen. It now supports CR and LF characters.

; Every driver and application programs start at location 0x10
; The above area (0 to 0xF) is for future use, and not used currently.
	ORG 0x10

; The first function in a module/driver program is a _init function. 
; This function is responsible for setting up the driver - install routines 
; into IVT etc. 

_init:
	pusha
	    ; Add the local despatcher routine to IVT
	    xor bx, bx
	    mov es, bx
	    mov [es:0x41*4],word _despatcher
	    mov [es:0x41*4+2],cs

	    ; Add the PANIC routine to IVT
	    xor bx, bx
	    mov es, bx
	    mov [es:0x42*4],word panic
	    mov [es:0x42*4+2],cs
	popa

	; RETF is a must to be able to return to the loader.
	retf

; This module has its own despather and do not use the system despatcher for
; its work. The reason for this is to keep the GURU module independent from the
; rest of the system and is an independent module that do not depend on any
; other.
; Input:
; 		BX - Routine number
; Output:
;		BX - Output from the called routine.
; Note:
;		All the registers except BX are saved and restored in the despatcher.
;		DS is kept unchanged. Data segment of the caller. Local data is
; 		accessed using the CS register.
;		ES register is also unchanges, but can be chanded in any routine.
_despatcher:
	push ds
	push ax
	push cx
	push dx
	push si
	push di

	; Each of the entry in the call vector is 2 bytes.
	; So the below statement multiplies bx by 2
	shl bx, 1
	call [cs:callvector+bx]

	pop di
	pop si
	pop dx
	pop cx
	pop ax
	pop ds

	; IRET is requried as this routine will be called via INT
	iret

; Displays an error message on the screen and halts the processor
; Input:
;		STACK - A ASCIIZ string that needs to be displayed.
;			  - DS is used for data segment
; Ouput:
;		None
panic:
	push bp
	mov bp, sp

	; Allote 20 bytes for storing 10 register values (Each a word)
	sub sp,20

;	params structure points to each of the values that are pushed into the
;	stack when calling the panic routine. This includes the error string as 
;	well.
;	The structure begins at an offet of 2 because of the PUSH BP statement
;	above. Will be used to retrive the value of CS:IP from the stack.
;	Use: mov ax, [bp + params.cs]
struc params,2
	.cs: resw 1
	.ip: resw 1
	.flag: resw 1
	.error: resw 1
endstruc

struc reg,2
	.ax: resw 1	; Top most
	.bx: resw 1
	.cx: resw 1
	.dx: resw 1
	.si: resw 1
	.di: resw 1
	.es: resw 1
	.ds: resw 1
	.ss: resw 1
	.sp: resw 1
endstruc

	; Save the register values into the stack. These will be used when
	; displaying their values
	mov [bp - reg.ax], ax
	mov [bp - reg.bx], bx
	mov [bp - reg.cx], cx
	mov [bp - reg.dx], dx
	mov [bp - reg.si], si
	mov [bp - reg.di], di
	mov [bp - reg.es], es
	mov [bp - reg.ds], ds
	mov [bp - reg.ss], ss
	mov [bp - reg.sp], bp


	; ======================= Clear the screen
	call clear
	; ======================= Display the error message
	mov ax, [bp + params.error]
	call copy_to_screen

	; At this point no data needs to be accessed from the Caller's side, so we
	; repurpose the ES register so that it can be used to call the below
	; routines.
	mov bx, cs
	mov ds, bx
	mov es, bx

	; ================= Dump a few memory locations

	; Dump the Stack (SS:BP)
	mov ax, .panic_stack_dump_msg
	call copy_to_screen	; Prints a asciiz string in ES:AX

	mov ax, ss
	mov dx, bp
	mov cx, 0x40
	call hexdump

	; Dump the MDA
	mov ax, .panic_mda_dump_msg
	call copy_to_screen	; Prints a asciiz string in ES:AX

	mov ax, MDA_SEG
	mov dx, MDA_OFF
	mov cx, 0x20
	call hexdump

	; ===================== Write out the registers (CS and IP)
	mov cx, 16
	lea di, [.panic_registers+6]

	mov ax, [bp + params.cs]
	call _printhex
	add di, 8

	mov ax, [bp + params.ip]
	call _printhex
	add di, 8

	; ====================== Write the rest of the registers
	; There are 10 registers, whoes values we are going to display
	mov cx, 10
	lea bx, [bp - reg.ax]
.next:
		push cx
			mov cx, 16
			mov ax, [ss:bx]
			call _printhex
			add di, 8

			; We subtract the BX register, so that it can point to the next
			; word that is below the current one.
			sub bx, 2
		pop cx
	loop .next

	; Dump the registers string
	mov ax, .panic_registers
	call copy_to_screen	; Prints a asciiz string in ES:AX
	jmp $

; ======================== PANIC ROUTINE ===================
.panic_stack_dump_msg: db 10,13,10,"Stack dump:",0
.panic_mda_dump_msg:   db 13,10,10,"First 32 bytes in MOS Data Area:",0
.panic_registers: db 10,13,10,"CS:---- IP:---- AX:---- BX:---- CX:---- "
                  db          "DX:---- SI:---- DI:---- ES:---- DS:---- "
				  db          "SS:---- SP:----",0

; Prints the hex representation of bytes in memory location
; Input: AX:DX - Location of the memory location, AX is the Segment, DX is the
;                offet in the segment.
;        CX    - Number of bytes to show
; Output: none
hexdump:
	pusha
	push es
		; Because there is no need to access caller data, we override ES and DS
		; to suite our needs.
		mov bx, cs
		mov es, bx
		mov ds, bx

		; This is again for our ease of use. As DX cannot be used in an
		; effective address, but si can be used.
		mov si, dx

		; From here on the destination location is addressed by AX:SI
		jmp .reset
.again:	
		cmp dx, 0
		jne .body

		; Display the current dump line
		pusha
			mov ax, .dump_line
			call copy_to_screen
		popa

.reset:
		; Reset the dump line to the template
		lea di,[.dump_line + 2]
		pusha		
			mov di, .dump_line
			mov si, .template
			mov cx, .template_len
			rep movsb
		popa	
		
		; Fill in the template
.headers:
		push cx
			; Print the Segment part
			mov cx, 16
			call _printhex
			add di, 5
		
			push ax
				; Print the offset
				mov ax, si
				call _printhex
			pop ax
			add di, 6
		pop cx
		
		mov dx, 8
.body:
		; Read 8 (or remaining)  bytes from AX:DX and put it 
		; into .dump_line
		push ax
		push cx
			push es
				mov es, ax
				mov ax,[es:si]
			pop es
			mov cx, 8
			call _printhex
			add di, 3
			inc si
		pop cx	
		pop ax

		dec dx
		loop .again

		; Display the last dump line.
		push ax
			mov ax, .dump_line
			call copy_to_screen
		pop ax
	pop es
	popa
	ret
.template: db 13,10,"----:----  -- -- -- -- -- -- -- --",0
.template_len: equ $ - .template
.dump_line: resb .template_len

; Copies one character with attribute in the VBA memory.
; This function also maintains the current offset in the VGA memory
; Input: BL - Character to print
;        BH - Attribute
_putchar:
	    push es
	    push bx
	    push di

		; setup the segment (ES), and offset (DI) value.
		push bx
		    mov bx, 0xb800
		    mov es, bx
		pop bx
		mov di, [cs:vga_offset]

		; print out the character and attribute byte
		mov [es:di], bl
		mov [es:di + 1], bh
		
		; We increment the offset variable
		add [cs:vga_offset], word 2
	    pop di
	    pop bx
	    pop es
	ret

; Clears the vga memory, and resets the vga_offset value to zero
; Input: none 
; Output: none
clear:
	    push cx
	    push ax
	    push di
	    push es
	    	mov ax, 0xb800
			mov es, ax
			mov di, 0

			mov ax, 0x0
			mov cx, 2000		; 80 words/row, 25 rows	
			cld
			rep stosw

			mov [cs:vga_offset], word 0
            pop es
	    pop di
	    pop ax
	    pop cx
	; Must be far return, because the despatcher reside in another segmnet.
	ret

; Copies a zascii stirng of bytes to VGA memory. It handles CR and LF
; characters properly.
; Input: Address to print is in DS:AX
; Output: none
copy_to_screen:
	push si
	push bx

	    mov si, ax
	    mov bh, DEFAULT_TEXT_COLOR	
.rep:
	    mov bl, [si]
	    cmp bl, 0
	    je .end

	    cmp bl, 13
	    jne .lf

	    ; Handle CR
	    call _cr
	    jmp .loop
.lf:
	    cmp bl, 10
	    jne .normal
	   
	    ; Handle LF
	    call _lf
	    jmp .loop
.normal:
	    call _putchar

.loop:
	    inc si
	    jmp .rep
.end:
	pop bx
	pop si
	; Must be far return, because the despatcher reside in another segmnet.
	ret		

; Implementation of the Carrage Return. Next character is printed at the first
; column of the current line.
; Input:
;	None
; Output:
;	None
_cr:
	pusha
	    ; Byte number = current_offset % 160
	    xor dx, dx
	    mov ax, [cs:vga_offset]
	    mov bx, 160
	    div bx	; AX = DX:AX / BX and
	    		; DX = DX:AX % BX

	    ; Start of the current line = current_offset - byte number
	    sub [cs:vga_offset], DX
	popa
	ret

; Implementation of Line Feed. Next character is printed in the next line at
; the next column.
; Input:
;	None
; Output (in BX):
;	None
_lf:
	add [cs:vga_offset],word 160
	ret

; Displays hexadecimal representation of a 16/8 bit number.
; Input: AX -> Number
;        CX -> Number of bits to show in the hex display.
;              16 - to see 16 bit hex
;              8  - to see 8 bit hex (will show only AL)
;	       Note: 0 < CX < 16 and CX is divisible by 4
; Output: None
printhex:
	push ds
	push bx
	push di
	
	    ; Put the hex value into the .buffer
	    mov di, .buffer
	    call _printhex
		
	    ; Display the string
		mov ax, cs
		mov ds, ax
	    mov ax, .buffer
	    call copy_to_screen

	pop di
	pop bx
	pop ds
	ret
.buffer: resb 4		; Place for 4 characters from _printhex
	 db 0		; and a end of string indicatior

; Prints out hexadecimal representation of a 16/8 bit number.
; Input: AX -> Number
;        CX -> Number of bits to show in the hex display.
;              16 - to see 16 bit hex
;              8  - to see 8 bit hex (will show only AL)
;	       Note: 0 < CX < 16 and CX is divisible by 4
;	CS:DI -> Write location 
; Output: None
_printhex:
		push di
	    push cx
	    push bx
	    push ax

		; Number of times the below loop need to loop
		; Number of itterations = CX/4
		mov bx, cx
		shr bx, 2
	
		; We Shift the number so many times so that the required bits
		; come to the extreme left.
		; Number of left shits = (16 - CX) or -(CX - 16)
		sub cx, 16
		neg cx
		shl ax, cl

		; Load the number of loop itteration into CX
		mov cx, bx		; we are doing 16 bits, so 4 hex chars
.rep:
		mov bx, ax		; just save the input
		shr bx, 12		; left most nibble to the right most
		mov bl, [cs:.hexchars + bx]; Get the hex character
		mov [cs:di], bl
		inc di

		shl ax, 4		; Position the next nibble
		loop .rep
		
	    pop ax
	    pop bx
	    pop cx
		pop di
	ret
.hexchars: db "0123456789ABCDEF"

;section .data
vga_offset: dw  0

; ======================== INCLUDE FILES ===================
%include "../include/mos.inc"
; ======================== LOCAL DATA ======================
callvector: dw printhex,copy_to_screen,clear,hexdump
