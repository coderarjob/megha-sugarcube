; Megha Sugarcube Operating System - Process Routines
; ----------------------------------------------------------------------------
; Version: 01022020
; ----------------------------------------------------------------------------
; Routines here will be responsible for Creating, Switching and Closing process
; (user programs). Even tough Megha is a Single Process OS, it can keep upto 4
; applications in memory (each can target one of the two virtual TTY), but only
; one can be active at anytine.
; ----------------------------------------------------------------------------

__k_process_init:
	pusha
	push es

	mov bx, MDA_SEG
	mov es, bx

	; -----------------------------------------------------------------------
	; Clear the Process Table Memory and the CurrentProcessID Memory in MDA
	; -----------------------------------------------------------------------

	mov [es:MDA.k_w_currentprocess], word 0

	mov di, MDA.k_list_process
	mov al, 0
	mov cx, K_PROCESS_size * PROCESS_MAX_COUNT
	rep stosb
	
	; -------------------------------------------------------------------
	; Clear and Initialize the Process Queue
	; -------------------------------------------------------------------
	mov cx, PROCESS_MAX_COUNT

	; Calculate the address of the Queue of Last entry in the Process Table.
	mov di, cx
	dec di
	imul di, K_PROCESS_size
	lea di, [di + MDA.k_list_process]
.again:
	mov [es:di + K_PROCESS.Q_w_length], word PROCESS_MSG_QUEUE_MAX_ITEMS
	mov [es:di + K_PROCESS.Q_w_width], word K_MSG_Q_ITEM_size
	mov [es:di + K_PROCESS.Q_w_head], word 0
	mov [es:di + K_PROCESS.Q_w_tail], word 0
	sub di, K_PROCESS_size		; Go to the previous one.
	loop .again

	xchg bx, bx

	; -----------------------------------------------------------------------
	; Add System Calls
	; -----------------------------------------------------------------------
	mov bx, DS_ADD_ROUTINE
	mov ax, K_PROCESS_CREATE
	mov cx, cs
	mov dx, sys_k_process_create
	int 0x40
	; -----------------------------------------------------------------------
	mov bx, DS_ADD_ROUTINE
	mov ax, K_PROCESS_SWITCH
	mov cx, cs
	mov dx, sys_k_process_switch
	int 0x40
	; -----------------------------------------------------------------------
	mov bx, DS_ADD_ROUTINE
	mov ax, K_PROCESS_EXIT
	mov cx, cs
	mov dx, sys_k_process_exit
	int 0x40
	; -----------------------------------------------------------------------

	pop es
	popa
ret

; ----------------------------------------------------------------------------
; Exits the Current Process and switches to the parent process. 	     
; If the Parent Process is Zero, then Exit fails and returns an error.
; TODO: Handle Parent process exiting before child process.
; (System Call Wrapper)
; ----------------------------------------------------------------------------
; Input:
;	AX		- Exit Code
; Ouput:
;	None	- Returns if fails, otherwise does not return.
sys_k_process_exit:
	push es
	push bx
	push di

	; Make ES = MDA Segment
	mov bx, MDA_SEG
	mov es, bx

	; Check if the Parent Process ID is not Zero.
	mov bx, [es:MDA.k_w_currentprocess]
	cmp bx, word 0
	je .failed_parent_zero

	; Parent Process ID is not zero

	; Get the Current Process ID and 
	; (a) Deallocate the Storage
	; (b) Deallocate the Process Table Entry for the Process

	; ----------------------------------------------------
	; Get the Current Process ID and 
	; ----------------------------------------------------
	; Process ID starts from 1, so inorder to use it as index into the process
	; table, we decrement it by 1
	dec bx		
	imul bx, K_PROCESS_size
	lea di, [bx + MDA.k_list_process]

	; ----------------------------------------------------
	; (a) Deallocate the Storage
	; ----------------------------------------------------
	mov ax, [es:di + K_PROCESS.Segment]
	call __k_free

	cmp ax, 0
	jne .failed_storeage_deallocation

	; ----------------------------------------------------
	; (b) Deallocate the Process Table Entry for the Process
	; ----------------------------------------------------
	mov [es:di + K_PROCESS.State],word PROCESS_STATE_KILLED

	; ----------------------------------------------------
	; Switch to the Parent Process ID
	; ----------------------------------------------------
	
	; TODO: A way to return the exit code to the switch restore point.
	; TODO: Do the below part properly.

	; Set the Current Process ID to zero. The result will be that the
	; sys_switch call will not save the current state, it will just restore and
	; not save the current process.
	mov [es:MDA.k_w_currentprocess], word 0

	mov ax, [es:di + K_PROCESS.ParentProcessID]
	call __k_process_switch


