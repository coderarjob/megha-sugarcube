; Main include file for kernel, driver and application developers.
; It includes the function numbers for all interrupts in the MOS kernel.
; It also includes some version information of various files in this release of
; the MOS Operating System.

%ifndef __MOS_INC__
	%define __MOS_INC__

	; Version informations
	%define 	MOS_VER 		"0.1  (110819)"
	%define 	BOOTLOADER_VER 	"0.32 (110819)"
	%define 	LOADER_VER		"0.21  (130819)"
	%define		DEBUG_DRV_VER	"0.1  (100819)"
	%define		KERNEL_VER		"0.1 (180819)"

	; Settings: -
		; Colors and look and feel
		DEFAULT_TEXT_COLOR:			EQU	0xF		; WHITE

		; String Comparison
		MATCH_CASE_INSENSITIVE: 	EQU 0
		MATCH_CASE_SENSITIVE: 		EQU 1
		STRING_MATCH: 				EQU MATCH_CASE_INSENSITIVE

	; Basic Structures used by the OS and application programs.
	struc Q
		.length:	resb 2
		.width:		resb 2	; We only needed a byte, but a word is easier to 
							; work with. Also some instructions like IMUL is 
							; more flexible with word or double word.
		.head:		resb 2	; Index in the buffer where to read next.
		.tail:		resb 2	; Index in the buffer where last write was.
		.buffer:	resb 1 	
	endstruc

	struc FAR_POINTER
		.Offset	resw 1
		.Segment resw 1
	endstruc

	%macro PROC 1
		%1.Offset resw 1
		%1.Segment resw 1
		%1 EQU %1.Offset
	%endmacro

	; MOS Fixed Memory Locations
	%include "../include/mem.inc"

	; Kernel Structures and constants.
	%include "../include/kernel.inc"

	; Maximan and Minimum limits
	%include "../include/limits.inc"

	; MOS Data Area Structures and Constants
	%include "../include/mda.inc"

	; Routines in guru.mod (accessed via INT 0x41)
	GURU_PRINTHEX			EQU 0
	GURU_PRINTSTRING		EQU 1
	GURU_CLEARSCREEN		EQU 2
	GURU_HEXDUMP			EQU 3

	; Kernel Routines
	K_IO_ADD_MESSAGE		EQU 10
	K_IO_GET_MESSAGE		EQU 11
	K_TAKEOVER				EQU 12
	K_IO_ADD_NOTIFICATION	EQU 13

	; Routines in 8254.mod (accessed via INT 0x40)
	PIT_SET_COUNTER			EQU 20
	PIT_SET_GATE			EQU 21
	
	; Routines in VGA.mod	(accessed via INT 0x40)
	VGA_WRITE					EQU 22
	VGA_SCROLL_UP				EQU 23
	VGA_SCROLL_DOWN				EQU 24
	VGA_SET_CURSOR_LOCATION		EQU 25
	VGA_SET_CURSOR_ATTRIBUTES	EQU 26
	VGA_SET_TEXT_ATTRIBUTES		EQU 27

	; Routines in despatcher.mod (accessed via INT 0x40)
	DS_ADD_ROUTINE			EQU 48
%endif
