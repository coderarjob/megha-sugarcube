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
			DEFAULT_TEXT_COLOR:		EQU	0xF		; WHITE

		; String Comparison
		MATCH_CASE_INSENSITIVE: 	EQU 0
		MATCH_CASE_SENSITIVE: 		EQU 1
		STRING_MATCH: 				EQU MATCH_CASE_INSENSITIVE

	; Segment and fixed lengths of different parts of MOS
	MDA_SEG:		EQU 	0x800
	MDA_OFF:		EQU		0x0
	MDA_LEN:		EQU		1024

	LOADER_SEG		EQU		0x800
	LOADER_OFF:		EQU		0x100
	LOADER_LEN:		EQU		768

	MODULE0_SEG:	EQU		0x840
	MODULE0_OFF:	EQU		0x64
	
	; Routines in guru.mod (accessed via INT 0x41)
	GURU_PRINTHEX			EQU 0
	GURU_PRINTSTRING		EQU 1
	GURU_CLEARSCREEN		EQU 2
	GURU_HEXDUMP			EQU 3

	; Routines in despatcher.mod (accessed via INT 0x40)
	DS_ADD_ROUTINE			EQU 0x30

	; Routines in vfs.mod (accessed via INT 0x40)
	VFS_OPEN				EQU 0xA
	VFS_CLOSE				EQU 0xB
	VFS_MOUNT				EQU 0xC
	VFS_UMOUNT				EQU 0xD
	VFS_REGISTER_FS			EQU 0xE
%endif
