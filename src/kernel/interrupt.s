; Megha SugarCube Interrupt Routines

; Will hold Hardware, Exception Interrupt Routines. But will be added to the
; IVT by the Kernel.

; Initial Release: 05012019

irq0:
	pusha
	push ds
	push es

		; Make DS = CS
		push cs
		pop ds

		; ------------------------------------------------------------------
		; Read System Queue
		; ------------------------------------------------------------------
		mov bx, K_IO_GET_MESSAGE
		mov ax, ds
		mov cx, .key
		int 0x40

		cmp ax, 0
		je .end

		; ------------------------------------------------------------------
		; Go through each of the items in Notifications array
		; and call the Routine. Because this is inside an Interrupt
		; the IF bit is already cleared and all Interrupts are disabled.
		; TODO: Should we enable interrupt before??
		; ------------------------------------------------------------------
		
		; Set ES register to proper segment
		mov bx, MDA_SEG
		mov es, bx

		; We will go through each of the items and will call the routine
		; which Message matches the current one.
		mov cx, K_MAX_NOTIFICATION_COUNT
		mov di, MDA.k_list_notification

.again:
			mov ax, [.key + K_MSG_Q_ITEM.Message]
			cmp [es:di + K_NOTIFICATION_ITEM.Message], ax
			jne .loop

			; if CX = 0, no match is found
			jcxz .end

			; TODO: How do we pass the Message arguments to the Routine??
			call far [es:di + K_NOTIFICATION_ITEM.Routine]
.loop:
			; Increment DI
			add di, K_NOTIFICATION_ITEM_size
		loop .again

		; ------------------------------------------------------------------
.end:

		; ------------------------------------------------------------------
		; Send EOI to PIC
		; ------------------------------------------------------------------
		mov al, 0x20
		out 0x20, al

	pop es
	pop ds
	popa
iret

.key: resb K_MSG_Q_ITEM_size
