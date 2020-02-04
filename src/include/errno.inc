
; Lists down all the error codes that can occour in the kernel or any of the
; system modules that make up the OS.

K_ERR_NONE:	equ 0

; General/Common Errors
K_ERR_FILE_NOT_FOUND:	EQU 10

; Errors in mem.s
K_ERR_MEM_STORAGE_FULL:			EQU 20

; Errors in Process (Kernel)
K_ERR_PROCESS_PARENT_ZERO:		EQU 40
K_ERR_PROCESS_LIST_FULL:			EQU 41
K_ERR_PROCESS_NOT_FOUND:			EQU 42
