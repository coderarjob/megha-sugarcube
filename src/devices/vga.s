
	COLUMNS: equ 80
	ROWS: EQU 25
	PAGES: EQU 2

	LAST_ROW_LAST_PAGE: EQU (PAGES * ROWS) -1
	FIRST_ROW_LAST_PAGE: EQU (PAGES -1) * ROWS

%macro _out 2
	push ax
	push dx
		mov dx, %1
		mov al, %2
		out dx, al
	pop dx
	pop ax
%endmacro


; Writes to the VGA memory. It also advances the cursor when needed.
; Input:
; 	DS:AX - Buffer location.
;	BX - Buffer length
sys_vga_write:
	push cx
		mov cx, bx			; We need to copy these many bytes
		jcxz .empty			; We end, if length provided is zero

	push es
	push si
	push di
	push ax
	push bx

		mov bx, MEM.seg		; We load the destination segment register
		mov es, bx

		mov si, ax
		mov di, [MEM.now]
		mov al, [ATTRIBUTE.value]
.again:	
		movsb
		mov [es:di],al
		inc di
		loop .again

	pop bx
		; For each character, we have to advance memory location by 2 bytes. 
		; So we add BX twice. We could have used SHL BX, 1 instruction, 
		; but then we had to put extra instructions to preserve and restore BX.
		add [MEM.now], bx	; Update the current memory location once
		add [MEM.now], bx	; Update the current memory location twice.

		;We need to update Cursor location here
		add [CURSOR.location], bx		; We add the number of bytes written to
										; the current cursor position
		mov bx, [CURSOR.location]		; Save the Updated location
		call __set_cursor_location		; Change the VGA Cursor location
										; registers. Input is BX.
	pop ax
	pop di
	pop si
	pop es
.empty:
	pop cx
	ret

; Scrolls up the screen content, and the first line on the screen is the line
; that is provided in the input. If the input row number (0 indexed) is in the 
; last page or past the last line of the last page, then this routine will 
; always make room for one line in the end. That is we scroll up one row.
; Input:
; 	AL - First row to display
sys_vga_scroll_up:
	pusha

	; Check if we have reached the last page.
	; If the input row > first row of the last page, then that is an
	; unreasonable request and is treated separately.
	cmp al, FIRST_ROW_LAST_PAGE
	ja .last_page

	; We are not dealing with the last page. So scroll down is as simple as
	; calling the set_origin method
	xor ah, ah
	imul ax, COLUMNS	
	call vga_set_origin

	jmp .end

.last_page:
	
	; There is no room for any more line. So drastic measureus need to be
	; taken. We destroy the very first line and copy the 2nd line in its place.
	; Then we copy the 3rd line to 2nd line, and so on untill we have copied 
	; the very last to the 2nd last line.

	; From the start to the end, there are 25 * 8 = 200 lines. We will do till
	; the 2nd last line, so 199th line.
	push es
	push ds
		; Setup the segment registers
		mov bx, MEM.seg
		mov ds, bx
		mov es, bx

		; This is the total number of words from the first line to the 2nd last
		; line.
		mov cx, (PAGES * ROWS - 1) * COLUMNS
		mov si, COLUMNS * 2			; This is the start of the very 2nd line.
		mov di, 0					; This is the start of the very first line.
		rep movsw					; Bytes from DS:SI will be copied to ES:DI
									; DS = ES = 0xB800
									; We will keep coping till the start of the
									; very last line of the last page.
	
		; Now we make the last line blank.
		mov cx, COLUMNS
		mov al, 0
		mov ah, [ATTRIBUTE.value]
		rep stosw
	pop ds
	pop es
.end:
	popa
	ret

; Scrolls down the content of the screen in such a way that the input row
; becomes to top most one. The input is unsigned int, so we cannot do a less
; than zero check. It is upto the terminal driver to do that kind of check,
; before calling scroll_down.
; Input:
; 	AL - Top most row to display, i.e the row at the top of the screen.
sys_vga_scroll_down:
	push ax

		xor ah, ah
		imul ax, COLUMNS

		call vga_set_origin
	pop ax
	ret

