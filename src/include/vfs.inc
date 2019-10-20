
%ifndef __VFS_INC_
	%define __VFS_INC_

	; Flags that control few aspects of the VFS

	; MAX values
	FILESYSTEM_NAME_MAX_LENGTH: equ 10
	MAX_REGISTERED_FILESYSTEM: equ 10
	
	MAX_DRIVE_NAME_LENGHT: equ 10
	MAX_MOUNT_POINT_COUNT: equ 10
	MAX_OPEN_FILES_COUNT: equ 10

	; file_t typedef
	FT_DEVICE: EQU 0
	FT_FILESYSTEM: EQU 1

	; node_t typedef
	NT_NORMAL: EQU 0
	NT_DIRECTORY: EQU 1
	NT_PIPE: EQU 2

	; file structure flags
	FILE_OPEN_BIT		EQU 0		; OPEN 1, CLOSE 0
	
	; All the pointers (memory locations) need to be far pointers in the
	; 'mount_point' and 'filesystem' structures, as these structures either
	; supply data from or to outside the VFS module.
	struc mount_point
		.filesystem resd 1	; struct filesystem *fs (far pointer)
		.source_file resd 1  ; struct file *source_f
		.mount_name resb MAX_DRIVE_NAME_LENGHT
	endstruc

	struc filesystem
		.fsname resb FILESYSTEM_NAME_MAX_LENGTH
		.fo   resd 1		; Far pointer to file_operations
	endstruc

	; Helper macro to create proocedures
	%macro PROC 1
		%1.offset resw 1
		%1.segmnet resw 1
		%1 EQU %1.offset
	%endmacro

	struc file_operations
		PROC .open  ; struct file *open(struct file*, char *drive,
					; char *filename_with_path, int flags);
		PROC .create; int create(char *drive, char *filename, int type, 
					; int flags)
		PROC .remove; int remove(char *drive, char *filename, int flags)
		PROC .read  ; int (*read)(struct file*, char *buffer, int size);
		PROC .write ; int (*read)(struct file*, char *buffer, int size);
		PROC .close ; int (*close)(struct file*);
		PROC .seek  ; int (*seek)(struct file*, int location)
		PROC .get_attr ; struct file_attributes (*get_attr)(struct file*);
		PROC .set_attr ; int (*set_attr)(struct file*,struct file_attributes*);
	endstruc

	struc file_stat
		.creation_date  resw 1
		.accessed_date	resw 1
		.size_bytes		resd 1
		.block_size		resw 1
		.current_sector	resd 1
	endstruc

	struc file
		.nflags	   resb 1		; Can be used to store flags. Multiple flags
								; are ORed together.
		.file_type resb 1		; FT_FILESYSTEM, FT_DEVICE
		.node_type resb 1		; NT_NORMAL, NT_DIRECTORY, NT_PIPE
		.filename resb 11		; Name of the node.

		; union{ device_t device; struct file *file} base;
		.device resw 1		
		.file_high resw 1	; stores the high byte of 32 bit file pointer
		.file equ .device

		.file_op resd 1					; File operations far pointer
		.file_info resb file_stat_size	; Some information about the node and a
										; position field to keep track of the
										; current position in the node.
	endstruc

%endif
