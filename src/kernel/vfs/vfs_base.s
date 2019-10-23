; Megha Virtual File System Basic routines.
; This file contains the basic routines of a VFS module.
; --------
; Routines:
; --------
;   * void register_fs(struct filesystem* newfs);
;   * void mount(struct file *source, char *fsname, char *drive);
;   * int unmount(char *drive);
;
; --------
; Note:
; --------
; The VFS.S is the main file that includes this file. 
;
;
; ============ [ CODE BLOCK ] =========
;
; Adds a new File system into the file systems list.
; Signature: 
;		void register_fs(struct filesystem* newfs);
; Input:
;	   DS:AX - Far pointer to a 'filesystem' structure.
; Output:
;		BX - 0, if successful, 1 if failure
vfs_register_fs:
	push ax
	push cx
	push dx
	push si
	push di
	push es

	; Set ES to be the current code segmnet
	push cs
	pop es

	; Store AX (far pointer to filesystem strucure) to DX
	mov dx, ax

	mov bx, [cs:fslist_count]
	cmp bx, byte MAX_REGISTERED_FILESYSTEM 
	je .toomuch

	; Here on DS points to the data segment of the caler, and ES to the
	; current module.
	; -----------------------------------------------------------------
	; 1. Check if same file system exists in the list of registered file
	; systems.
	; -----------------------------------------------------------------
	; SI -> Location of the File system name in the input filesystem
	; structure.
	mov bx, dx
	lea si, [bx + filesystem.fsname]		; File sytem name: DS:SI

	; Returns the pointer to the file system which matches name with the
	; string in DS:SI. The match is case in-sensitive.
	; ES MUST POINT TO THE DATA SEGMENT OF THIS MODULE.
	call get_filesystem_from_name			
	cmp bx, 0
	jne .fs_found
	; -----------------------------------------------------------------

.copy_fs_to_local:
	; -----------------------------------------------------------------
	; 2. Copy the filesystem from DS:DX (caller location) to ES:DI (Local)
	; -----------------------------------------------------------------
	; a. Get the next location in the local filesystem array
	mov bx, [es:fslist_count]
	imul bx, filesystem_size
	lea di, [es:fslist + bx]

	; b. We make SI point to the source offset
	mov si, dx

	; c. Source = DS:SI, Destination = ES:DI
	mov cx, filesystem_size
	rep movsb
	; -----------------------------------------------------------------
.done:
	; increment fs count
	inc byte [es:fslist_count]

	; Return as success
	mov bx, 0
	jmp .end

.fs_found:
	mov bx, 2
	jmp .end
.toomuch:
	mov bx, 1
.end:
	; Restore the registers
	pop es
	pop di
	pop si
	pop dx
	pop cx
	pop ax

	; A far jump is required to return to the despatcher.
	ret

; Compares source with the destination anciiz string
; Input:
;		DS:SI - Source string
;		ES:DI - Destination string
;		BX    - 1 if compare binary or 0 if compare string.
; Output:
;		BS - 0, if strings match, otherwise 1
_str_is_equal:
	push ax
	push dx
	push cx
	push si
	push di

	push bx
		; Get Source length
		call _strlen			; Get the length of string at DS:SI
		mov cx, bx

		; Get Destination length
		push ds
		push si

			; make DS = ES (ES = destination string data segment)
			push es
			pop ds
			
			; Now that ES:DI, has become DS:SI, we can call _strlen
			mov si, di
			call _strlen	
			mov dx, bx
		pop si
		pop ds
	pop bx

	; Compare DX (Destination string length), CX (Source string length)
	cmp dx, cx
	jb .continue

	; DX > CX, so we make CX = DX (the maximum count)
	mov cx, dx

	; Check if we need to do a case sensitive compare or a insensitive one.
.continue:
	cmp bx, 0
	je .case_insensitive_match

.case_sensitive_match:
	rep cmpsb
	cmp cx, 0
	je .match
	jne .notmatch

.case_insensitive_match:
	mov bx,2
.readsource:
	mov al, [ds:si]
	jmp .tolower
.readdestination:
	mov ah, al
	mov al, [es:di]
.tolower:
	; Check to see AL >= 'A' and AL <= 'Z'
	; If AL is in upper case then makes it lower case
	cmp al, 'A'
	jb .not_upper
	
	cmp al, 'Z'
	ja .not_upper

	; Make AL lower case 
	; if AL = A, then AL + 'a' - 'A' = 'a'
	add al, 'a' - 'A'
.not_upper:
	dec bx
	cmp bx, 1
	je .readdestination

.compare:
	cmp al, ah
	jne .notmatch

	inc si
	inc di
	loop .case_insensitive_match

.match:
	mov bx, 0
	jmp .end
