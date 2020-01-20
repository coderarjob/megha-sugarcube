; Basic Structures and Macros that will be used in the Kernel and also in
; application development.

%ifndef _KERNEL_INC_
	%define _KERNEL_INC_

	MSG_NONE:		EQU 0
	MSG_KB_DOWN:	EQU 1
	MSG_KB_UP:		EQU 2

	ERR_NOTI_FULL:	EQU 10

	NOTI_TYPE_APP   : EQU 0
	NOTI_TYPE_SYSTEM: EQU 1

	MEM_ITEM_STATE_UNALLOCATED	: EQU 0
	MEM_ITEM_STATE_USED			: EQU 1
	MEM_ITEM_STATE_FREE			: EQU 2

	PROCESS_TYPE_APPLICATION	: EQU 0
	PROCESS_TYPE_MODULE			: EQU 1

	PROCESS_STATE_ACTIVE		: EQU 0
	PROCESS_STATE_DORMANT		: EQU 1
	PROCESS_STATE_KILLED		: EQU 2

	struc K_MEMORY_ITEM
		.Segment	resw 1
		.Offset		equ .Segment	; Same structure could be used in the
									; Dynamic memory module as well.
		.State		resw 1			; State = Unallocated, Used, Free
		.BlockCount	resw 1			; Number of consecutinve blocks allocated.
		.Size		resw 1
	endstruc


	%macro KM_SCREEN_CELL 1
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

	struc K_PROCESS
		.Segment	resw 1				; Segment where the process is loaded.
		.Filename 	resb 12				; Holds the ASCIIZ file name
		.ProcessID	resw 1				; Process ID

		; General Purpose registers (32 bit registers are used as application 
		; programs will be build in modern C compilers.
		.EAX resw 2						
		.EBX resw 2
		.ECX resw 2
		.EDX resw 2
		.ESI resw 2
		.EDI resw 2
		.DS  resw 2
		.ES  resw 2
		.GS  resw 2
		.FS  resw 2
		.CS  resw 2
		.IP  resw 2
		.EFLAGS resw 2					; 32 bit Flags register.
		; Process can be in Active/Dormant/Killed modes.
		.State resw 1					
		.TTYID resw 1					; Which TTY is being used.
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

%endif
