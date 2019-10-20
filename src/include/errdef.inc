
; Lists down all the error codes that can occour in the kernel or any of the
; system modules that make up the OS.

ERR_NONE:	equ 0

; Errors in vfs module
ERR_DRIVE_ALREADY_EXISTS:	EQU 
ERR_FS_LIMIT_EXCEED:		EQU 1
ERR_DUPLICATE_FS_NAME:		EQU 2
ERR_FILE_CLOSED:			EQU 1		; raised by vfs_close, if input file is
										; alreay closed.
ERR_DRIVE_NOT_FOUND: 		EQU 101		; raised by vfs_open, if drive was not
										; found.
ERR_FILE_LIMIT_EXCEED: 		EQU 102		; raised by vfs_open, if it cannot add
										; more files, as the limit was reached.