.notmatch:
	mov bx, 1
.end:
	pop di
	pop si
	pop cx
	pop dx
	pop ax
	ret

; Calculates string length
; Input:
;		DS:SI - Pointer to a asciiz string
; Output:
;		BX - Length of the string
_strlen:
	push si
	push ax
		xor bx, bx
.again:
		lodsb
		cmp al, 0
		je .end

		inc bx
		jmp .again
.end:
	pop ax
	pop si
	ret

; Get near pointer to the filesystem structure which matches the supplied name.
; Note: 
; This function will most likely be called from the environment where DS points
; to the data segment of the caller module and ES points to the one of this
; module. Therefore, the file system array is available with the ES segment not
; with the DS segment.
; Input:
;		DS:SI - Contains the name of the file system.
; Output:
;		ES:BX - Location of the file system structure for the name supplied, if
; 				no match is found, BX is set to 0.
get_filesystem_from_name:
	push dx
	push cx
	push di
	push si
	
	; Set ES to be the current code segmnet
	push cs
	pop es

	; Number of file systems already installed.
	; If there is no registered file system, we skip and return false.
	mov cx, [es:fslist_count]						
	cmp cx, 0
	je .notfound

	; Points to the next offset in the fslist array.
	xor bx, bx
.next_fs:
	lea di, [es:fslist + bx + filesystem.fsname]
	push bx
		; Match as per set in the VFS.INC file. I think it is set to 'case
		; in-sensitive' checking.
		mov bx, STRING_MATCH
		call _str_is_equal	; matches string (case insensitive) from DS:SI with
							; ES:DI
		mov dx, bx
	pop bx
	cmp dx, 0
	je .found

	add bx, filesystem_size
	loop .next_fs

.notfound:
	mov bx, 0
	jmp .end
.found:
	mov bx, di
.end:
	pop si
	pop di
	pop cx
	pop dx
	ret
		
; Creates a mount_point structure and adds it to the list of mount points.
; Signature: 
; 		void mount(struct file *source, char *fsname, char *drive);
; Input:
;		DS:AX - Pointer to the file structure
;		DS:CX - File system name. This must be one of the registered file
;				systems. String is case insensitive.
;		DS:DX - Holds a pointer to the drive name. Upto 10 characters, 
;				including the null terminator.
; Output:
;		BX - 0 if success
;			 1 if file system do not exist
;			 2 if drive is already registered.
;
; TODO: Signature should be void mount (char *drive, char *filename, char
;										*fsname, char *drive)
; TODO: Mount must open the file and call a filesystem method that will read a 
;		portion of the file header (or something esle) and keep it in the file
;		structure. 
;		Is this a good idea to store such header details in the file structure??
vfs_mount:
	push bp
	mov bp, sp

struc mount_args
	.file_ptr resw 1
	.fsname_ptr resw 1
	.drive_name_ptr resw 1
endstruc

	sub sp, mount_args_size

	mov [bp - mount_args.file_ptr], ax
	mov [bp - mount_args.fsname_ptr], cx
	mov [bp - mount_args.drive_name_ptr], dx

	push di
	push si
	push cx
	push dx
	push es
	
	; Set ES to be the current code segmnet
	push cs
	pop es

	; At this point DS points to the data segment of the caller and ES to
	; the data segment of the current module.
	
	; --------------------------------------------------------------------
	; 1. Search if a file system with the name in DS:CX exists, in
	; ES:fslist.
	; --------------------------------------------------------------------
	; get_filesystem_from_name searches CS:fslist with the filesystem name
	; in DS:SI. Returns the pointer to the respective file system structure
	; in ES:BX.
	mov si, [bp - mount_args.fsname_ptr]
	call get_filesystem_from_name
	cmp bx, 0
	je .filesystem_not_found
	mov dx, bx				; offset where the filesystem item is located
							; in the fslist array.
	; --------------------------------------------------------------------
	; 2. Check if drive with name in DS:DX, already exists in the 
	; ES:mountlist array.
	; --------------------------------------------------------------------
	mov si, [bp - mount_args.drive_name_ptr]
	call _get_mount_point_from_drive
	cmp bx, 0
	jne .mount_point_exists

	; --------------------------------------------------------------------
	; Copy the values in the next in the mountlist array.
	; --------------------------------------------------------------------
	mov bx, [es:mountlist_count]
	imul bx, mount_point_size

	; a. Copy filesystem pointer (ES:DX)
	lea di, [es:mountlist + bx + mount_point.filesystem]
	mov [es:di], word dx
	mov [es:di+2],word es

	; b. Copy source file pointer (DS:AX)
	lea di, [es:mountlist + bx + mount_point.source_file]
	mov dx, word [bp - mount_args.file_ptr]
	mov [es:di],dx 
	mov [es:di+2],word ds

	; c. Copy the drive name (DS:CX)
	mov si, [bp - mount_args.drive_name_ptr]
	lea di, [es:mountlist + bx + mount_point.mount_name]
	mov cx, MAX_DRIVE_NAME_LENGHT
	rep movsb

	inc word [es:mountlist_count]
	mov bx, 0
	jmp .end
