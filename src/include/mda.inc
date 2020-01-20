; Megha Operating System (MOS) Data Area Maps

%ifndef __MDA_INC_
	%define __MDA_INC_
	
	struc MDA
		
		; -----------------[ Modules ] -----------------
		; We store the addresses of loaded programs/modules in a list at
		; location 0x800:0x1. 0x800:0 is used to store the number of item in 
		; this list.
		.k_w_modules_count:	RESW 1
		.k_list_modules:	RESB KERNEL_MODULE_MAX_COUNT * K_MODULE_size

		; ---------------------[ Despatcher Routines ] ------------------------
		; Despatcher stores routines in this list. It starts from 0x800:21.
		; Each of the item has an offset and segment of the subroutine.
		; A subroutine can be called by putting routine number in BX and
		; calling INT 0x41
		.dsp_lstd_routines: 		RESB FAR_POINTER_size * DS_MAX_ITEMS

		; ---------------------[ Main Messages Queue ] ------------------------
		.k_q_messages:	
			.msg_w_length 			RESW 1
			;|-----|------------|------------|
			;|  0  |     1      |     2      |
			;|-----|------------|------------|
			;| MSG | ARG WORD 0 | ARG WORD 1 |
			;|-----|------------|------------|
			.msg_w_width  			RESW 1
			.msg_w_head 			RESW 1
			.msg_w_tail 			RESW 1
			.msg_lst_buffer 		RESB K_MSG_QUEUE_MAX_ITEMS * K_MSG_Q_ITEM_size

		; ---------------------[ Messsage Notification List ] -----------------
		.k_list_notification:		RESB K_NOTIFICATION_ITEM_size * K_MAX_NOTIFICATION_COUNT

		; ---------------------[ Virtual Terminals ] -----------------
		.k_list_vttys:				RESB K_VIRTUAL_TTY_size * VTTY_COUNT

		; ---------------------[ Processes Memory ] -----------------
		.k_list_process_memory:		RESB (PROCESS_MAX_COUNT + KERNEL_MODULE_MAX_COUNT) * K_MEMORY_ITEM_size

		; ---------------------[ Processes ] -----------------
		.k_list_process:			RESB K_PROCESS_size * PROCESS_MAX_COUNT

		; ---------------------[ Text Mode VGA Driver ] -----------------
		.vga_w_mem_now:				resw 1
		.vga_w_cur_now:				resw 1
		.vga_b_text_attr:			resb 1
	endstruc

%endif