; Sets the cursor location on the screen.
; This also updates the current location (MEM.now) as well to the proper value.
; Input:
; 	Al - Column number (starts from 0)
;	Bl - Row number (starts from 0)
sys_vga_set_cursor_location:
	push ax
	push bx
		
		xor ah, ah
		xor bh, bh

		; Need to convert the rows and columns to linear address.
		; offset = row * COLUMNS + column
		imul bx, COLUMNS
		add bx, ax

		; Update VGA cursor location registers.
		; Input is the Text Cell index (Staring with 0), in BX register
		call __set_cursor_location

		; Save the current location
		mov [CURSOR.location], bx

		; Update the screen memory location
		; Every text cell on screen takes two bytes. So
		; mem location = offset * 2
		shl bx, 1
		mov [MEM.now], bx
	pop bx
	pop ax
	ret

; Similar to the method above, but takes in the location as text cell index
; rather than columns and rows.
; Note: This is a routine used locally by the driver.
; Input:
;	BX - Text cell index. (Top left cell is 0)
__set_cursor_location:
	; Set the Cursor Location Low Register	
	_out 0x3d4, 0xF
	_out 0x3d5, bl

	; Set the Cursor Location High Register
	_out 0x3d4, 0xE
	_out 0x3d5, bh 
	ret
	
; Sets the offset text cell number, from which the to display starts.
; Setting this to 80 (on a 80 column monitor), will start display from the 
; 2nd line. This routine will be used to reset the start memory at the 
; beginning and also can be used for vertical scrolling.
; Input:
;	AX - Offset value
vga_set_origin:
	; 1. Set the low byte into the VGA Start Memory Register
	_out 0x3d4, 0xD
	_out 0x3d5, al

	; 2. Set the High byte into the VGA Start Memory Register
	_out 0x3d4, 0xC
	_out 0x3d5, ah
	ret

; Sets the attribute (Fore Color, Background Color and Blink)
; Attribute in memory:
;   |---|-----------|---------------|
;   | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;   |---|-----------|---------------|
;   | B | BG Color  | FG Color      |
;   |---|-----------|---------------|
; Input:
;	AH - Attribute selection ( 0 - FG color, 1 - BG Color, 2 - Blink)
;	AL - Attribute value
sys_vga_set_attribute:
	cmp ah, 0
	je .fg_color

	cmp ah, 1
	je .bg_color
	
	cmp ah, 2
	je .blink

	jmp .invalid

.fg_color:
	and [ATTRIBUTE.value],byte 0b11110000
	or [ATTRIBUTE.value], al
	jmp .end
.bg_color:
	and [ATTRIBUTE.value],byte 0b10001111
	shl al, 4
	or [ATTRIBUTE.value], al
	jmp .end
.blink:
	and [ATTRIBUTE.value],byte 0b01111111
	shl al, 7
	or [ATTRIBUTE.value], al
.invalid:
.end:
	ret

; Sets the cursor shape
; Input:
;	AL - Cursor start scan line
;	AH - Cursor end scan line
sys_vga_set_cursor_attribute:
	push ax
	; Set the Cursor Start Register
	; We will set the CD (Cursor Display) bit to 1
	or al, CURSOR.CD_ON
	and al, 0xF			; Only the right most 4 bits are importaint

	_out 0x3d4, 0xA
	_out 0x3d5, al

	; Set the Cursor End Register
	; We will set the CSK (Cursor Skew) bits to 0
	and ah, 0xF			; We keep only the right most 4 bits.

	_out 0x3d4, 0xB
	_out 0x3d5, ah
	
	pop ax
	ret

MEM: 
	.seg equ 0xB800
	.now dw 0

ATTRIBUTE:
	.value: db 0xF

CURSOR:
	.location: dw 0
	.CD_ON: EQU 0b_0010_0000

