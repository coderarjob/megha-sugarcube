; Megha Operating System Sugarcube 
; - Keyboard driver
; ----------------------------------------------------------------------------
;
; Driver module that overrides the bios Keyboard interrupt routine. Everytime a
; key on the keyboard is pressed or released, the interrupt routine will be
; called. The driver will put approproate values into the Message Queue.

; ----------------------------------------------------------------------------
; Functions:
; ----------------------------------------------------------------------------
; 1. System independent KeyCode. This would help decouple the ScanCode
;    (which the keyboard manufacturer provided) from the rest of the Operating
;     System.
; 2. Put into the queue every key press and release. If the previous key added 
;    to the queue, is the one that is pressed now, then we skip the present key
;    press. We do not add repeating keys into the queue.

;   	|---------|---------|-------------|---------|
;       |  Byte 0 | Byte 1  | Byte 2 	  | Byte 3  |
;   	|---------|---------|-------------|---------|
;		|         |         |Shift (1) 	  |         |
;		|         |         |ALT (1)      |         |
;		|Key Code |Scan code|CTRL(1)      | Unused  |
;		|   8     |   8     |PRESSED(1)   |    8    |
;		|         |         |REPEAT(1)    |         |
;		|         |         |EXTENDED (1) |         |
;       |         |         |NUM(1)       |         |
;       |         |         |CAPS(1)      |         |
;		|---------|---------|-------------|---------|
; 3. System reset on CTRL+ALT+DEL
; 4. Call a kernel function to kill the current process and start the
;    interpreter, when Ctrl+C is pressed. (Not implemented here)

; ----------------------------------------------------------------------------
; Build Version: 0.1 (04012020)
; Initial Dated: 4th Jan 2020
; ----------------------------------------------------------------------------

; Every module on MOS starts at location 0x10. The below 16 bytes are for
; future use.

	ORG 0x10
_init:
	; Install the Keyboard Interrupt module
	push bx
	push es
		xor bx, bx
		mov es, bx
		cli
			mov [es:9*4],word kb_interrupt
			mov [es:9*4+2],cs
		sti
	pop es
	pop bx
	retf

kb_interrupt:
	pusha
	push ds
		
		push cs
		pop ds

		; Read the Scan code from the keyboard
		in al, 0x60				

		; ----------------------------------------
		; The return code could also be 0xFA or 0xFE
		; We ignore them for now.
		; ----------------------------------------
		cmp al, 0xFA
		je .endb

		cmp al, 0xFE
		je .endb

		; ----------------------------------------
		; Check if Extended key
		; ----------------------------------------
		cmp al, 0xE0
		jne .n1

		or [key.flags], byte EXTENDED	; SET EXTENDED FLAG
		jmp .extended_get_next_key 		; We do not add 0xE0 to the output and
										; A second interrupt will have the scan
										; code of the Extended key.

.n1:
		; ----------------------------------------
		; We Save the Scan code
		; ----------------------------------------
		mov [key.scancode], al

		; ----------------------------------------
		; Check is key is released or pressed
		; We set the PRESSED flag and get the MAKE Code from 
		; the currently available BREAK code, by 
		; ANDING by 0x7F or ~0x80
		; ----------------------------------------
		test al, 0x80		; ANDing in order to check for break codes.
		jz .n1a				; Not a break code, continue

		and al, ~0x80
		and [key.flags], byte ~PRESSED	; CLEAR PRESSED Flag
		jmp .n2
.n1a:
		or [key.flags], byte PRESSED	; SET PRESSED Flag
.n2:
		; ----------------------------------------
		; We save the Key code
		; ----------------------------------------
		xor bx, bx
		mov bl, al
		
		test [key.flags],byte EXTENDED
		jz .resolve

		; We have an Extended key, so we do a little math to resolve a
		; normalized scancode. 
		; Note: This calculation will change is the we start receiving
		; different scancodes, for example when attaching a new keyboard.

		; The calculation normalizes scan codes for the Effective keys and
		; makes the effective key with the smallest scan code start from 0.
		; The smallest scan code for any effective key (in my current keyboard)
		; is 0x1C or 28.

		; The maximum scan code generated from my computer keyboard is 0x5B or
		; 91 in decimal. So the Scan codes for these Extended keys must be after
		; 91. I have chosen that the effective scan code for the first Extended
		; key should be 100.

		; Normalized position (zero based) = Scan Code - 0x1C
		; Position in the keycodes array = Normalized position + 100

		add bx, 100 - 0x1C
