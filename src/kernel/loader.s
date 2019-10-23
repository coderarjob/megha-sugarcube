; Megha OS Loader
; Loades different programs/modules into memory and calls the _init routine.
; Version: 0.21 (130819)
;
; Initial version was 0.2
;
; -------------------------
; Changes in Version 0.2
; -------------------------
; * The loader output welcome message now has a ascii art 
;   (The letter capital M).
;
; -------------------------
; Changes in Version 0.2
; -------------------------
; * Loads multiple files/modules mentioned in fat_files location.
;
; * Load location of files are calculated based on the size of the previous
;   loaded file. Files are loaded right after one another, but at a 16 byte
;   boundary.
;
; * Do not load the 'splash' bitmap file. That job is now not part of the
;   loader.
;
; * Displays friendly messages while loading files and when error occures in
;   loading files.
;
; * Max file size of the loader is 768 bytes. 
;
; * Loaded is loaded at location 0x800:0x100 which is an area shared by the MOS
;   data block. After the loader is done working can control is transfered to
;   the CLI, this area will be reused by the kernel.
;
; * Maintains a list at location 0x800:1, with each entry holding the segment
;   number where each of the module is loaded. There is also at 0x800:0 a
;   'count' of entries in the list.
;
; * Includes a file called 'mos.inc'. This file lists versions of all the
;   different modiles in the operating system, and different function numbers
;   that can be called via each of the software interrupts of the OS.

	; ******************************************************
	; MACRO AND STRUCTURE BLOCK
	; ******************************************************

	%macro printString 1
		push si
		    mov si, %1
		    int 0x31
		pop si
	%endmacro


	; We store the addresses of loaded programs/modules in a list at
	; location 0x800:0x1. 0x800:0 is used to store the number of item in 
	; this list.
	; This structure can be found in the mda.inc file
	%macro AddToModuleList 1
		push bx
		push ax
			; load the argument into a register.
			; This will save us from specifying a operand size.
			; Also makes the below code work with any kind of
			;argument.
			mov ax, %1
			; get the count already in memory
			xor bx, bx
			mov bl, [da_loader_module_list.count]

			; each list item is 2 bytes long, so we multiply by 2
			shl bx, 1	
			mov [bx + da_loader_module_list.seg_start], ax

			; Increment the count value
			inc byte [da_loader_module_list.count]
		pop ax
		pop bx
	%endmacro

	; ******************************************************
	; MAIN BLOCK
	; ******************************************************
	
; Loader is loaded at location 0x800:0x100
	ORG 0x100

_init:
	; Clear the memory for storing loaded modules
	mov [da_loader_module_list.count], byte 0

	; Prints version information and other statup messages.
	printString msg_loader_welcome

	; Loads the start address of the list of files to load into 
	;index registers.
	mov si, fat_files
	mov di, friendly_filenames
.load_next:
	cmp [si],byte 0
	je .load_end

	; print the name of the file to be loadede on screen. 
	printString di

	; Load the file to memory
	; Inputs: 
	; 1) File is loaded into a segment at a specific offset. These are 
	;    * Segment: [_init_addr + 2]
	;    * Offset : [_init_addr]
	; 2) SI register points to the filename in fat_files.

	mov ax, [_init_addr + 2]
	mov bx, [_init_addr]
	mov dx, si
	int 0x30

	; On successful load, AX should contain the size of the file that was
	; loaded. If set to zero, the file could not be loaded.
	cmp ax, 0
	je failed_file_not_found

	; call the _init routine of the loaded module
	push ds
		push 0		; argument count, there are none
		    call far [_init_addr] 
		sub sp, 2	; adjust for the push 0
	pop ds

	; Add to the module list
	AddToModuleList [_init_addr+2]

	; print 'loading complete message'
	printString msg_file_loaded

	; calculate the next segment
	; seg = (size (ax) + OFFSET (_init_addr) >> 4) +1 + seg
	add ax, [_init_addr]
	shr ax, 4
	inc ax
	add [_init_addr + 2], ax
	
	;  Progress the two index registers
	add di, 15		; 15 bytes per entry in friendly file names
	add si, 11		; 11 bytes per entry in fat_files
	jmp .load_next
.load_end:
	
	; clear the screen
	mov bx, GURU_CLEARSCREEN
	int 0x41

	; Print hello world
	mov bx, GURU_PRINTSTRING 
	mov ax, hello
	int 0x41

	; print a number in hex format
	mov bx, GURU_PRINTHEX
	mov ax, 0xfa45
	mov cx, 16
	int 0x41

	mov bx, GURU_HEXDUMP
	xor ax, ax
	mov dx, 0x0
	mov cx, 0x40
	int 0x41

	mov bx, DS_ADD_ROUTINE
	mov ax, 0xFF
	int 0x40

	;mov bx, GURU_CLEARSCREEN
	;int 0x41

	;mov ax, dummy_str
	;mov bx, GURU_PRINTSTRING
	;int 0x41
	

	jmp exit

failed_file_not_found:
	printString msg_file_not_found
exit:
	jmp $

; ================ Included files =====================
section .data

%include "../include/mos.inc"
%include "../include/mda.inc"

dummy_str: db 'Arjob Mukherjee',0
; ================ Data for loader =====================
fat_files:   db 'GURU    MOD'
	     db 'DESPCHR MOD'
	     db 'KERNEL  MOD'
             ;db 'IO      DRV'
             db 0

_init_addr: dw 	 0x64
            dw   0x840 ;MODULE0_SEG

; ================ Text messages =======================
friendly_filenames: db 10,13," guru.mod...",0
		    db 10,13," despchr.mod",0
		    db 10,13," kernel.mod.",0
		    db 10,13," io.drv.....",0

msg_file_loaded:    db "   Done",0
msg_file_not_found: db "   Not found",0
fatal_error:	    db "Cannot continue. Fatal error.",0

;msg_loader_welcome: db "Megha Operating System (MOS) ", MOS_VER,10,13
		    ;db "MOS Loader ", LOADER_VER, 10,13,0

msg_loader_welcome: db 10,13,10,13
		    db ' ####      ####  ',10,13
		    db ' ## ##    ## ##  ','Megha Operating System (MOS)',10,13
		    db ' ##  ##  ##  ##  ','Version:',MOS_VER,10,13         
		    db ' ##   ####   ##  ','MOS Loader ', LOADER_VER, 10,13
		    db ' ##    ##    ##  ',10,13
		    db ' ----------------------------------------------'
		    db 10,13,' Loading modules..',10,13,0

hello: db "Showing this message using a debug.mod routine.",13,10
       db "Result: 0x",0
; ================ ZERO PADDING =======================
times 768 - ($ - $$) db 0