.failed_parent_zero:
	mov ax, K_ERR_PROCESS_PARENT_ZERO
	call __k_setlasterror
.failed_storeage_deallocation:
.end:
	pop di
	pop bx
	pop es
retf

; ----------------------------------------------------------------------------
; Creates a process for the input executable file. 	     (System Call Wrapper)
; ----------------------------------------------------------------------------
; Input:
; 	AX:CX	- ASCIIZ File name
;	DX		- TTY ID
; Output:
;	AX		- PID (Starts from 1)
;			- 0 is failed
; ----------------------------------------------------------------------------
sys_k_process_create:
	call __k_process_create
retf

; ----------------------------------------------------------------------------
; Creates a process for the input executable file.			   (Local Routine)
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
__k_process_create:

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
	; A. PROCESS ID, STATE AND TTY ID, PARENT PROCESS ID, LastExitCode
	; ------------------------------------------------------------------------
	; Process ID = (PROCESS_MAX_COUNT - CX) + 1   ProcessID starts from 1
	; ------------------------------------------------------------------------
	sub cx, PROCESS_MAX_COUNT		; Does CX - PROCESS_MAX_COUNT
	neg cx							; Does - (CX - PROCESS_MAX_COUNT)
	inc cx							; PROCESS_MAX_COUNT - CX + 1

	mov [es:di + K_PROCESS.ProcessID], cx						; PROCESS ID
	mov [es:di + K_PROCESS.State],word PROCESS_STATE_DORMANT	; STATE

	mov ax, [bp + CREATE_PROCESS_LVARS.TTYID]
	mov [es:di + K_PROCESS.TTYID],ax							; TTY ID

	mov ax, [es:MDA.k_w_currentprocess]					; Parent Process ID
	mov [es:di + K_PROCESS.ParentProcessID], ax				

	; We reset the LastExitCode because it could have residue from previous
	; allocations in the Process Table Entry. Is this important, becuase when
	; any process exits via sys_exit call, it will always set the Exit Code
	; anyways.
	mov [es:di + K_PROCESS.LastExitCode], word 0

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
	xchg bx, bx
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
; (System Call Wrapper)
; ----------------------------------------------------------------------------
sys_k_process_switch:
	call __k_process_switch
retf

; ----------------------------------------------------------------------------
; Jumps to the CS:IP of the process mentioned in the input.
;
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
; 	BX		- 0, Normal Switch, 1, Switch due to exit
; Output:
;	AX		- 0 Success
;			- 1 Process not found.
; ----------------------------------------------------------------------------
__k_process_switch:
	push es
	push si
	push di
	push bx

	mov bx, MDA_SEG
	mov es, bx

	; ------------------------------------------------------------------------
	; Validation of the Input
	; ------------------------------------------------------------------------
	; Check if CurrentProcessID == Input AX. If so we exit.
	cmp word [es:MDA.k_w_currentprocess], ax
	je .failed_invalid_processid

	; Check if input is a valid Process ID 
	; Process ID starts from 1 and goes to PROCESS_MAX_COUNT
	cmp ax, 0
	je .failed_invalid_processid

	cmp ax, PROCESS_MAX_COUNT
	ja .failed_invalid_processid

	; ------------------------------------------------------------------------
	; Process ID is valid
	; ------------------------------------------------------------------------

	; ------------------------------------------------------------------------
	; Save the Current Process State in the Entry for the CurrentProcessID
	; If CurrentProcessID == 0, we skip Saving the Current Process.
	; ------------------------------------------------------------------------
	cmp word [es:MDA.k_w_currentprocess], 0
	je .process_restore_and_jump		; Skip Saving the Current Process

	;Get the Address of the entry in Process Table for the Current Process.
	;xchg bx, bx
	mov di, [es:MDA.k_w_currentprocess]
	dec di						; Process ID Starts from 1, 
								; Index into Process Table = ProcessID - 1
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
	;xchg bx, bx
	dec ax						; Process ID Starts from 1, 
								; Index into Process Table = ProcessID - 1
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
	pop bx
	pop di
	pop si
	pop es