.resolve:
		mov ah, [key_codes + bx]
		mov [key.keycode], ah

		; ----------------------------------------
		; Check for SHIFT key press
		; ----------------------------------------

		; --- Check for Left Shift Key
		cmp ah, key_codes.LSHIFT
		je .n2a					; It is Left Shift Key

		; --- Check for Right Shift key
		cmp ah, key_codes.RSHIFT
		jne .n3					; Neither of the SHIFT keys
.n2a:
		; --- Check if pressed or released
		test [key.flags], byte PRESSED	
		jz .n2_rel			; SHIFT key is being released not pressed.

		; SHIFT key is being PRESSED.
		or [key.flags], byte SHIFT		; SET SHIFT Flag
		jmp .end
.n2_rel:
		and [key.flags], byte ~SHIFT	; CLEAR SHIFT Flag
		jmp .end
.n3:
		; ----------------------------------------
		; Check for CONTROL key press
		; ----------------------------------------
		
		cmp ah, key_codes.LCTRL
		je .n3_ctrl			; It is the Left CONTROL key

		cmp ah, key_codes.RCTRL
		jne .n4				; Not any of the CONTROL Keys.

.n3_ctrl:
		; --- Check if key is being pressed or released.
		test [key.flags], byte PRESSED	
		jz .n3_rel				; CONTROL key is being released 

		or [key.flags], byte CTRL	; SET CONTROL Flag
		jmp .end
.n3_rel:
		and [key.flags], byte ~CTRL	; CLEAR CONTROL Flag
		jmp .end

.n4:
		; ----------------------------------------
		; Check for ALT key press
		; ----------------------------------------
		
		cmp ah, key_codes.LALT
		je .n4_alt			; It is the Left ALT key

		cmp ah, key_codes.RALT
		jne .n5				; Not any of the ALT Keys, Continue

.n4_alt:
		; --- Check if key is being pressed or released.
		test [key.flags], byte PRESSED	
		jz .n4_rel			; Key is being released 

		or [key.flags], byte ALT		; SET ALT Flag
		jmp .end
.n4_rel:
		and [key.flags], byte ~ALT		; CLEAR ALT Flag
		jmp .end

.n5:
		; ----------------------------------------
		; Check for CAPS LOCK key press
		; ----------------------------------------

		cmp ah, key_codes.CAPS
		jne .n6

		xor bx, bx
		mov bl, [key.caps_state]
		imul bx, 2
		jmp [.jtable_caps + bx]

.caps_case0:
		test [key.flags], byte PRESSED
		jz .end

		; --- key is pressed, we engage the CAPS Lock and LEDs
		mov [key.caps_state], byte 1
		or [key.flags], byte CAPS
		or [key.leds], byte CAPS_LED
		jmp .end_led_modified
.caps_case1:
		test [key.flags], byte PRESSED
		jnz .end
		
		; --- Key is released, we move the state
		mov [key.caps_state], byte 2
		jmp .end
.caps_case2:
		test [key.flags], byte PRESSED
		jz .end

		; --- key is pressed, we de-engage the CAPS Lock and LEDs
		mov [key.caps_state], byte 3
		and [key.flags], byte ~CAPS
		and [key.leds], byte ~CAPS_LED
		jmp .end_led_modified
.caps_case3:
		test [key.flags], byte PRESSED
		jnz .end
		
		; --- Key is released, we move the state
		mov [key.caps_state], byte 0
		jmp .end
.n6:
		; ----------------------------------------
		; Check for NUM LOCK key press
		; ----------------------------------------

		cmp ah, key_codes.NUM
		jne .n7							; Not the NUM Lock

		xor bx, bx
		mov bl, [key.nums_state]
		imul bx, 2
		jmp [.jtable_nums + bx]

