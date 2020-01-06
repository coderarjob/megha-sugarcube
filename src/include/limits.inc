; Megha SugarCube Operating System
; This file has the many limits (Maximam and Minimum values) used in the
; Operating System.

	MAX_LOADER_MODULES:		EQU	10
	DS_MAX_ITEMS:			EQU	50
	K_MSG_QUEUE_MAX_ITEMS: EQU 100
	K_MAX_NOTIFICATION_COUNT EQU 10
	VGA_COLUMNS: equ 80
	VGA_ROWS: EQU 25
	VGA_PAGES: EQU 2
	VGA_LAST_ROW_LAST_PAGE: EQU (VGA_PAGES * VGA_ROWS) -1
	VGA_FIRST_ROW_LAST_PAGE: EQU (VGA_PAGES -1) * VGA_ROWS
