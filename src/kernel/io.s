; Megha SugarCube IO Routines
;
; When an IO interrupt occurs, the interrupt routine will add in a message into
; a System Queue. The routine that will allow this will be housed here.
; This Kernel Module will also house the notification queue - An application 
; can ask the OS to notify it when a perticular Message arrives in the Queue.
;
; Initial release: 28122019
;
; This module will be part of the Kernel module and will be initalized when the
; Kernal module is initialized. All the system calls will be initalized later
; on by the System Calls kernel module.

%include "../include/mos.inc"

io_init:
	pusha
	push es	
		; Initialize Messages Queue
		mov bx, MDA_SEG
		mov es, bx
		mov [es:MDA.msg_w_length], word K_MSG_QUEUE_MAX_ITEMS
		mov [es:MDA.msg_w_width], word K_MSG_Q_ITEM_size
		mov [es:MDA.msg_w_head], word 0
		mov [es:MDA.msg_w_tail], word 0
	pop es
	popa
	ret

; Returns the top most message from the System Queue.
; Input:
;	AX:CX - Location to copy the queue item.
; Output:
;	AX    - 0 Failure, anything else success.
sys_io_get_message:
	push cx
	push dx
	push bx
		mov bx, cx			; AX:BX - Pointer to data location
		mov cx, MDA_SEG		; CX:DX - Pointer to queue
		mov dx, MDA.k_q_messages
		call queue_get
	pop bx
	pop dx
	pop cx
	retf

; Adds one message to the Messages queue.
; Input:
; 	AX - Message
; 	CX - Argument 0
; 	DX - Argument 1
; Output:
; 	AX - 0 failure, anything else success.
sys_io_add_message:
	push bx
	push cx
	push dx

		; -----------------------------------------------------
		; 1. ADD TO THE SYSTEM QUEUE
		; -----------------------------------------------------
		cli
			mov [.queue_item + K_MSG_Q_ITEM.Message], ax
			mov [.queue_item + K_MSG_Q_ITEM.Arg0], cx
			mov [.queue_item + K_MSG_Q_ITEM.Arg1], dx
	
			mov ax, ds
			mov bx, .queue_item
			mov cx, MDA_SEG
			mov dx, MDA.k_q_messages
			call queue_put

			; TODO: Handle Queue full scenario
		sti
		; -----------------------------------------------------
		
		; TODO: Notify routines waiting for the Message
	pop dx
	pop cx
	pop bx
	retf
.queue_item: resb K_MSG_Q_ITEM_size

