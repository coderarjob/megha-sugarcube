; Megha SugarCube Interrupt Routines

; Will hold Hardware, Exception Interrupt Routines. But will be added to the
; IVT by the Kernel.

; Initial Release: 05012019

irq0:
	pusha
	push ds
	
		push cs
		pop ds

		; Read System Queue
		mov bx, K_IO_GET_MESSAGE
		mov ax, ds
		mov cx, .key
		int 0x40

		cmp ax, 0
		je .end

		mov bx, GURU_CLEARSCREEN
		int 0x41

		mov bx, GURU_PRINTHEX
		mov ax, [.key + K_MSG_Q_ITEM.Arg1]
		mov cx, 16
		int 0x41
.end:
		; Send EOI to PIC
		mov al, 0x20
		out 0x20, al

	pop ds
	popa
iret

.key: resb K_MSG_Q_ITEM_size
