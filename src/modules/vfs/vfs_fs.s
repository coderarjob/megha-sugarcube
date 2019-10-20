; File system operations for VFS file system.
; The vfs_open and vfs_close along with vfs_mount and vfs_umount will be
; implemented as interrupt calls. However in order to get listing of drives 
; from vfs, there has to be some mechanism. I think the way to go is to be 
; able to treat VFS like any other file system. 
;
; So it will be possible to write code like below:
; 	mount(NULL, "vfs", "vfs:")
; 	file *f = vfs_open(NULL,"vfs:","",NT_DIRECTORY)
; 	f->read(f,buffer,100)

; Note that read will read bytes from the mount_table and not read out just the
; individual drives. The bytes that the consumer will get is raw bytes from the
; mount_table. seek will work in bytes as well.


; Open method for the file_operations in VFS file system.
; This method will return sucess if flags have NT_DIRECTORY as input.
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
;			  - ES = 0, in case or error, BX = 1 if flags do not include
;											   NT_DIRECTORY
_vfs_fs_open:
	
