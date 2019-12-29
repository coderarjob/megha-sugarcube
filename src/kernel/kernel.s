; Megha SugarCube Kernel Routines
;
; This module is one of the core modules that makes up the Operating System.
; The Kernel will house the external System calls, data structures related to 
; Process management, IO management, File system, diffrent Queues. The Megha OS
; kernel, is not just module, but will include other modules that
; will be loaded by the loader separately.
;
; Sub Modules: IO, FS, Process, Memory, System calls
;
; Initial release: 28122019

; The binary to this module will be a 'Module' that will be loaded directly by
; the loader. Every module starts at location 0x64.

	org 0x64

_init:
	; ------------------------------------
	; Setup Counter 0 Frequency
	; ------------------------------------
	retf


; =====================[ INTERRUPTS ]====================
in_irq0:
ret

	
; =====================[ SOURCE FILES ]========================
%include "despatcher.s"