ret

;-------------------------------------------------------------------------
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

	;-------------------------------------------------------------------------
	; Save 16 bit Code Segment and Pointer Registers
	; Note: Stack Segment and Stack Pointer and Base Pointer registers are
	; saved outside this routine in a macro.
	;-------------------------------------------------------------------------
	mov [es:di + K_PROCESS.CS], cs
	mov [es:di + K_PROCESS.IP], word __k_process_switch.process_restore_point

	;-------------------------------------------------------------------------
	; Mark the Current Process as Dormant 
	;-------------------------------------------------------------------------
	mov [es:di + K_PROCESS.State], word PROCESS_STATE_DORMANT

jmp __k_process_switch.process_saved
;-------------------------------------------------------------------------

;-------------------------------------------------------------------------
__k_process_restore:
	;-------------------------------------------------------------------------
	; Restore 32 bit General Purpose registers (Except ESI)
	;-------------------------------------------------------------------------
	mov eax ,[es:si + K_PROCESS.EAX] 
	mov ebx ,[es:si + K_PROCESS.EBX] 
	mov ecx ,[es:si + K_PROCESS.ECX] 
	mov edx ,[es:si + K_PROCESS.EDX] 
	mov edi ,[es:si + K_PROCESS.EDI] 

	;-------------------------------------------------------------------------
	; Restore EFLAGS register
	;-------------------------------------------------------------------------
	push dword [es:si + K_PROCESS.EFLAGS]
	popfd

	;-------------------------------------------------------------------------
	; Restore 16 bit Segment Registers (Except ES)
	;-------------------------------------------------------------------------
	mov ds, [es:si + K_PROCESS.DS]
	mov gs, [es:si + K_PROCESS.GS]
	mov fs, [es:si + K_PROCESS.FS]
	mov ss, [es:si + K_PROCESS.SS]

	;-------------------------------------------------------------------------
	; Restore 16 bit Stack Pointer and Base Pointer Registers
	;-------------------------------------------------------------------------
	mov bp, [es:si + K_PROCESS.BP]
	mov sp, [es:si + K_PROCESS.SP]

	;-------------------------------------------------------------------------
	; Mark the Current Process as Active set the k_w_currentprocess.
	;-------------------------------------------------------------------------
	mov [es:si + K_PROCESS.State],word PROCESS_STATE_ACTIVE

	; Set the Current ProcessID variable in MDA
	push ax
		mov ax, [es:si + K_PROCESS.ProcessID]
		mov [es:MDA.k_w_currentprocess], ax
	pop ax
	
	;-------------------------------------------------------------------------
	; We store the Return address in a local memory before we restore
	; ESI and ES.
	;-------------------------------------------------------------------------

	push eax
		mov eax, [es:si + K_PROCESS.INVOKE_ADDRESS]
		mov [cs:.jump_loc], eax
	pop eax

	;-------------------------------------------------------------------------
	; Restore the ESI, ES registers and jump to the 
	; CS:IP thus restoring them.
	;-------------------------------------------------------------------------
	push word [es:si + K_PROCESS.ES]
		mov esi ,[es:si + K_PROCESS.ESI] 
	pop es

	xchg bx, bx
	jmp far [cs:.jump_loc]
;-------------------------------------------------------------------------
.jump_loc: resw 2
;-------------------------------------------------------------------------
