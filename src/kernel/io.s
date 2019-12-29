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

; Returns the top most message from the System Queue.
; Input:
;	AX:BX - Location to copy the queue item.
; Output:
;	AX    - 0 Failure, anything else success.
sys_io_get_system_message:
	push cx
	push dx
		mov cx, ds
		mov dx, SYS_QUEUE
		call queue_put
	pop dx
	pop cx
	ret

; Adds one message to the system queue.
; Input:
; 	AX - Message
; 	BX - Argument 0
; 	CX - Argument 1
; Output:
; 	AX - 0 failure, anything else success.
sys_io_add_system_message:
	push bx
	push cx
	push dx

		; -----------------------------------------------------
		; 1. ADD TO THE SYSTEM QUEUE
		; -----------------------------------------------------
		cli
			mov [.queue_item + SYS_Q_ITEM.Message], ax
			mov [.queue_item + SYS_Q_ITEM.Arg0], bx
			mov [.queue_item + SYS_Q_ITEM.Arg1], cx
	
			mov ax, ds
			mov bx, .queue_item
			mov cx, ds
			mov dx, K_MAIN_QUEUE
			call queue_put

			; TODO: Handle Queue full scenario
		sti
		; -----------------------------------------------------
		
		; TODO: Notify routines waiting for the Message
	pop dx
	pop cx
	pop bx
	ret
.queue_item: resw K_SYS_Q_ITEM_SIZE

; Notifies all the routines which are awating for the current Message. 
; Input:
;	AX	- Message
__notify_all:
	pusha
		mov si, [K_NOTIFICATION_LIST]
.again:
	popa
	ret

K_MAIN_QUEUE:
	.length dw 100
	.width  dw 3	
	;|-----|------------|------------|
	;|  0  |     1      |     2      |
	;|-----|------------|------------|
	;| MSG | ARG WORD 0 | ARG WORD 1 |
	;|-----|------------|------------|
	.head dw 0
	.tail dw 0
	.buffer resw 300

K_NOTIFICATION_LIST: resb K_NOTIFICATION_ITEM_SIZE * K_MAX_NOTIFICATION_COUNT 
