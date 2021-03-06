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

__k_io_init:
	pusha
	push es	
		; -------------------------------------------------------------------
		; Initialize Messages Queue 
		; -------------------------------------------------------------------
		mov bx, MDA_SEG
		mov es, bx
		mov [es:MDA.msg_w_length], word K_SYSTEM_MSG_QUEUE_MAX_ITEMS
		mov [es:MDA.msg_w_width], word K_MSG_Q_ITEM_size
		mov [es:MDA.msg_w_head], word 0
		mov [es:MDA.msg_w_tail], word 0

		; -------------------------------------------------------------------
		; Initialize Notification list.
		; We initialize the memory array with MSG_NONE
		; -------------------------------------------------------------------
		mov di, MDA.k_list_notification
		mov al, MSG_NONE
		mov cx, K_NOTIFICATION_ITEM_size * K_MAX_NOTIFICATION_COUNT
		rep stosb

		; -------------------------------------------------------------------
		; Install the System Calls
		; -------------------------------------------------------------------

		; 												K_IO_ADD_MESSAGE
		mov bx, DS_ADD_ROUTINE
		mov	ax, K_IO_ADD_MESSAGE
		mov cx, cs
		mov dx, sys_io_add_message
		int 0x40

		; 												K_IO_GET_MESSAGE
		mov bx, DS_ADD_ROUTINE
		mov ax, K_IO_GET_MESSAGE
		mov cx, cs
		mov dx, sys_io_get_message
		int 0x40

		; 												K_IO_ADD_NOTIFICATION
		mov bx, DS_ADD_ROUTINE
		mov ax, K_IO_ADD_NOTIFICATION
		mov cx, cs
		mov dx, sys_io_add_notification
		int 0x40
		; -------------------------------------------------------------------

		; Test
		;mov ax, MSG_KB_DOWN
		;mov cx, NOTI_TYPE_SYSTEM 
		;mov dx, cs
		;mov si, __goo
		;call __io_add_notification

		;mov ax, MSG_KB_UP
		;mov cx, cs
		;mov dx, __foo
		;call sys_io_add_notification
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
;		 If the queue is full, it returns 0.
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
		sti
		; -----------------------------------------------------
		
	pop dx
	pop cx
	pop bx
	retf
.queue_item: resb K_MSG_Q_ITEM_size

; Adds a Application Notification Item. This is a wrapper that allows
; application softwares to add notification only of type NOTI_TYPE_APP.
; Input:
;	AX		- MSG
;	CX		- Process ID
;   DX		- Routine Offset
; Output:
;	AX		- 0 is success, 1 notification list full
sys_io_add_notification:
	push si
	push dx
	push cx
		mov si, dx
		mov dx, cx
		mov cx, NOTI_TYPE_APP
		call __io_add_notification
	pop cx
	pop dx
	pop si
retf

; Adds a Complete Notification Item. A system call wrapper will allow
; application softwares to add notification only of type NOTI_TYPE_APP.
; Input:
;	AX		- MSG
;	CX		- Type ( 0 - NOTI_TYPE_APP, 1 - NOTI_TYPE_SYSTEM)
;	DX		- Segment/PID 
;   SI		- Offset
; Output:
;	AX		- 0 is success, 1 notification list full
__io_add_notification:
	push bx
	push cx
	push di
	push es

		; Sets ES = Segment of the MDA
		mov bx, MDA_SEG
		mov es, bx
		
		; Set the location of the notification array to DI
		mov di, MDA.k_list_notification

		; Keep CX (Segment part of the routine) in BX
		mov bx, cx

		; Search for a place in the notification array, which is free.
		; Free place is marked by the Message word to MSG_NONE

		; Note: Notificaions can be disabled by setting the Count to Zero. 
		;		That is the reason for the JCXZ instruction
		mov cx, K_MAX_NOTIFICATION_COUNT
		jcxz .success
.again:
			cmp word [es:di + K_NOTIFICATION_ITEM.Message], MSG_NONE
			je .found							; Empty location found.
			add di, K_NOTIFICATION_ITEM_size	; Try next location.
		loop .again

		; End is reached, no empty location found. We exit.
		jne .full 		
.found:
		; We have found an empty location. Location in ES:DI
		mov [es:di + K_NOTIFICATION_ITEM.Message], ax
		mov [es:di + K_NOTIFICATION_ITEM.Type], bx
		mov [es:di + K_NOTIFICATION_ITEM.Routine.Segment], dx
		mov [es:di + K_NOTIFICATION_ITEM.Routine.Offset], si
.success:
		xor ax, ax
		jmp .end
.full:
		mov ax, ERR_NOTI_FULL 	; ERR_NOTI_FULL = 1
.end:
	pop es
	pop di
	pop cx
	pop bx
ret