.filesystem_not_found:
	mov bx, 1
	jmp .end
.mount_point_exists:
	mov bx, 2
.end:
	pop es
	pop dx
	pop cx
	pop si
	pop di
	leave	; sp = bp and pop bp 
	ret

; Executing this routine will remove the mount point from the local mountlist
; array and decrement the mount point count.
; Signature:
; 		int unmount(char *drive);
; Input:
;		DS:AX - Points to the name of drive to unmount
; Output:
;		BX    - 0 is successful, 
;			  - 1 if drive do not exist
vfs_umount:
	push ax
	push si
	push di
	push dx
	push cx
	push es
	push ds

		; -----------------------------------------------------------------
		; Make ES = CS
		; -----------------------------------------------------------------
		push cs
		pop es

		; -----------------------------------------------------------------
		; 1. Get the mount point location 
		; Returns far pointer in ES:BX to mount_point structure after searching 
		; for drive name in CS:mountlist_count with drive name in DS:SI
		; -----------------------------------------------------------------
		mov si, ax
		call _get_mount_point_from_drive

		cmp bx, 0
		je .not_found
		; -----------------------------------------------------------------
		; 2. If found we shift every mount point array item one item to the
		;    left to fill the gap from the removed mount point.
		; -----------------------------------------------------------------

		; We no longer need to access caller data segment so we make DS = ES =
		; CS of this module.
		push cs
		pop ds

		; DX = End address of the mountlist array
		; This is used to check, if we have passed the last item.
		push bx
			mov bx, [mountlist_count]
			imul bx, mount_point_size
			lea dx, [mountlist + bx]
		pop bx
	
		; array item to be removed. 
		mov di, bx

		; next array item to the one getting removed.
		lea si, [bx + mount_point_size]
.next:
		cmp si, dx
		jae	.last_item_to_remove

	; TODO: The below CX assignment and rep may not be required. Just one movsb
	; is all that may be is required. But REP may be faster.
	; We copy this much byte for each item.
		mov cx, mount_point_size
		rep movsb	; Copies one byte DS:SI to ES:DI and increments SI and DI

		jmp .next

.last_item_to_remove:
		dec word [mountlist_count]
		mov bx, 0
		jmp .end
.not_found:
	mov bx, 1
.end:
	pop ds
	pop es
	pop cx
	pop dx
	pop di
	pop si
	pop ax
	ret

; Returns a far pointer to a 'mount_point' structure that matches the specified
; name.
; Signature:
;	mount_point *get_mount_point(char *drive);
; Input:
;		DS:SI - Name of the drive
; Output:
;		ES:BX  - Far Pointer to the mount_point structure in the 'mountlist'
;				 array which is part of this module.
;				 If not found, then ES and BX is set to 0
_get_mount_point_from_drive:
	push dx
	push cx
	push di
	push si

	; Make ES = CS
	push cs
	pop es

	; If there is no registered mount points, we skip and return false.
	mov cx, [es:mountlist_count]
	cmp cx, 0
	je .notfound

	; Points to the next offset in the mountlist array.
	xor bx, bx
.next_mp:
	lea di, [es:mountlist + bx + mount_point.mount_name]
	push bx
		; Match as per set in the VFS.INC file. I think it is set to 'case
		; in-sensitive' checking.
		mov bx, STRING_MATCH
		call _str_is_equal	; matches string (case insensitive) from DS:SI with
							; ES:DI
		mov dx, bx
	pop bx
	cmp dx, 0
	je .found

	add bx, mount_point_size
	loop .next_mp

.notfound:
	mov bx, 0
	mov es, bx
	jmp .end
.found:
	lea bx, [es:mountlist + bx]
.end:
	pop si
	pop di
	pop cx
	pop dx
	ret

; Returns a far pointer to a 'mount_point' structure that matches the specified
; name. A helper function that calls _get_mount_point_from_drive.
; Signature:
;	mount_point *get_mount_point(char *drive);
; Input:
;		DS:AX - Name of the drive
; Output:
;		ES:BX  - Far Pointer to the mount_point structure in the 'mountlist'
;				 array which is part of this module.
;				 If not found, then ES and BX is 0
get_mount_point_from_drive:
	push si
		mov si, ax
		call _get_mount_point_from_drive
	pop si
	ret
