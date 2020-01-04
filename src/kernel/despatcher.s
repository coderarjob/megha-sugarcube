; Megha Operating System (MOS) Software Interrupt 0x40 despatcher
; Version: 0.11 
;
; Changes in 0.11 (24th Aug 2019)
; -------------------------------
; * The global despatcher is now installed in the IVT at vector 40. Previously
;   it was at 41st location in IVT.
;
; Changes in 281219 (28th Dec 2019) (CANCELLED)
; -------------------------------
; * The despatcher module will not be part of the Kernal module and will not be
;   loaded separetely by the loader. When the kernal gets loaded by the loader,
;   the _init routine of the Despatcher will be called by the _init routine 
;   of the kernel module.
;   In effect this change will reduce the segment fragmentation and keep the
;   kernel is the same segment. This would help in debugging as well. 
;   And futhter more there is no need for despatcher to be a separate module on
;	its own.
; * As it is not part of the Kernel module, no ORG is needed.
; * Renamed _init routine to despatcher_init
;
; Changes in 291219 (29th Dec 2019)
; ----------------------------------
; * addRoutine takes module number in AX instead of AL
; * Despatcher sets DS to the Code Segment of the called function.
; * Upto 16 bits are returned in AX, 32 bits are returned in AX:BX
; * Includes only the mos.inc file. The MOS.INC file now includes 
;   every other INC files needed for Kernel Development.

; The first routine is _init, a initialization routine that works that is used
; to setup the data structures or to install a routine to IVT.

; Loader modules start at location 0x10
	org 0x10

_init:
	pusha	; Push AX, BX, CX, DX, SI, DI, SP, BP

	    ; Install the despatcher routine into IVT
	    xor bx, bx
	    mov es, bx
	    mov [es:0x40 * 4], word  sys_despatcher
	    mov [es:0x40 * 4 + 2], cs
	    
	    ; Register the addRoutine
	    mov ax, DS_ADD_ROUTINE
	    mov cx, cs
	    mov dx, sys_addRoutine
		call __sys_addRoutine
	popa
; It is importaint to do a RETF in the end, to be able to return to the loader.
	retf

; Dispatcher is the function that will be installed into the IVT. 
; The function will be identified by a number in BX register.
; Arguments are provided in AX, CX, DX, SI, DI. 
; Return in 
; 	* AX - if upto 16 bits
;	* AX:BX - if return value is > 16 bits but <= 32 bits
;
; Points to note:
; 1. The DS register points to the Code Segment of the called routine.
;	 Becuase we are goint to use far pointers always, there is no need 
;	 for the DS to be set in the despatcher. The called routine is free to use
;	 DS as it pleases. 
; 2. Restore the DS to the same value as it was when dispatcher was called.
; 3. CX, DX, DS, ES, SI, DI are preserved. AX, BX are not preserved.
;
; Input: BX   	 - Module number (must be < 256)
; Output: AX,BX  - Value comes from the routine that was called.
sys_despatcher:
	push cx
	push dx
	push si
	push di
	push ds
	push es

	; Three segment addresses are needed here:
	;	* DS - Segment of the caller
	;	* ES - Currently unchanged. But can be changed by the called routine.
	;	* GS - MOS data area segment.
	push bx
		; Set GS to the MDA segment
		mov bx, MDA_SEG
		mov es, bx
	pop bx

	; Each of the item in call table is 4 bytes
	shl bx, 2

	; Set DS to the Code Segment of the routine.
	push bx
		;mov bx, [es:(bx + da_desp_routine_list_item.seg_start)]
		mov bx, [es:(bx + MDA.dsp_lstd_routines + FAR_POINTER.Segment)]
		mov ds, bx
	pop bx

	; Do a far call to the function based on the value in BX
	;call far [es:(bx + da_desp_routine_list_item.offset_start)]
	call far [es:(bx + MDA.dsp_lstd_routines + FAR_POINTER.Offset)]

	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	iret

; [SYSTEM CALL - __sys_addRoutine]
; This function installs a routine in the Despatcher Data Area.
; Input: AX  - Interrupt number (used to calculate offet in the Data Area)
;        CX  - Segment of the routine
;        DX  - Offset of the routine
; Output: None
sys_addRoutine:
	call __sys_addRoutine
	retf

; This function installs a routine in the Despatcher Data Area.
; Input: AX  - Interrupt number (used to calculate offet in the Data Area)
;        CX  - Segment of the routine
;        DX  - Offset of the routine
; Output: None
__sys_addRoutine:
	push bx
	push es
    
	; Compare the input interrupt number and report error if it is more
	; than the maximum allowed.
	cmp ax, DS_MAX_ITEMS
	jae .toomuch
	
	mov bx, MDA_SEG
	mov es, bx

	xor bx, bx
	mov bl, al

	; 4 bytes is the size of desp_routine_list_item.
	shl bx,2		; multiply BX by 4

	;mov [es:(bx + da_desp_routine_list_item.offset_start)], dx
	;mov [es:(bx + da_desp_routine_list_item.seg_start)], cx
	mov [es:(bx + MDA.dsp_lstd_routines + FAR_POINTER.Offset)], dx
	mov [es:(bx + MDA.dsp_lstd_routines + FAR_POINTER.Segment)], cx

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
	ret

; ==================== INCLUDE FILES ======================
%include "../include/mos.inc"

; ===================== DATA SECTION ======================
invalid_routine_number_msg: db ";( addRoutine (despatcher). Routine number is "
                            db "invalid.",0
