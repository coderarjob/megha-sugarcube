; Megha SugarCube Operating System
; This file has the many limits (Maximam and Minimum values) used in the
; Operating System.

	DS_MAX_ITEMS:						EQU	50

	; System Queue
	K_SYSTEM_MSG_QUEUE_MAX_ITEMS: 		EQU 100

	; Notification
	K_MAX_NOTIFICATION_COUNT: 			EQU 10

	; VGA 
	VGA_COLUMNS: 						EQU 80
	VGA_ROWS: 						    EQU 25
	VGA_PAGES: 						    EQU 2
	VGA_LAST_ROW_LAST_PAGE: 			EQU (VGA_PAGES * VGA_ROWS) -1
	VGA_FIRST_ROW_LAST_PAGE: 			EQU (VGA_PAGES -1) * VGA_ROWS

	; Virtual TTY
	VTTY_WIDTH: 					   EQU 80
	VTTY_HEIGHT: 					   EQU 25
	VTTY_COUNT: 					   EQU 2

	; Process and Modules
	KERNEL_MODULE_MAX_COUNT:		   EQU 10
	PROCESS_MEMORY_MAX: EQU 0x80C00		; Start of Extended BIOS Data Area.
										; Valid Segment Range that can be
										; alloted -> 0xB000 to 0x80BFF (471 KiB)
										; Valid Segment Range that can be
										; alloted -> 0xB000 to 0x80BFF (471 KiB)
	PROCESS_MAX_COUNT: 				  EQU 5 
	PROCESS_MAX_STACK: 				  EQU 1024
	PROCESS_MAX_UNALLOCATED_STORAGE:  EQU 1024
	PROCESS_MSG_QUEUE_MAX_ITEMS: 	  EQU 50


