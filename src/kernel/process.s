; Megha Sugarcube Operating System - Process Routines
; ----------------------------------------------------------------------------
; Version: 22012020
; ----------------------------------------------------------------------------
; Routines here will be responsible for Creating, Switching and Closing process
; (user programs). Even tough Megha is a Single Process OS, it can keep upto 4
; applications in memory (each can target one of the two virtual TTY), but only
; one can be active at anytine.
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; Creates a process for the input executable file.
; ----------------------------------------------------------------------------
; Input:
; 	AX:CX	- ASCIIZ File name
;	DX		- TTY ID
; Output:
;	AX		- PID (Starts from 1)
;			- 0 is failed
; ----------------------------------------------------------------------------
struc CREATE_PROCESS_LVARS
	FAR_ADDRESS .Filename	; 0 - bp to bp+3
	.Segment  resw 1		; 4 - bp+4 to bp+5
	.ProcessID resw 1		; 6 - bp+6 to bp+7
	.TTYID	   resw 1		; 8 - bp+8 to bp+9
	.ProgramSize resw 1		;10 - bp+10 to bp+11
endstruc
; ----------------------------------------------------------------------------
sys_k_process_create:

	push bp
	sub sp, CREATE_PROCESS_LVARS_size		; Allocate space on Stack
	mov bp, sp

	push bx
	push cx
	push dx
	push si
	push di
	push es

	;------------------------------------------------------------------------
	; Initialize the local variables
	;------------------------------------------------------------------------
	mov [bp + CREATE_PROCESS_LVARS.Filename.Segment], ax
	mov [bp + CREATE_PROCESS_LVARS.Filename.Offset], cx
	mov [bp + CREATE_PROCESS_LVARS.TTYID], dx
	mov [bp + CREATE_PROCESS_LVARS.Segment], word 0
	mov [bp + CREATE_PROCESS_LVARS.ProcessID], word 0

	;------------------------------------------------------------------------
	; Initalize Segments
	;------------------------------------------------------------------------
	mov ax, MDA_SEG
	mov es, ax

	;------------------------------------------------------------------------
	; Allocate memory for the new Process.
	;------------------------------------------------------------------------
	; TODO: After the filesystem routines are ready, I can have the size of the
	; file, before reading the contents. That way I do not have to enter
	; hardcoded values. Currently just as an temporary measure, I will allocate
	; memory of size 10K (from the file) + 1K (Stack) + 1K (Unallocated memory).
	;------------------------------------------------------------------------
	mov ax, 10*1024 + PROCESS_MAX_STACK + PROCESS_MAX_UNALLOCATED_STORAGE
	call __k_alloc

	;xchg bx, bx
	; Check if __k_alloc was successful. If it is not successful, it returns 0
	; in AX.
	cmp ax, ERR_ALLOC_STORAGE_FULL
	je .failed

	; Store the Segment allocated for later use.
	mov [bp + CREATE_PROCESS_LVARS.Segment], ax

	; ------------------------------------------------------------------------
	; Load the file into the segment.
	; ------------------------------------------------------------------------
	; Note: Becuase the above 10K space is an arbitary size, the file loaded
	; could have a size > 10K. This is going to change once the filesystem is 
	; up and running.
	;
	; NOTE: INT 0x30 - Loads file with filename at DS:DX into AX:BX Location.
	; ------------------------------------------------------------------------
	push ds
		; Set the filename location in DS:DX
		mov bx, [bp + CREATE_PROCESS_LVARS.Filename.Segment]
		mov ds, bx
		mov dx, [bp + CREATE_PROCESS_LVARS.Filename.Offset]

		; Set load address at AX:BX
		mov ax, [bp + CREATE_PROCESS_LVARS.Segment]
		mov bx, MODULE0_OFF
		int 0x30		
	pop ds
	
	; Check if file was loaded successfully. AX = 0, if file could not be
	; loaded, most possibly because the filemame is incorrect or file with 
	; the name is not found.
	;xchg bx, bx
	cmp ax, 0
	je .failed_load_file

	; Store the Program Size
	mov [bp + CREATE_PROCESS_LVARS.ProgramSize], ax

	; ------------------------------------------------------------------------
	; Search for an available slot in the Process Table.
	; ------------------------------------------------------------------------
	; Add an entry about the new Process in the Process table in MDA.
	; We add to the Process table here, because in case of an error while 
	; loading the file, we do not have have to go back and remove the new 
	; entry from the Process table.
	; ------------------------------------------------------------------------
		
	; We are looking for an entry in the process table whose State = Killed.
	mov di, MDA.k_list_process
	mov cx, PROCESS_MAX_COUNT
.again:
		cmp [es:di + K_PROCESS.State], word PROCESS_STATE_KILLED
		je .found

		; Current entry is not FREE, check the next entry.
		add di, K_PROCESS_size		
	loop .again

	; There are no free slots available.
	jmp .failed_process_list_full
	
	; ------------------------------------------------------------------------
	; We are going to add an entry at ES:DI
	; ------------------------------------------------------------------------
