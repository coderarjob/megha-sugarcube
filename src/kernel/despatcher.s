; Megha Operating System (MOS) Software Interrupt 0x40 despatcher
; Version: 0.11 (240819)
;
; Changes in 0.11 (24th Aug 2019)
; -------------------------------
; * The global despatcher is now installed in the IVT at vector 40. Previously
;   it was at 41st location in IVT.
;
; Every module, driver or process in MOS starts at an offset of 0x64
	ORG 0x64

; The first routine is _init, a initialization routine that works that is used
; to setup the data structures or to install a routine to IVT.
_init:
	pusha	; Push AX, BX, CX, DX, SI, DI, SP, BP

	    ; Install the despatcher routine into IVT
	    xor bx, bx
	    mov es, bx
	    mov [es:0x40 * 4], word  despatcher
	    mov [es:0x40 * 4 + 2], cs
	    
	    ; Register the addRoutine
	    ; Note: I cannot just do call far es:addRoutine, this is why we are
	    ; using .proc_addr as the pointer to the call location.
	    mov [.proc_addr],word addRoutine
	    mov [.proc_addr+2], cs
	    mov al, DS_ADD_ROUTINE
	    mov cx, cs
	    mov dx, addRoutine
	    call far [.proc_addr]

	popa
; It is importaint to do a RETF in the end, to be able to return to the loader.
	retf
.proc_addr: resw 1
	    resw 1
; Dispatcher is the function that will be installed into the IVT. 
; The function will be identified by a number in BX register.
; Arguments are provided in AX, CX, DX, SI, DI. 
; Return in 
; 	* BX - if upto 16 bits
;	* AX:BX - if return value is > 16 bits but <= 32 bits
;	* ES:BX - Far pointer

; Points to note:
; 1. The DS register points must point to the data segment of the caller. This
;    is done to be able operate string instrucions more easily without the 
;	 need to switch segments.
; 2. Call the appropriate function and
; 3. Restore the DS to the same value as it was when dispatcher was called.
; 4. CX, DX, DS, GS, SI, DI are preserved. AX, BX, ES are not always preserved.
;
; Input: BX   - Module number (must be < 256)
; Output: BX  - Value comes from the routine that was called.
despatcher:
	push cx
	push dx
	push si
	push di
	push ds

	;TODO: Can we do without GS. IT WAS NOT PRESENT IN 8086
	; Three segment addresses are needed here:
	;	* DS - Segment of the caller
	;	* ES - Currently unchanged. But can be changed by the called routine.
	;	* GS - MOS data area segment.
	push gs
	    push bx
			; Set GS to the MDA segment
			mov bx, MDA_SEG
			mov gs, bx
	    pop bx

		; Each of the item in call table is 4 bytes
		shl bx, 2

	    ; Do a far call to the function based on the value in BX
	    call far [gs:(bx + da_desp_routine_list_item.offset_start)]

	pop gs
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	iret

; This function installs a routine in the Despatcher Data Area.
; Input: AL  - Interrupt number (used to calculate offet in the Data Area)
;        CX  - Segment of the routine
;        DX  - Offset of the routine
; Output: None
addRoutine:
	push bx
	push es
    
	; Compare the input interrupt number and report error if it is more
	; than the maximum allowed.
	cmp al, DS_MAX_ITEMS
	jae .toomuch
	
	mov bx, MDA_SEG
	mov es, bx

	xor bx, bx
	mov bl, al

	; 4 bytes is the size of desp_routine_list_item.
	shl bx,2		; multiply BX by 4

	mov [es:(bx + da_desp_routine_list_item.offset_start)], dx
	mov [es:(bx + da_desp_routine_list_item.seg_start)], cx

	; Output success
	mov al, 0
	jmp .end
.toomuch:
	; Output failure status
	; As DS is set to the caller data segment, we switch it to the current code
	; segment for PANIC call to display the local message.
	push ds
		push cs
		pop ds

		push invalid_routine_number_msg
		int 0x42
	pop ds
.end:
	pop es
	pop bx
	retf

; ==================== INCLUDE FILES ======================
%include "../include/mda.inc"
%include "../include/mos.inc"

; ===================== DATA SECTION ======================
invalid_routine_number_msg: db ";( addRoutine (despatcher). Routine number is "
                            db "invalid.",0
