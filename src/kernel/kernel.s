; Megha SugarCube Kernel Routines
;
; This module is one of the core modules that makes up the Operating System.
; The Kernel will house the external System calls, data structures related to 
; Process management, IO management, File system, diffrent Queues. The Megha OS
; kernel, is not just this module, but will include other modules that
; will be loaded by the loader separately.
;
; Sub Modules: IO, FS, Process, Memory, System calls
;
; Initial release: 28122019

; The binary to this module will be a 'Module' that will be loaded directly by
; the loader. Every module starts at location 0x10.

%include "../include/mos.inc"

	org 0x10

__init:
	pusha

	; Initaize sub modules
	call io_init

	; Install IRQ 0
	xor ax, ax
	mov es, ax
	mov [es:8*4],word irq0
	mov [es:8*4+2], cs

	; Install System Calls
	mov bx, DS_ADD_ROUTINE
	mov	ax, K_IO_ADD_MESSAGE
	mov cx, cs
	mov dx, sys_io_add_message
	int 0x40

	mov bx, DS_ADD_ROUTINE
	mov ax, K_IO_GET_MESSAGE
	mov cx, cs
	mov dx, sys_io_get_message
	int 0x40

	popa

	retf

irq0:
	cli
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
sti
iret

.key: resb K_MSG_Q_ITEM_size

%include "io.s"
%include "../common/queue.s"