.found:
	; ------------------------------------------------------------------------
	; A. PROCESS ID, STATE AND TTY ID
	; ------------------------------------------------------------------------
	; Process ID = (CX - PROCESS_MAX_COUNT) + 1   ProcessID starts from 1
	; ------------------------------------------------------------------------
	sub cx, PROCESS_MAX_COUNT
	inc cx

	mov [es:di + K_PROCESS.ProcessID], cx						; PROCESS ID
	mov [es:di + K_PROCESS.State],word PROCESS_STATE_DORMANT	; STATE

	mov ax, [bp + CREATE_PROCESS_LVARS.TTYID]
	mov [es:di + K_PROCESS.TTYID],ax							; TTY ID

	; ------------------------------------------------------------------------
	; B. SEGMENT AND GENERAL PURPOSE REGISTERS
	; Load the General Purpose Registers (32 BIT) in the Process Table wit the
	; appropritate values. All are 32 bit locations.
	; ------------------------------------------------------------------------
	xor eax, eax
	mov [es:di + K_PROCESS.EAX], eax
	mov [es:di + K_PROCESS.EBX], eax
	mov [es:di + K_PROCESS.ECX], eax
	mov [es:di + K_PROCESS.EDX], eax
	mov [es:di + K_PROCESS.ESI], eax
	mov [es:di + K_PROCESS.EDI], eax
	mov [es:di + K_PROCESS.EFLAGS], eax
	mov [es:di + K_PROCESS.ES], ax
	mov [es:di + K_PROCESS.GS], ax
	mov [es:di + K_PROCESS.FS], ax
	mov [es:di + K_PROCESS.BP], ax

	; Calculate and set the Stack Pointer
	; Stack Pointer = MODULE0_OFFSET + ProgramSize + StackSize -1
	; SP = 0x10 + 0x300 (say) + 1024 - 1 = 0x70F (Stack from 0x310 to 0x70F)
	mov ax, [bp + CREATE_PROCESS_LVARS.ProgramSize]
	add ax, MODULE0_OFF
	add ax, PROCESS_MAX_STACK
	dec ax

	mov [es:di + K_PROCESS.SP], ax
	mov [es:di + K_PROCESS.StackEnd], ax
	; ------------------------------------------------------------------------
	; Store the Segment in the Process Table entry.
	; This ensures the HIGH WORD in EAX is ZERO and only the LOW WORD will 
	; have the segment.
	; ------------------------------------------------------------------------
	mov ax, [bp  + CREATE_PROCESS_LVARS.Segment]
	mov [es:di + K_PROCESS.Segment], ax
	mov [es:di + K_PROCESS.CS], ax
	mov [es:di + K_PROCESS.DS], ax
	mov [es:di + K_PROCESS.SS], ax
	mov [es:di + K_PROCESS.IP], word MODULE0_OFF

	; ------------------------------------------------------------------------
	; C. Copy Filename	to the Process Table Entry.
	; ------------------------------------------------------------------------
	push ds
	push di
		mov cx, 11
		; Source: DS:SI
		mov ax, [bp + CREATE_PROCESS_LVARS.Filename.Segment]
		mov ds, ax
		mov si, [bp + CREATE_PROCESS_LVARS.Filename.Offset]
		;Destination: ES:DI
		lea di, [di + K_PROCESS.Filename]
		rep movsb			; Copy 11 bytes from DS:SI to ES:DI
	pop di
	pop ds
	; ------------------------------------------------------------------------

	; Success, return
	mov ax, [es:di + K_PROCESS.ProcessID]
	jmp .end

	; ------------------------------------------------------------------------
.failed_process_list_full:
.failed_load_file:
	; Free up the allocated segment
	;xchg bx, bx
	mov ax, [bp + CREATE_PROCESS_LVARS.Segment]
	call __k_free	
.failed:
	; Failed to create process. AX = 0 
	xor ax, ax
	; ------------------------------------------------------------------------
.end:
	;xchg bx, bx
	pop es
	pop di
	pop si
	pop dx
	pop cx
	pop bx

	add sp, CREATE_PROCESS_LVARS_size
	pop bp
ret
; ------------------------------------------------------------------------

