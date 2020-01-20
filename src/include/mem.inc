
; Megha Operating System (MOS) Various Fixed Memory Locations

%ifndef __MEM_INC_
	%define __MEM_INC_

	; Segment and fixed lengths of different parts of MOS
	MDA_SEG:		EQU 	0x800
	MDA_OFF:		EQU		0x0
	MDA_LEN:		EQU		12 * 1024		; 12 KiB

	LOADER_SEG		EQU		0x800
	LOADER_OFF:		EQU		0x500
	LOADER_LEN:		EQU		1024			; Just some large enough number.

	MODULE0_SEG:	EQU		0xB00			; Data area ends at 0xB000
	MODULE0_OFF:	EQU		0x10

	VGA_TEXT_MEM_SEG: EQU	0xB800
%endif
