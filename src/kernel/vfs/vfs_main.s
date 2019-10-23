
; ============ [ CODE BLOCK ] =========
; Every module in MOS starts at location 0x64. The below 100 bytes, from 0x0 to
; 0x63 is for the future use.
	ORG 0x100
;
; The first routine in any module is the _init routine. This can be as simple
; as a retf statement or can actually be used for something importaint.
_init:
	pusha

	; We will add each of the public methods to the despatcher
	; Public methods: vfs_open, vfs_close, vfs_mount, vfs_umount and
	;                 vfs_register_fs

	mov bx, DS_ADD_ROUTINE
	mov cx, cs

	; Add the vfs_open method to despatcher
	mov ax, 0xA
	mov dx, vfs_open
	int 0x40

	; Add the vfs_close method to despatcher
	mov ax, 0xB
	mov dx, vfs_close
	int 0x40

	; Add the vfs_mount method to despatcher
	mov ax, 0xC
	mov dx, vfs_mount
	int 0x40

	; Add the vfs_umount method to despatcher
	mov ax, 0xD
	mov dx, vfs_umount
	int 0x40

	; Add the vfs_register_fs method to despatcher
	mov ax, 0xE
	mov dx, vfs_register_fs
	int 0x40

	popa
	retf

;TODO: Implement the vfs_write method.
;TODO: Implement the vfs_read method.
;TODO: Implement the vfs_seek method.
;TODO: Implement the vfs_stat method.
;TODO: Implement the vfs_initialize method. This method will return a
;	   filesystem structure pointer to OS, which will be used to call the vfs 
;	   methods, instead of the despatcher.

; This call will mark the specified file as closed
; Input:
;		DS:AX - Near pointer to the where the specific file is stored in the
;		        CS:fileslist array.
; Output:
;		BX - 0 if success, 1 if file already closed.
vfs_close:
	push ax
		mov bx, ax			; Store the pointer into BX, helps in addressing.
		lea bx, [cs:bx]
	
		; Check if file already closed
		mov al, [bx + file.nflags]
		and al, (1 << FILE_OPEN_BIT)
		jz .file_closed

		; Not closed, close it, CLEAR the FILE_OPEN_BIT
		and [bx + file.nflags], byte ~(1 << FILE_OPEN_BIT)

		mov bx, 0
		jmp .end
.file_closed:
		mov bx, 1
.end:
	pop ax
	ret

; The operating system will call this routine when it wants to get the file
; structure for any file/device it wants to open (on any drive and any device).
; Input:
;		DS:AX - Can be any value, not really used.
;		DS:CX - Far pointer to asciiz drive name.
;				Format: MountPoint:
;		DS:DX - Far pointer to asciiz file name in the drive.
;				Format: /folder1/file1.txt
;		SI	  - Flags ot be provided as it is to the underlying file system
;				module for the file.
; Output:
;		ES:BX - Holds the location of the file object that was created. When
;				successful, ES = data segment of VFS module, as files are 
;				stored here.
;			  - ES = 0, in case or error, BX = 101, if drive was not found.
;			                              BX = 102, if maximum files are open.
vfs_open:
	push bp
	mov bp, sp

	struc params, 2
		.mounted_file resw 1
		.drive_name resw 1
		.filename_with_path resw 1
		.flags resw 1
		.return_status resw 1
	endstruc

	mov [bp - params.mounted_file], ax
	mov [bp - params.drive_name], cx
	mov [bp - params.filename_with_path], dx
	mov [bp - params.flags], si

	push ax
	push cx
	push dx
	push si
	push di
	push ds

	; -------------------------------------------------------------------------
	; 1. Get the mount point
	; -------------------------------------------------------------------------
	; Searches drive name in near pointer DS:AX
	; Returns a far pointer in ES:BX
	mov ax, [bp - params.drive_name]
	call get_mount_point_from_drive	
	cmp bx, 0						; If not found, ES and BX are set to 0
	je .drive_not_found
	
	; -------------------------------------------------------------------------
	; 2. Call filesystem operations Open routine
	; -------------------------------------------------------------------------
	; Load ES and BX with the location of filesystem from the mount point
	les bx, [es:bx + mount_point.filesystem] 	

	; Load address of the file_operations 
	les bx, [es:bx + filesystem.fo]

	; Call the Open method
	mov ax, [bp - params.mounted_file]
	mov cx, [bp - params.drive_name]
	mov dx, [bp - params.filename_with_path]
	mov si, [bp - params.flags]
	call far [es:bx + file_operations.open]		
	
	mov ax, es			; Segment of the specific file system module
	mov si, bx			; BX holds the offset in that segment

	; Check if open call was a success
	cmp ax, 0
	je .open_failed_from_child

	; -------------------------------------------------------------------------
	; 4. Now copy the newly created file structure in the respective file
	;    system module to local array. All opened files via VFS resides in side
	;    VFS itself.
	; -------------------------------------------------------------------------
	call _get_free_file_location	; Returns a near pointer in BX
	cmp bx, 0						; On failure returns 0
	je .toomuch

	push bx				; Preserve this offset, needs to be returned
		mov di, bx		; DI holds now the offset at will file will be copied

		; Make changes in segment registers that will make copying easy.
		; Make DS = segment of the file system
		mov ds, ax

		; Make ES = CS
		push cs
		pop es

		; Copy file_size bytes from source (FS module) to destination (local)
		mov cx, file_size
		rep movsb		; Copies CX bytes from DS:SI to ES:DI

	pop bx

	; Mark the flie as Open by SETTING FILE_OPEN_BIT bit.
	or [es:bx + file.nflags],byte (1 << FILE_OPEN_BIT)

.drive_found:
	; At this point, ES = CS and BX = offset where the new file is stored.
	jmp .end
.drive_not_found:
	xor bx, bx
	mov es, bx
	mov bx, ERR_DRIVE_NOT_FOUND
.toomuch:
	xor bx, bx
	mov es, bx
	mov bx, ERR_FILE_LIMIT_EXCEED
.open_failed_from_child:
	; At this point ES = 0 and BX has some value recognising the error.
.end:
	pop ds
	pop di
	pop si
	pop dx
	pop cx
	pop ax
	leave	; sets sp = bp and then pops ep
	retf


; Checks the CS:fileslist array to see which location can be used to store a
; new file structure. Free files are marked using the .nflags field in the file
; structure.
; Input:
;		None
; Output:
;		BS: Near pointer to the free location, 0 if none is free
_get_free_file_location:
	push ax
	push cx
	push si
	push ds

	; Make DS = CS
	push cs
	pop ds

	mov si, fileslist
	mov cx, MAX_OPEN_FILES_COUNT
.again:
	lodsb			; Loads AL with value in DS:SI
	cmp al, 0
	je .free

	add si, file_size
	dec cx
	jnz .again

.none_free:
	mov bx, 0
	jmp .end
.free:
	mov bx, si
.end:
	pop ds
	pop si
	pop cx
	pop ax
	ret

; Find index of a character in the asciiz string
; Input:
;		DS:AX = location of string
;		CX = Character to find
;		DX = Start index
; Output:
;		BX = index of the character. First character is at location 0
_str_indexof:		
	push si
	push ax

		mov si, ax
		mov bx, dx
		add ax, dx
.again:
		lodsb
		cmp al, 0
		je .not_found

		cmp al, cl
		je .end

		inc bx
		jmp .again
.not_found:
		mov bx, 0xFFFF
.end:
	pop ax
	pop si
	ret