.nums_case0:
		test [key.flags], byte PRESSED
		jz .end

		; --- key is pressed, we engage the CAPS Lock and LEDs
		mov [key.nums_state], byte 1
		or [key.flags], byte NUM
		or [key.leds], byte NUM_LED
		jmp .end_led_modified
.nums_case1:
		test [key.flags], byte PRESSED
		jnz .end
		
		; --- Key is released, we move the state
		mov [key.nums_state], byte 2
		jmp .end
.nums_case2:
		test [key.flags], byte PRESSED
		jz .end

		; --- key is pressed, we de-engage the CAPS Lock and LEDs
		mov [key.nums_state], byte 3
		and [key.flags], byte ~NUM
		and [key.leds], byte ~NUM_LED
		jmp .end_led_modified
.nums_case3:
		test [key.flags], byte PRESSED
		jnz .end
		
		; --- Key is released, we move the state
		mov [key.nums_state], byte 0
		jmp .end
.n7:
		; ----------------------------------------
		; Check for SCROLL LOCK key press
		; ----------------------------------------

		cmp ah, key_codes.SCROLL_LOCK
		jne .end							; Not SCROLL Lock

		mov bx, [key.scroll_state]
		imul bx, 2
		jmp [.jtable_scroll + bx]

.scroll_case0:
		test [key.flags], byte PRESSED
		jz .end								; LED update is not needed.

		; --- key is pressed, we engage the SCROLL Lock and LEDs
		mov [key.scroll_state], byte 1
		or [key.flags], byte SCROLL_LOCK
		or [key.leds], byte SCROLL_LED
		jmp .end_led_modified				; Update LEDs
.scroll_case1:
		test [key.flags], byte PRESSED
		jnz .end
		
		; --- Key is released, we move the state
		mov [key.scroll_state], byte 2
		jmp .end
.scroll_case2:
		test [key.flags], byte PRESSED
		jz .end

		; --- key is pressed, we de-engage the SCROLL Lock and LEDs
		mov [key.scroll_state], byte 3
		and [key.flags], byte ~SCROLL_LOCK
		and [key.leds], byte ~SCROLL_LED
		jmp .end_led_modified
.scroll_case3:
		test [key.flags], byte PRESSED
		jnz .end
		
		; --- Key is released, we move the state
		mov [key.scroll_state], byte 0
		jmp .end
.extended_get_next_key:
		; Note that we do not want to add 0xE0 into the queue, so we skip the
		; below instruction
		jmp .endb

.end_led_modified:
		; Set the LEDS
		call wait_kbd
		mov al, 0xED
		out 0x60, al

		call wait_kbd
		mov al, [key.leds]
		out 0x60, al
.end:
		; Adds the ScanCode, KeyCode and Flags in the System Message Queue.

		; Message for Key Down and Key Up are Different.
		; We determine that based on the PRESSED bit in the flags.

		mov ax, MSG_KB_DOWN

		test [key.flags], byte PRESSED
		jnz .cont				; PRESSED so continue
	
		mov ax, MSG_KB_UP		; NOT PRESSED, therefore MSG_KB_UP
.cont:
		mov bx, K_IO_ADD_MESSAGE
		mov cx, [key.flags]			; LOW = FLAGS, HIGH = SCANCODE
		mov dx, [key.keycode]		; LOW = KEYCODE
		xor dh, dh
		int 0x40

		; CLEAR EXTENDED Flag
		; EXTENDED Flag is just an indication that the current keycode is part
		; of an Extended keybord or not. It is not marked continously through
		; multiple keypresses like the SHIFT or CONTROL key.
		and [key.flags], byte ~EXTENDED
.endb:
		; send a EOI to PIC
		mov al, 0x20
		out 0x20, al
	pop ds
	popa
	iret

.jtable_nums: dw .nums_case0, .nums_case1, .nums_case2, .nums_case3
.jtable_caps: dw .caps_case0, .caps_case1, .caps_case2, .caps_case3
.jtable_scroll: dw .scroll_case0, .scroll_case1, .scroll_case2, .scroll_case3

