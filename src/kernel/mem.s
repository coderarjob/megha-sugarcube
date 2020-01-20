; Megha Sugarcube Operating System - Memory Management Routines
;
; These routines will find the segment which is large enough to load a program
; /module or some bytes in case of application programs dynamic memory
; allocation. 
; TODO: Dymanic Memory Allocation may be done in a libray and not be a 
; system call at all.
;
; In case of programs/modules, the routine will look in the Memory Already
; allocated and find one or more blocks which are large enough or will return an
; address after the last program/module.

; Input:
; 	AX		- Segment
; Output:
;	AX		- 0 Done, 1 Segment is not found
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
		mov cx, PROCESS_MAX_COUNT + KERNEL_MODULE_MAX_COUNT
		jmp .match

.again:
			add di, K_MEMORY_ITEM_size
.match:
			cmp [es:di + K_MEMORY_ITEM.Segment], ax
		loopne .again

		; If CX = 0, then the Segment is not found.
		jcxz .notfound
		
		;xchg bx, bx
		; Segment is found, DI holds the address in the Storage Table
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
		xor ax, ax
		mov ax, 1
.end:
	pop es
	pop di
	pop cx
	pop bx
ret

; Input:
; 	AX		- Size
; Output:
;	AX		- New Segment location
;	AX		- 0 is failed
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
		
		jmp .save_parameters

.first_block_unallocated:
		mov cx, MODULE0_SEG

.save_parameters:
		; Save the parameters to the new block

		mov [es:si + K_MEMORY_ITEM.Segment], cx
		mov [es:si + K_MEMORY_ITEM.Size], ax
		mov [es:si + K_MEMORY_ITEM.BlockCount], word 1
		mov [es:si + K_MEMORY_ITEM.State], word MEM_ITEM_STATE_USED

		; Success [Return the new Segment]
		mov ax, cx
		jmp .end

.notfound:
		;xchg bx, bx
		xor ax, ax
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
