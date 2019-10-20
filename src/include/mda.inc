; Megha Operating System (MOS) Data Area Maps

%ifndef __MDA_INC_
	%define __MDA_INC_

	; We store the addresses of loaded programs/modules in a list at
	; location 0x800:0x1. 0x800:0 is used to store the number of item in 
	; this list.

	MAX_LOADER_MODULES:	EQU	10

	struc da_loader_module_list 
	    .count     resb 1
	    .seg_start resw 1
	endstruc

	
	; Despatcher stores routines in this list. It starts from 0x800:21.
	; Each of the item has an offset and segment of the subroutine.
	; A subroutine can be called by putting routine number in BX and
	; calling INT 0x41
	
	DS_MAX_ITEMS:	EQU	50
	
	struc da_desp_routine_list_item, 21
		.offset_start resw 1
		.seg_start    resw 1
	endstruc

%endif