wait_kbd:
	push ax
.check:
		in al, 0x64
		test al, 0x2		; Check PS/2 input buffer. If full we check again.
		jnz .check
	pop ax
	ret
; ==========================================================

key:
; |---------------- Flags Bit Map --------------------|
; |    7  |    6   |    5     | 4 | 3  |  2  | 1  | 0 |
; |-------|--------|----------|---|----|-----|----|---|
; |Pressed|Extended|ScrollLock|ALT|CTRL|SHIFT|CAPS|NUM|
; |-------|--------|----------|---|----|-----|----|---|
	.flags db 0			
		NUM: EQU 0x1
		CAPS: EQU 0x2
		SHIFT: EQU 0x4
		CTRL: EQU 0x8
		ALT: EQU 0x10
		SCROLL_LOCK: EQU 0x20
		EXTENDED: EQU 0x40
		PRESSED: EQU 0x80
	.scancode db 0
	.keycode db 0
	.ascii db 0
; ==========================================================
; For use only by driver
; ==========================================================
	.leds db 0
		SCROLL_LED: EQU 0x1
		NUM_LED: EQU 0x2
		CAPS_LED: EQU 0x4
	.caps_state db 0
	.nums_state db 0
	.scroll_state db 0
	; -----------------------------------

; -----------------------------------------------------------------
; Scan code to Key code map
; Legend: 
;		  Numbers      : 0		   --> 0xB
;						 1 - 9     --> 0x2 0xA
;		  Num KeyPad   : 0 - 9     --> 0xE to 0x17
;         Space        :           --> 0x1A
;		  Function keys: F1 to F12 --> 0x2D to 0x38
;         Characters   : A - Z     --> 0x41 to 0x5A
;		  Arrow Keys   : Down      --> 0x5F
;					   : Left      --> 0x5C
;					   : Right     --> 0x5D
;					   : Up        --> 0x40
;		  Delete Key   :           --> 0x62
;         Win          :           --> 0x63
;         Menu         :           --> 0x65
;         Enter        : Normal    --> 0x18
;                      : NumPad    --> 0x64
; Extended Keys:
;		  Because Extended Keys can have same Scan Codes as 
;		  another key in the keyboard (but some are unique)
;			|===========|==========|
;		  	| Scan code |   Key    |
;			|===========|==========|
;			|   0x5B    |  Windows |
;			|-----------|----------|
;			|   0x5D    |  Menu    |
;			|-----------|----------|
;			|   0x1D	| L Control|
;			|-----------|----------|
;			|   0x1D    | R Control|
;			|===========|==========|
;
; 		  In order to use the existing mapping table (below), We Shift the 
;		  scan codes of Extended keys so that the modified scan codes, all 
;		  start at location 0x64 (the last scan code ended at 0x58 (F12)).
;
;		  0x64 was chosen as it is larger than than the largest scan code, 
;		  there is no other reason. 
;
;		  This means that the Extended Key with the lowest Scan code starts at
;		  location 0x64. (0x1C is the lowest)
;
;		  Modified Scan code: [Scan Code (byte 2)] + 100 - 0x1C
;		  ------------------
;
;		  Drawbacks:
;		  ----------
;		  This method however does nothing to make the extended keys closer, so
;		  that less space is wasted.
;		 
; -----------------------------------------------------------------
key_codes:
; The below contants are used to identify if LEFT SHIFT, CAPS, ALT keys are
; pressed. Previously we used to perform this identification using Scan codes,
; but that will make them hardwired to the keyboard hardware. 
; To make the below contants independent of the keyboard hardware, 
; we assign *Key Codes* to them.

	;-------------|-----------|
	; Constant    | Key Codes |
	;-------------|-----------|
	.LSHIFT: 		EQU 0x1C 
	.RSHIFT: 		EQU 0x23
	.CAPS: 	 		EQU 0x26	
	.LALT: 	 		EQU 0x25	
	.RALT: 	 		EQU 0x3E
	.LCTRL:			EQU 0x19	
	.RCTRL: 	 	EQU 0x3C	
	.NUM:			EQU 0x3A	
	.SCROLL_LOCK: 	EQU 0x3B	
	;-------------|----------|

	db 0,1,2,3,4,5,6,7									; 0x7
	db 8, 9,0xA,0xB,0x1D,0x28,0xC			 			; 0xE
	db 0xD, 'Q', 'W', 'E', 'R', 'T'						; 0x14
	db 'Y', 'U', 'I', 'O', 'P', 0x29					; 0x1A
	db 0x2B,0x18, 0x19,'A','S','D','F'					; 0x21
	db 'G','H','J','K','L',0x27, 0x1B, 0x2C				; 0x29
	db 0x1C, 0x2A, 'Z', 'X', 'C', 'V', 'B'				; 0x30
	db 'N', 'M', 0x20, 0x21, 0x22, 0x23, 0x24			; 0x37
	db 0x25, 0x1A, 0x26, 0x2D, 0x2E, 0x2F				; 0x3D
	db 0x30, 0x31, 0x32, 0x33, 0x34, 0x35				; 0x43
	db 0x36, 0x3A, 0x3B, 0x15, 0x16, 0x17, 0x1F			; 0x4A
	db 0x12, 0x13, 0x14, 0x1E, 0xF, 0x10, 0x11, 0xE     ; 0x52
	db 0x39,0,0,0,0x37,0x38,0,0,0,0,0,0,0,0,0,0,0x00	; 0x63
	;   -----------------------------------------------
	; [ Extended keys: Modified Scan codes to Key Codes ]
	;   -----------------------------------------------
	db 0x64, 0x3C,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 0x78
	db 0,0,0,0,0,0,0x3D, 0x3E, 0,0,0,0,0,0,0,0,0,0		; 0x8A
	db 0,0,0,0,0x3F,0x40,0x5B, 0,0x5C,0,0x5D,0,0x5E		; 0x97
	db 0x5F, 0x60, 0x61, 0x62, 0,0,0,0,0,0,0,0x63,0		; 0xA4
	db 0x65												; 0xA5

