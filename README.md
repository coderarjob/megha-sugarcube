# MEGHA OPERATING SYSTEM SUGARCUBE                                  INTRODUCTION

This version of Megha Operating System is more for the proof of concept. Many
modules like the VFS exist for the namesake, and many more features like
'mountable file systems' etc, simply do not exist.

The motivation of this version is that I want a usable operating system before
10th Feb 2020, and it is already 21st October 2019. I want to have a demo ready
for Jayati before our marriage day.

Wish me Luck!

## Features available in Sugarcube:

1. Console module, for outputting text on the screen.
2. FAT12 file system with the system calls for opening, reading and writting.
3. An command interpretter.
4. A functional keyboard driver with type ahead features and code pages.
5. A simple sound driver, capable of pitch change and producing sound.
6. Few simple programs:- cat, dir, echo.
7. Modules:- Guru, Despatcher, Console, Sound, KDB, MKRNL
8. Many modules like the Console, terminal, VFS, even tough available in
   Sugarcube, are not the final versions and will lac many features.

## Features exclusive to Sugarcube:

1. Will have one mount point for the floppy using the FAT12 file system.
2. VFS mount, and umount is not available, but vfs_open, vfs_read, vfs_write,
   vfs_close system calls will work as expected as if there was only one drive.
3. A program called JAYATI for our special night.


## Features not available in Sugarcube:

1. DEVFS, so devices can be treated as files.
2. VFS, ability of open, read and write files seemlessly between different
   devices and different file systems.
3. Ability to mount devices.
4. Extensibe driver model:- Ability to have hook methods etc.
5. Multiple application programs like edittor, mount etc.