; ----------------------------------------------------------------------------
; Jumps to the CS:IP of the process mentioned in the input.
; This routine also preserves the state of the Current Process before
; switching. If the Current Process = 0, then we do not save the status of the
; current process. Current Process = 0 means that the control still lies with
; the Operating System, and the first proceess has not yet started.
;
; The basic operation would be the following in the order given.
; 1. If CurrentProcessID == 0 Goto RestoreAndJump
; 2. If CurrentProcessID == Input Goto End
; 3. Save the Current GPRs (as is in the routine, as the restore point will be
; 	 within the routine)
; 4. Save the Segment registers.
; 5. Save the Stack Registers (BP, SP)
; RestoreAndJump:
; 1. Restore the GPRs 
; 2. Save the Stack Registers (BP, SP)
; 3. Restore the Segment registers.
; 4. Set CurrentProcessID = Input
; 5. Jump to RestorePoint
; ----------------------------------------------------------------------------
; Input:
; 	AX		- Process ID (1st Process ID = 1, not Zero)
; Output:
;	AX		- 0 Success
;			- 1 Process not found.
; ----------------------------------------------------------------------------
sys_k_process_switch:
	push es
	push si
	push bx

	mov bx, MDA_SEG
	mov es, bx

	; ------------------------------------------------------------------------
	; Validation of the Input
	; ------------------------------------------------------------------------
	; TODO: Check if CurrentProcessID == Input AX. If so we exit.
	; Process ID starts from 1, we decrement it so that we can use it as an
	; index into the Process Table.
	dec ax

	; Check if input is a valid Process ID
	cmp ax, PROCESS_MAX_COUNT
	jae .failed_invalid_processid

	; Process ID is valid

	; ------------------------------------------------------------------------
	; Save the Current Process State in the Entry for the CurrentProcessID
	; If CurrentProcessID == 0, we skip Saving the Current Process.
	; ------------------------------------------------------------------------
	cmp word [es:MDA.k_w_currentprocess], 0
	je .process_saved

	;Get the Address of the entry in Process Table for the Current Process.
	mov di, [es:MDA.k_w_currentprocess]
	imul di, K_PROCESS_size
	lea di, [di + MDA.k_list_process]

	; Note that Stack Operations will have to done with care.
	; The Stack Pointer must be valid for the .process_restored location.
	jmp __k_process_save
.process_saved:

	; ------------------------------------------------------------------------
	; Restore the State of the Input Process from its entry in the Process
	; Table.
	; ------------------------------------------------------------------------
.process_restore_and_jump:
	; Get the Address of the entry in Process Table for the Input Process
	mov si, ax					; AX cannot be used in Effective addressing.
	imul si, K_PROCESS_size
	lea si, [si + MDA.k_list_process]

	jmp __k_process_restore
.process_restored:
.process_restore_point:
	; Jumped back. Success
	xor ax, ax
	jmp .end
.failed_invalid_processid:
	mov ax, ERR_INVALID_PROCESS_ID
	jmp .end
.end:
ret

__k_process_save:
	;-------------------------------------------------------------------------
	; Save 32 bit General Purpose registers
	;-------------------------------------------------------------------------
	mov [es:di + K_PROCESS.EAX], eax
	mov [es:di + K_PROCESS.EBX], ebx
	mov [es:di + K_PROCESS.ECX], ecx
	mov [es:di + K_PROCESS.EDX], edx
	mov [es:di + K_PROCESS.ESI], esi
	mov [es:di + K_PROCESS.EDI], edi

	;-------------------------------------------------------------------------
	; Save EFLAGS register
	;-------------------------------------------------------------------------
	push eax
		pushfd
		pop eax
		mov [es:di + K_PROCESS.EFLAGS], eax
	pop eax

	;-------------------------------------------------------------------------
	; Save 16 bit Segment Registers
	;-------------------------------------------------------------------------
	mov [es:di + K_PROCESS.DS], ds
	mov [es:di + K_PROCESS.ES], es
	mov [es:di + K_PROCESS.GS], gs
	mov [es:di + K_PROCESS.FS], fs
	mov [es:di + K_PROCESS.SS], ss

	;------------------------------------------------------------------
	; Save the 16 bit Stack Segment, Stack Pointer and Base Pointer
	; registers into the Process table
	;------------------------------------------------------------------
	mov [es:di + K_PROCESS.SP], sp
	mov [es:di + K_PROCESS.BP], bp

jmp sys_k_process_switch.process_saved

__k_process_restore:
	;-------------------------------------------------------------------------
	; Restore 32 bit General Purpose registers
	;-------------------------------------------------------------------------
	mov eax ,[es:si + K_PROCESS.EAX] 
	mov ebx ,[es:si + K_PROCESS.EBX] 
	mov ecx ,[es:si + K_PROCESS.ECX] 
	mov edx ,[es:si + K_PROCESS.EDX] 
	mov esi ,[es:si + K_PROCESS.ESI] 
	mov edi ,[es:si + K_PROCESS.EDI] 

	;-------------------------------------------------------------------------
	; Restore EFLAGS register
	;-------------------------------------------------------------------------
	push dword [es:si + K_PROCESS.EFLAGS]
	popfd

	;-------------------------------------------------------------------------
	; Restore 16 bit Segment Registers
	;-------------------------------------------------------------------------
	mov ds, [es:si + K_PROCESS.DS]
	mov es, [es:si + K_PROCESS.ES]
	mov gs, [es:si + K_PROCESS.GS]
	mov fs, [es:si + K_PROCESS.FS]
	mov ss, [es:si + K_PROCESS.SS]

	;-------------------------------------------------------------------------
	; Restore 16 bit Stack Pointer and Base Pointer Registers
	;-------------------------------------------------------------------------
	mov bp, [es:di + K_PROCESS.BP]
	mov sp, [es:di + K_PROCESS.SP]

jmp sys_k_process_switch.process_restored

