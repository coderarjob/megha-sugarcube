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

	; MOS Data Area Structures and Constants
	%include "../include/mda.inc"

	; Kernel Structures and constants.
	%include "../include/kernel.inc"

	; Maximan and Minimum limits
	%include "../include/limits.inc"

	; Routines in guru.mod (accessed via INT 0x41)
	GURU_PRINTHEX			EQU 0
	GURU_PRINTSTRING		EQU 1
	GURU_CLEARSCREEN		EQU 2
	GURU_HEXDUMP			EQU 3

	; Routines in despatcher.mod (accessed via INT 0x40)
	DS_ADD_ROUTINE			EQU 0x30

	; Routines in 8254.mod (accessed via INT 0x40)
	PIT_SET_COUNTER			EQU 10
	PIT_SET_GATE			EQU 11
%endif