modifier_maps:

	NONE:	 	EQU 0	; Keys that never change its meaning or function.
	M_SHIFT:	EQU 1	; Keys that change behaviour when SHIFT is pressed.
	M_SCAPS:	EQU 2	; Keys that change behaviour depending on both SHIFT and CAPS LOCK.
	M_CAPS:		EQU 3	; Keys that change behaviour depending on CAPS LOCK.
	M_NUM:		EQU 4	; Keys that change behaviour depending on NUMS LOCK.

		;0/8  1/9   2/A   3/B   4/C   5/D   6/E   7/F 
db		NONE, NONE, M_SHIFT,M_SHIFT,M_SHIFT,M_SHIFT,M_SHIFT,M_SHIFT		; 0x7
db		M_SHIFT,M_SHIFT,M_SHIFT,M_SHIFT,NONE, NONE, M_NUM,  M_NUM		; 0xF
db		M_NUM,  M_NUM,  M_NUM,  M_NUM,  M_NUM,  M_NUM,  M_NUM,  M_NUM	; 0x17
db		NONE, NONE, NONE,M_SHIFT, NONE, M_SHIFT,NONE, NONE				; 0x1F
db		M_SHIFT,M_SHIFT,M_SHIFT,NONE, NONE, NONE, NONE, M_SHIFT			; 0x27
db		M_SHIFT,M_SHIFT,M_SHIFT,M_SHIFT,M_SHIFT,NONE, NONE, NONE		; 0x2F
db		NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE					; 0x37
db		NONE, NONE, NONE, NONE, NONE, NONE, NONE, NONE					; 0x3F 
db		NONE,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS	; 0x47
db		M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS ; 0x4F
db		M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS,M_SCAPS ; 0x57
db		M_SCAPS,M_SCAPS,M_SCAPS, NONE, NONE, NONE, NONE, NONE			; 0x5F
db		NONE, NONE, NONE, NONE, NONE, NONE								; 0x65

%include "../include/mos.inc"
