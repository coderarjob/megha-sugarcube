; Megha Operating System Sugarcube 
; - 8254 driver
; ----------------------------------------------------------------------------
;
; 8254 Driver module provides to set the counters and the GATE of Counter 2.
; It however do no override IRQ0. That will be done in the Kernel.
;
; ----------------------------------------------------------------------------

; This is module that will be loaded by the loader. The loader modules start at
; location 0x64.

	Org 0x64

_init:
	
	; Add sys_set_counter to Despatcher modules
	mov bx, DS_ADD_ROUTINE
	mov ax, PIT_SET_COUNTER
	mov cx, cs
	mov dx, sys_set_counter
	int 0x40

	; Add sys_set_counter to Despatcher modules
	mov bx, DS_ADD_ROUTINE
	mov ax, PIT_SET_GATE
	mov cx, cs
	mov dx, sys_set_gate_state
	int 0x40

	retf


; Sets the value into a Counter.
; Input:
;	AX 	- Counter	(0 - Counter 0, 2 - Counter 2)
;	CX	- Value		
;	DX	- Mode		 0 - Mode 0 (Counter 0 & Counter 2)
;					 1 - Mode 1 (Counter 2),
;					 2 - Mode 2 (Counter 0 & Counter 2),
;					 3 - Mode 3	(Counter 0 & Counter 2)
; Output:
;	AX	- 0 Success, 1 Invalid
sys_set_counter:
	push cx
	push dx

		; TODO: Check for invalid modes

		; ------------------------------------
		; Setup Control Word in AL register
		;
		;|-----|-----|-----|-----|----|----|----|-----|
		;| SC1 | SC0 | RW1 | RW0 | M2 | M1 | M0 | BCD |
		;|-----|-----|-----|-----|----|----|----|-----|
		;
		push ax
			shl ax, 6				; SC1, SC0 - Sets the Counter
			or 	ax, 0b0011_0000		; RW1, RW0 - Two Byte Mode

			shl dx, 1
			and dx, 0b0000_0110		; Make sure CX is at-most 3. Clears BCD.
			or ax, dx				; M2, M1, M0 - Mode
		
			; Write the Control Word
			out 0x43, al
		pop ax

		; ------------------------------------
		; Write the Counter value
		; ------------------------------------
		cmp ax, 0
		je .counter0
		cmp ax, 2
		je .counter2

		; ------------------------------------
		; Invalid Counter
		; ------------------------------------
		mov ax, 1	
		jmp .end
.counter0:
		mov al, cl
		out 0x40, al
		mov al, ch			; Cannot use BH,BL in OUT!!
		out 0x40, al
		jmp .done

.counter2:
		mov al, cl
		out 0x42, al
		mov al, ch			; Cannot use BH,BL in OUT!!!
		out 0x42, al
.done:
		xor ax, ax
.end:
	pop dx
	pop cx
retf

; Sets/Clears GATE of Counter 2
; Input:
;	AX	- 1 (Set)
;		  0 (Clear)
; Output:
;	AX 	- 0
sys_set_gate_state:
	test ax, 0x1
	jnz .on

	; Turn off GATE
	in ax, 0x61
	and ax, 0b1111_1100
	jmp .end

.on:
	; Turn on GATE
	in al, 0x61
	or ax, 0b0000_0011
.end:
	out 0x61, al
	xor ax, ax
retf

; ==================== INCLUDE FILES ======================
%include "../include/mos.inc"
