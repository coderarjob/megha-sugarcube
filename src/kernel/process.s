; Megha Sugarcube Operating System - Process Routines
;
; Create, Switch and Close process

; Creates a process with the filename
; Input:
; 	AX:CX	- ASCIIZ File name
sys_k_create_process:

	; Copy the filename to current segment
	push ds
		push ds
		pop es

		mov ds, ax
		mov si, cx
		mov di, .filename
		mov cx, 11			; MAX FILENAME LENGTH
		rep movsb
	pop ds
	

	; Get the last module Segment and Size
	mov di, [MDA.mod_b_count]		; Count
	dec di 							; 1st item is 0, so Count -1 = last item.

	imul di, K_MODULE_ITEM_size		; Each of item is K_MODULE_ITEM_size bytes
	mov ax, [di + MDA.mod_list_modules + K_MODULE_ITEM.Size]
	mov bx, [di + MDA.mod_list_modules + K_MODULE_ITEM.Segment]

	; Get the next segment location
	; seg = (size (ax) + OFFSET (_init_addr) >> 4) +1 + seg
	add ax, MODULE0_OFF			; size + OFFSET
	shr ax, 4					; (size + OFFSET)  * 16
	inc ax						; (size + OFFSET)  * 16 + 1
	add bx, ax					; (size + OFFSET)  * 16 + 1 + LastSegment

	mov ax, bx
	mov bx, MODULE0_OFF
	mov dx, .filename
	int 0x30

retf

.filename

