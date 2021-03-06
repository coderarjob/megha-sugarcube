; Megha OS Loader
; Loades different programs/modules into memory and calls the _init routine.
; Version: 19012020
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
; Changes in Version 0.21
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
;
; -------------------------
; Changes in Version 0.22
; -------------------------
; * We call AddToModuleList before calling the _init routine of the loaded 
;   module. This is done so that we can get the segment of the current module
;	for debugging, if the _init routine did not return, or we want a breakpoint 
;	in the _init routine.
; * Removed '.section data', as it resulted in wrong size of the output binary.

; ----------------------------
; Changes in Version 18012020
; ----------------------------
; * AddToModule now saves the Size of each module as well as a Word.
; * This is because, the first process will be loaded just where the last 
;   module ends.
; ----------------------------
; Changes in Version 19012020
; ----------------------------
; * AddToModule now saves information in two places. 
;   1. Modules list at 0x800:0x0
;   2. Allocated Memory List: 0x800:0x235E
;
; * Modules list has items with 
;   1. Index to the Allocated Memory List
;   2. Filename
;
; * Allocated memory list has items with
;   1. Status
;   2. Segment
;   3. Size

; This separation is done becuase Allocated memory Array will be used by both
; the Processes and modules. By keeping separate 3 lists (Process, Module,
; Allocated memory) we can keep the Memory Managent module generic and simple
; with complete decoupling from the meaning of a process and module.

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
	; Argument: Segment, Size, ASCIIZ Friendly Filename
	%macro AddToModuleList 3
		push si
		push cx
		push ax

			; load the argument into a register via the stack.
			; Also makes the below code work with any kind of
			;argument.
			push word %1
			push word %2
			push word %3
			pop si			; Friendly filename
			pop cx			; Size
			pop ax			; Segment

		; The filename provided will be in the format '\r\n aaaaa.bbb    0'.
		; The number of trailing space is such that the filename always has
		; length 15 (for displaying as columns when printed on screen).
		; We need to modify SI to that we donot copy the '\r\n ' but keep the
		; trailing spaces.
			add si, 3
			call __add_module_to_process_list
		pop ax
		pop cx
		pop si
	%endmacro

	; ******************************************************
	; MAIN BLOCK
	; ******************************************************
	
; Loader is loaded at location 0x800:0x400
	ORG 0x500

_init:
	; Clear the memory for storing loaded modules
	mov [MDA.k_w_modules_count], word 0

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

	; Add to the module list
	AddToModuleList [_init_addr+2], ax, di

	; call the _init routine of the loaded module
	push ds
		push 0		; argument count, there are none
		    call far [_init_addr] 
		sub sp, 2	; adjust for the push 0
	pop ds

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

	; Call Kernel Takeover routine (This will never return)
	mov bx, K_TAKEOVER
	int 0x40
	
	; clear the screen
	;mov bx, GURU_CLEARSCREEN
	;int 0x41

	; Print hello world
	;mov bx, GURU_PRINTSTRING 
	;mov ax, hello
	;int 0x41

	; print a number in hex format
	;mov bx, GURU_PRINTHEX
	;mov ax, 0xfa45
	;mov cx, 16
	;int 0x41

	mov bx, PIT_SET_COUNTER
	mov ax, 2
	mov cx, 0x4A8
	mov dx, 3
	int 0x40

	mov bx, PIT_SET_GATE
	mov ax, 1
	int 0x40

	;mov bx, GURU_HEXDUMP
	;xor ax, ax
	;mov dx, 0x0
	;mov cx, 0x40
	;int 0x40

	;mov bx, DS_ADD_ROUTINE
	;mov ax, 0xFF
	;int 0x40

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

; Input:
; 	AX - Segment
;	CX - Size
; 	DS:SI - ASCIIZ Friendly filename
; Output:
;	None
__add_module_to_process_list:
	pusha
	push es

		; get the count already in memory
		mov bx, [MDA.k_w_modules_count]

		; -------------------------------------------------
		; Add to Process Memory List
		; -------------------------------------------------
		push bx
			; each next location in the list.
			imul bx, K_MEMORY_ITEM_size

			; Fill in the list item.
			mov [bx + MDA.k_list_process_memory+ K_MEMORY_ITEM.Segment], ax
			mov [bx + MDA.k_list_process_memory+ K_MEMORY_ITEM.Size], cx
			mov word [bx + MDA.k_list_process_memory+ K_MEMORY_ITEM.State], MEM_ITEM_STATE_USED
			mov word [bx + MDA.k_list_process_memory+ K_MEMORY_ITEM.BlockCount], 1
		pop bx

		; -------------------------------------------------
		; Add to Modules list
		; -------------------------------------------------
		imul bx, K_MODULE_size
		mov word [bx + MDA.k_list_modules + K_MODULE.Segment], ax
		
		; -------------------------------------------------
		; Copy the filename
		; -------------------------------------------------

		; 1. Set DS = ESilename
		push ds		
		pop es

		; 2. Get Count of the filename
		mov cx, -1
		xor ax, ax
		mov di, si
		repne scasb
		inc cx
		neg cx

		; 3. Copy the filename
		lea di, [bx + MDA.k_list_modules+ K_MODULE.Filename]
		repne movsb 
		
		; Increment the count value
		inc word [MDA.k_w_modules_count]

	pop es
	popa
ret
; ================ Included files =====================
%include "../include/mos.inc"

; ================ Data for loader =====================
fat_files:   
         db 'GURU    MOD'
		 db 'DESPCHR MOD'
		 db 'PIT     MOD'
	     db 'KERNEL  MOD'
		 db 'KBD     MOD'
         ;db 'IO      DRV'
		 ;db 'VGA     MOD'
         db 0

_init_addr: dw 	 MODULE0_OFF
            dw   MODULE0_SEG

; ================ Text messages =======================
friendly_filenames: db 10,13," guru.mod   ",0
					db 10,13," despchr.mod",0
					db 10,13," pit.mod    ",0
					db 10,13," kernel.mod ",0
					db 10,13," kbd.mod    ",0

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
times 768 - ($-$$) db 0



