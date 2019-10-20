; A very basic implementation of the VIRTUAL FILE SYSTEM for MOS.
; The responsibilities of the VFS is to keep track of the various mounted
; filesystems and their mount points. It also should provide routines to
; register new file system and mount/unmount operations.
;
; The primary funtion of a VFS is to be able to access files no matter which 
; file system it is in. Thus VFS allows installable file systems that can be 
; added or removed as needed. 
;
; Initial version: 2092019 (2nd September 2019)
;
; --------------------------------------------------------------------------
; Public methods via despatcher:
; --------------------------------------------------------------------------
;   * void register_fs(struct filesystem* newfs);
;   * void mount(struct file *source, char *fsname, char *drive);
;   * int unmount(char *drive);
;   * struct filesystem *init_vfs();
;
; --------------------------------------------------------------------------
; Structures:
; --------------------------------------------------------------------------
; The mount_point structure keeps track of the mount points in the system
; currently installed. This structure binds the file system (thus its
; operations) with the mounted file. Any particular mount point is identified
; by the drive name (can by at max 10 bytes long, including the 
; null terminator byte)
;
; struct mount_point
; {
; 	struct filesystem *fs;	
; 	struct file source_f;
; 	char mount_point[10];
; }
; --------------------------------------------------------------------------
; The file system structure is used internally by the VFS to keep the
; filesystem operations and its name together. The name of the file system is
; used by the mount routine to retrive the filesystem operations.
; This structure exposes the operations to the outside world via the 
; mount_point structure.  
;
; struct filesystem
; {
; 	char fsname[10];
; 	struct filesystem_operations fso;
; }
; --------------------------------------------------------------------------
; This structure is again used internally by the VFS, and holds the two
; operations implemented by any file system together.

; struct filesystem_operations
; {
; 	struct dir_operations *diro;
; 	struct file_operations *fo;
; }
; --------------------------------------------------------------------------
; The members of this structure points to the respective routines in any
; filesystem. An instance of this structure along with the dir_operations is
; what gets registered in the VFS.
; The file_operations and dir_operations is what allows to add filesystems and
; access it.
; Every routine may not be initialised by every file system. However, open and
; close always need to be implemented.
; struct file_operations
; {
; 	struct file *(*open)(struct file*, char *filename, int flags);
; 	int (*read)(struct file*, char *buffer, int size);
; 	int (*write)(struct file*, char *buffer, int size);
; 	int (*close)(struct file*);
; 	struct file_attributes (*get_attr)(struct file*);
; 	int (*set_attr)(struct file*,struct file_attributes*);
; }
;
; struct dir_operations
; {
;	int (*create)(...);
;	int (*delete)(...);
;	struct file *(*open)(struct file *mounted_f, char *foldername, int flags);
; 	int (*close)(struct file*);
;	struct folder_attributes (*get_attr)(...);
;	int (*get_attr)(struct folder_attributes*,...);
; }
;
; --------------------------------------------------------------------------
; This is the one of the main structures that define any opened file (be that
; be a DEVICE file or a DIRECTORY), and also links to the base (mounted
; file / device driver) that lies below, thus forming a linked list.
; In many ways this structure is what keeps track of the nested file systems and
; their file and directory operations together with the file and directory they
; perform on. 
; For example:
; Say we mount C:\Images file to D drive using the FAT16 filesystem. The C
; drive is the mount point for the floppy0 file using the FAT12 filesystem. The
; floppy0 file resides in the drive for the devfs (say E drive).
; So the instance of the file structure for a file in the D drive would have
; the fillowing topology.
;                           d:\selfie.png -----> D drive handled by FAT16 
;                                  |
;								   v
;							  c:\images    -----> C drive handled by FAT12
;                                  |
;							       v
;							  e:\floppy0   -----> E drive handled by devfs
;                                  |
;							       v
;								floppy0    -----> Indentified by its major and
;												  minor numbers and handled 
; 												  by the floppy driver.
;
; ------------|----------------|-------------|-----------------|-----------------------|---------------------|
; File/Device	 File system	 mount point	 base.file		    base.device		 	   file_operations
; ------------|----------------|-------------|-----------------|-----------------------|---------------------|
;   floppy0           -               -               -           DEVICE(major, minor)    floppy driver
; ------------|----------------|-------------|-----------------|-----------------------|---------------------|
; The file system DEVFS is mounted in th E drive.
; ------------|----------------|-------------|-----------------|-----------------------|---------------------|
; e:/floppy0        FAT12             C        floppy0 device              -                   FAT12
;                                              file
; ------------|----------------|-------------|-----------------|-----------------------|---------------------|
; c:/Images         FAT16             D        e:\floppy0                  -                   FAT16
; ------------|----------------|-------------|-----------------|-----------------------|---------------------|

; The structure can be read this way:
;  - File/Directory/Device with name in 'filename' can be read (other operations
;    as well) using the function pointers in ops.fo (or ops.diro if file
;    represents a drectory) members. 
;  - If this file resides in a mounted drive whose parent file is base.file.
; The base union points to either a file or a device file from which the file
; structure is derived.
; 
; If the file points to a device driver, the base.device has the device 
; identity (MAJOR and MINOR) numbers.
;
;struct file
;{
;	file_t type;
;	node_t ntype;
;	char filename[11];
;	union{
;		device_t device;
;		struct file file;
;	} base;
;	union {
;		struct file_operations fo;
;		struct dir_operations diro;
;	} ops;
;	char extra[20];
;}
; --------------------------------------------------------------------------
; Type definations:
; --------------------------------------------------------------------------
; typedef enum {DEVICE, FILESYSTEM} file_t
; typedef enum {NORMAL, DIRECTORY, PIPE} node_t
; typedef int16 device_t;
; --------------------------------------------------------------------------
; Helpful macros:
; --------------------------------------------------------------------------
; MAKDEV(major, minor) ((major) << 8) | (minor))
; MINOR(d) ((d) & 0xFF)
; MAJOR(d) (((d) >> 8) & 0xFF)
;
; =============== [ INCLUDE FLIES ] ===================
; The order of the below included files are not importaint expect for 
; 1. The VFS.INC. This file must be included before vfs_main.s; to be able 
;     to create an instance of a structure, it must be defined first.
; 2. vfs_main.s file has the _init method, and thus must always be included
;    before any .S file.

%include "../../include/vfs.inc"
%include "../../include/mos.inc"
%include "./vfs_main.s"
%include "vfs_base.s"

; =============== [ DATA SECTION ] ===================
fslist: times MAX_REGISTERED_FILESYSTEM * filesystem_size db 0
fslist_count: dw 0

mountlist: times MAX_MOUNT_POINT_COUNT * mount_point_size db 0
mountlist_count: dw 0

fileslist: times MAX_OPEN_FILES_COUNT * file_size db 0
