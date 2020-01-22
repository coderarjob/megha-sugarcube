; Megha Sugarcube Operating System - Memory Management Routines
;
; Version: 21012020
; --------------------------------------------------------------------------
; These routines will find the segment which is large enough to load a program
; /module or some bytes in case of application programs dynamic memory
; allocation. 
;
; TODO: Dymanic Memory Allocation will (may) be done in a libray and not be a 
; system call at all. This way, the Programming Language can provide whatever
; memory managemnt that suits their need. MALLOC() will have a similar
; implementation, but can also be implemented differently in future. No need
; for the OS to provide memory management to individual processes. The below
; routines are souly for the kernel to use in Memory management for 
; Process/Modules
;
; The routine will look in the Storage Already allocated and find one or more 
; blocks which are large enough or will return an address after the last 
; program/module.

; --------------------------------------------------------------------------
; Sets the Status to FREE for the storage block(s) starting with the block
; whose Segment matches the input value in AX. These FREE blocks can later be
; used by the __alloc routine when a block of at-most the SIZE of the freed
; block(s) is requested.
; NOTES: Does not collate adjacent FREE blocks into one. This results in
;        waistage of storage as a FREE block of any size is alloted as long 
;	     its size > one requested.
; --------------------------------------------------------------------------
; Input:
; 	AX		- Segment
; --------------------------------------------------------------------------
; Output:
;	AX		- 0 Done, 
;			- 1 Segment is not found
; --------------------------------------------------------------------------
__k_free:
	push bx
	push cx
	push di
	push es

		mov bx, MDA_SEG
		mov es, bx

		; SI holds the address to compare for Segment
		lea di, [MDA.k_list_process_memory]

		; Find the segment
		; Total number of items in Storage table is MAX_MODULES + MAX_PROCESS
		mov cx, PROCESS_MAX_COUNT + KERNEL_MODULE_MAX_COUNT

.again:
			cmp [es:di + K_MEMORY_ITEM.Segment], ax
			je .found
			add di, K_MEMORY_ITEM_size
		loop .again

		; Not found, as we have check all the items and jump to found never
		; occured.
		jmp .notfound

		; Segment is found, DI holds the address in the Storage Table
.found:
		;xchg bx, bx
		mov cx, [es:di + K_MEMORY_ITEM.BlockCount]
		lea di, [di + K_MEMORY_ITEM.State]
.loop:
			mov [es:di], word MEM_ITEM_STATE_FREE
			add di, K_MEMORY_ITEM_size
		loop .loop
		
		; Success: AX = 0
		xor ax, ax
		jmp .end
.notfound:
		; Failed: Segment was not found in table
		mov ax, ERR_FREE_SEGMENT_NOT_FOUND 	; ERR_FREE_SEGMENT_NOT_FOUND = 1
.end:
	pop es
	pop di
	pop cx
	pop bx
ret

; --------------------------------------------------------------------------
; Allocates at-least the number of bytes specified in the input. When run for
; the time, it returns a Segment = MODULE0_SEG and allots whatever size that 
; was requested. If no consequetive FREE blocks are big enough, it will allot
; new block at the first UNALLOCATED block with the size that was requested.
; --------------------------------------------------------------------------
; Input:
; 	AX		- Size
; --------------------------------------------------------------------------
; Output:
;	AX		- New Segment location
;			- 0 if failed
; --------------------------------------------------------------------------
__k_alloc:
	push bx
	push cx
	push si
	push es

		mov bx, MDA_SEG
		mov es, bx

		; Reset variables
		mov word [.start_block], 0
		mov word [.totalsize], 0
		mov word [.nblocks], 0

		; BX holds the number of blocks checked.
		mov bx, 0
		jmp .load

.state1:
		cmp word [es:si + K_MEMORY_ITEM.State], MEM_ITEM_STATE_USED
		je .used
	
		; Not in USED state. Check if Free?
		cmp word [es:si + K_MEMORY_ITEM.State], MEM_ITEM_STATE_FREE
		je .state2

		; Not in USED, Free state. Check if Unallocated?
		cmp word [es:si + K_MEMORY_ITEM.State], MEM_ITEM_STATE_UNALLOCATED
		je .state3

.state2:
		; Increment the number of blocks, and total size
		inc word [.nblocks]

		mov cx, [.totalsize]
		add cx, [es:si + K_MEMORY_ITEM.Size]
		mov [.totalsize], cx			; Update TotalSize

		; We have a free block, we check if the Size of it is enough.
		; If it is we end, to we look at the next block.
		cmp cx, ax
		jl .load_next		; Not enough free storage found.

		; We have found enough free blocks	
		mov si, [.start_block]
		imul si, K_MEMORY_ITEM_size
		lea si, [si + MDA.k_list_process_memory]

		; Update the Block Count
		mov cx, [.nblocks]
		mov [es:si + K_MEMORY_ITEM.BlockCount], cx
		
		; Success [Return the new Segment]
		mov ax, [es:si + K_MEMORY_ITEM.Segment]

		; All the blocks need to be marked USED
		mov cx, [.nblocks]
		lea si, [si + K_MEMORY_ITEM.State]

.loop:
			mov [es:si], word MEM_ITEM_STATE_USED
			add si, K_MEMORY_ITEM_size
		loop .loop

		jmp .end

.state3:
		;xchg bx, bx
		; Check if Storage Block Index = 0.
		; We assign fixed Segment for the 1st Storage Block
		cmp bx, 0
		je .first_block_unallocated

		push si
			; Get the last Segment from the previous Storage Block
			sub si, K_MEMORY_ITEM_size		

			; Calculate new Segment after the current one.
			; New Segment = (Segment Size >> 4) + 1 + Segment
			mov cx, [es:si + K_MEMORY_ITEM.Size]
			shr cx, 4
			inc cx
			add cx, [es:si + K_MEMORY_ITEM.Segment]
		pop si
		
		jmp .write_block_parameters

.first_block_unallocated:
		mov cx, MODULE0_SEG

.write_block_parameters:
		; Check if Alloted Segment is within limits. (Out of Memory Check)
		cmp cx, PROCESS_MAX_SEGMENT
		jae .memory_full

		; Save the parameters to the new block

		mov [es:si + K_MEMORY_ITEM.Segment], cx
		mov [es:si + K_MEMORY_ITEM.Size], ax
		mov [es:si + K_MEMORY_ITEM.BlockCount], word 1
		mov [es:si + K_MEMORY_ITEM.State], word MEM_ITEM_STATE_USED

		; Success [Return the new Segment]
		mov ax, cx
		jmp .end


.used:
		;xchg bx, bx
		inc bx
		mov word [.start_block], bx

		; Reset variables
		mov word [.totalsize], 0
		mov word [.nblocks], 0
		jmp .load
.load_next:
		inc bx
.load:
		; Check index out of bounds
		cmp bx, (PROCESS_MAX_COUNT + KERNEL_MODULE_MAX_COUNT)
		jae .notfound

		; Get location to ith (i = BX) block
		mov si, bx				; Do not want to break the invariant bestowed
								; on bx. So using SI for IMUL
		imul si, K_MEMORY_ITEM_size
		lea si, [si + MDA.k_list_process_memory]
		
		jmp .state1

.memory_full:
.notfound:
		;xchg bx, bx
		mov ax, ERR_ALLOC_STORAGE_FULL	; ERR_ALLOC_STORAGE_FULL = 0
		jmp .end
.end:
	;xchg bx, bx
	pop es
	pop si
	pop cx
	pop bx
ret

.totalsize: dw 0
.start_block: dw 0
.nblocks  : dw 0
; --------------------------------------------------------------------------
