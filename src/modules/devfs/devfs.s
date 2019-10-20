; This is the implementation of devfs filesystem.
; Major Functions:
; --------------------
; 1. Devices will register themselves into the devfs filesystem with their 
;	 major and minor numbers.
; 2. Will implement the filesystem contract, so that VFS will be able to
