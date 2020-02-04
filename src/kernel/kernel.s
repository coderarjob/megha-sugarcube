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
		call __k_io_init
		call __k_process_init

		; ------ [ Kernel ] ---------
		mov bx, DS_ADD_ROUTINE
		mov ax, K_TAKEOVER
		mov cx, cs
		mov dx, sys_k_takeover
		int 0x40

		; --------[ IRQ 0 ] ----------
		xor ax, ax
		mov es, ax
		;mov [es:8*4],word irq0
		;mov [es:8*4+2], cs

	pop es
	popa

retf

; ---------------------------------------------------------------------------
; Sets the last Kernel error from System calls or local routine calls.
; (Local Routine)
; ---------------------------------------------------------------------------
; Input: 
;	AX	- Error Code
; Output:
;	None
; ---------------------------------------------------------------------------
__k_setlasterror:
	push es
		
		mov ax, MDA_SEG
		mov es, ax

		mov [es:MDA.k_w_lasterror], ax
	pop es
retf

; ---------------------------------------------------------------------------
; Gets the last Kernel error from System calls or local routine calls.
; (System Call)
; ---------------------------------------------------------------------------
; Input: 
;	None
; Output:
;	AX	- Error Code
; ---------------------------------------------------------------------------
sys_k_getlasterror:
	push es
		
		mov ax, MDA_SEG
		mov es, ax

		mov ax, [es:MDA.k_w_lasterror]
	pop es
retf
; ---------------------------------------------------------------------------

sys_k_takeover:

	; As this is a system call, IF (Interrupt)
	; is disabled. We need to enable it.
	sti

	mov ax, cs
	mov cx, .filename
	mov dx, 0x1
	call __k_process_create

	xchg bx, bx
	mov ax, 1
	call __k_process_switch

	; Infinite loop
	jmp $

	; IMP: MUST NEVER RETURN
ret
.filename: db "DEMO    COM"

%include "interrupt.s"
%include "io.s"
%include "mem.s"
%include "process.s"
%include "../common/queue.s"

