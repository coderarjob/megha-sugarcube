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
	push es

		; Initaize sub modules
		call io_init

		; ------ [ Kernel ] ---------
		mov bx, DS_ADD_ROUTINE
		mov ax, K_TAKEOVER
		mov cx, cs
		mov dx, sys_k_takeover
		int 0x40

		; --------[ IO ] ------------

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

		; --------[ IRQ 0 ] ----------
		xor ax, ax
		mov es, ax
		mov [es:8*4],word irq0
		mov [es:8*4+2], cs

	pop es
	popa

retf

sys_k_takeover:

	; As this is a system call, IF (Interrupt)
	; is disabled. We need to enable it.
	sti

	xchg bx, bx
	mov ax, 100
	call __k_alloc

	push ax
		xchg bx, bx
		mov ax, 105
		call __k_alloc

		xchg bx, bx
		call __k_free
	pop ax

	xchg bx, bx
	call __k_free

	xchg bx, bx
	mov ax, 300
	call __k_alloc

	xchg bx, bx
	call __k_free

	xchg bx, bx
	mov ax, 300
	call __k_alloc

	xchg bx, bx
	call __k_free
	xchg bx, bx
	
	; Infinite loop
	jmp $

	; IMP: MUST NEVER RETURN
	ret

%include "interrupt.s"
%include "io.s"
%include "mem.s"
%include "../common/queue.s"
