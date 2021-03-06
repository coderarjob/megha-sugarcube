; Basic Structures and Macros that will be used in the Kernel and also in
; application development.

%ifndef _KERNEL_INC_
	%define _KERNEL_INC_

	MSG_NONE:		EQU 0
	MSG_KB_DOWN:	EQU 1
	MSG_KB_UP:		EQU 2

	ERR_NOTI_FULL:		EQU 1
	ERR_ALLOC_STORAGE_FULL:	EQU 0
	ERR_FREE_SEGMENT_NOT_FOUND:	EQU 1

	ERR_INVALID_PROCESS_ID:	EQU 1

	NOTI_TYPE_APP   : EQU 0
	NOTI_TYPE_SYSTEM: EQU 1

	MEM_ITEM_STATE_UNALLOCATED	: EQU 0
	MEM_ITEM_STATE_USED			: EQU 1
	MEM_ITEM_STATE_FREE			: EQU 2

	PROCESS_TYPE_APPLICATION	: EQU 0
	PROCESS_TYPE_MODULE			: EQU 1

	PROCESS_STATE_KILLED		: EQU 0
	PROCESS_STATE_ACTIVE		: EQU 1
	PROCESS_STATE_DORMANT		: EQU 2

	struc K_MEMORY_ITEM
		.Segment	resw 1
		.Offset		equ .Segment	; Same structure could be used in the
									; Dynamic memory module as well.
		.State		resw 1			; State = Unallocated, Used, Free
		.BlockCount	resw 1			; Number of consecutinve blocks allocated.
		.Size		resw 1
	endstruc


	%macro KM_SCREEN_CELL 1			; KM stands for Kernel macro
		%1.row		resw 1
		%1.collumn  resw 1
	%endmacro

	; Each of the Application programs/Processes, will use one of the virtual
	; TTYs. So one TTY will be used by more than one Process.
	struc K_VIRTUAL_TTY
		KM_SCREEN_CELL .CursorLocation		; Cursor location in row and coll.
		.CursorHeight resw 1				; Cursor Height, 0 means no cursor.
		.Text_Attribute resw 1				; Holds the current text attribute.
		.Text_Dirty_Start_Start resw 1		; Text cell number (Starts from 0)
		.Text_Dirty_Start_End resw 1		; Text cell number (Starts from 0)
		.tty_buffer	resb VTTY_HEIGHT * VTTY_WIDTH * 2
	endstruc

	struc K_MODULE
		.Segment	resw 1			; Segment where the module is loaded.
		.Filename 	resb 12			; Holds the ASCIIZ file name
	endstruc

	struc K_NOTIFICATION_ITEM
		.Message resw 1
		.Type    resw 1
		PROC .Routine
		.PID EQU .Routine.Segment
	endstruc

	struc K_MSG_Q_ITEM
		.Message resw 1
		.Arg0 resw 1
		.Arg1 resw 1
	endstruc

	struc K_PROCESS
		.Segment			resw 1		; Segment where the process is loaded.
		.Filename 			resb 12		; Holds the ASCIIZ file name
		.ProcessID			resw 1		; Process ID
		.ParentProcessID	resw 1		; If 0, this is the first process.
		.LastExitCode		resw 1
		.StackEnd			resw 1
		.ReservedMemoryStart EQU (.StackEnd + 1)
		.TotalSize			 EQU .ReservedMemoryStart + PROCESS_MAX_UNALLOCATED_STORAGE

		; General Purpose registers (32 bit registers are used as application 
		; programs will be build in modern C compilers.
		.EAX 	resw 2						
		.EBX 	resw 2
		.ECX 	resw 2
		.EDX 	resw 2
		.ESI 	resw 2
		.EDI 	resw 2
		.EFLAGS resw 2					; 32 bit Flags register.
		.DS  	resw 1
		.ES  	resw 1
		.GS  	resw 1
		.FS  	resw 1
		.IP  	resw 1
		.CS  	resw 1
		.INVOKE_ADDRESS EQU .IP
		.SS	 	resw 1
		.SP	 	resw 1
		.BP  	resw 1

		.State resw 1					; Process can be in Active/Dormant/
										; Killed (available for new process)
										; mode.
		.TTYID resw 1					; Which TTY is being used.

		; Private Message Queue of the Process.
		; The System Message Queue is used up (dequeued) by the Timer Routine,
		; so is useless for use by the Process. A separate Queue will keep
		; things simple I think.
		.Process_Q:
		.Q_w_length 			RESW 1
		;|-----|------------|------------|
		;|  0  |     1      |     2      |
		;|-----|------------|------------|
		;| MSG | ARG WORD 0 | ARG WORD 1 |
		;|-----|------------|------------|
		.Q_w_width 				RESW 1
		.Q_w_head	 			RESW 1
		.Q_w_tail 				RESW 1
		.Q_lst_buffer	 		RESB PROCESS_MSG_QUEUE_MAX_ITEMS * K_MSG_Q_ITEM_size
	endstruc


%endif
