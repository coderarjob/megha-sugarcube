; Megha Operating System (MOS) Data Area Maps

%ifndef __MDA_INC_
	%define __MDA_INC_

	; Segment and fixed lengths of different parts of MOS
	MDA_SEG:		EQU 	0x800
	MDA_OFF:		EQU		0x0
	MDA_LEN:		EQU		1024

	LOADER_SEG		EQU		0x800
	LOADER_OFF:		EQU		0x100
	LOADER_LEN:		EQU		768

	MODULE0_SEG:	EQU		0x840
	MODULE0_OFF:	EQU		0x64

	; We store the addresses of loaded programs/modules in a list at
	; location 0x800:0x1. 0x800:0 is used to store the number of item in 
	; this list.


	struc da_loader_module_list 
	    .count     resb 1
	    .seg_start resw 1
	endstruc

	
	; Despatcher stores routines in this list. It starts from 0x800:21.
	; Each of the item has an offset and segment of the subroutine.
	; A subroutine can be called by putting routine number in BX and
	; calling INT 0x41
	
	
	struc da_desp_routine_list_item, 21
		.offset_start resw 1
		.seg_start    resw 1
	endstruc

%endif
