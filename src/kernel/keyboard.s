; Megha Operating System Sugarcube 
; - Keyboard driver
; ----------------------------------------------------------------------------
;
; Driver module that overrides the bios Keyboard interrupt routine. Everytime a
; key on the keyboard is pressed, it will call a routine in this module. The
; driver will keep the pressed key into a queue that can be read by other
; applications using system calls also defined here.

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
;    interpreter, when Ctrl+C is pressed.

; ----------------------------------------------------------------------------
; Build Version: 0.1 (211019)
; Initial Dated: 21 Oct 2019
; ----------------------------------------------------------------------------

; Every module on MOS starts at location 0x64. The below 100 bytes are for
; future use.

	ORG 0x64
_init:
	retf
