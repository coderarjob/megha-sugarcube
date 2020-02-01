#! /bin/sh

# Directory structure
# -------------------
# 1. The source files are placed in src folder or any of its subfolders.
# 2. Compilled binaries are placed in the Build folder.
# 3. Disk images for the OS is placed in the disk_images folder.

# Compile the bootloader
pushd src/bootloader
	echo "    [ Compilling bootloader ]    "
	nasm -f bin boot.s -g -o ../../build/boot -l ../../lists/boot.lst|| exit
popd

# Compile the Kernel and its modules
pushd src/kernel
	echo "    [ Compilling loader ]    "
	nasm -f bin loader.s -g -o ../../build/loader -l ../../lists/loader.lst|| exit
	echo "    [ Compilling guru.mod ]    "
	nasm -f bin guru.s  -o ../../build/modules/guru.mod -l ../../lists/guru.lst||exit
	echo "    [ Compilling despchr.mod ]    "
	nasm -f bin despatcher.s  -o ../../build/modules/despchr.mod -l ../../lists/despatcher.lst || exit
	echo "    [ Compilling kernel.mod ]    "
	nasm -f bin kernel.s  -o ../../build/modules/kernel.mod -l ../../lists/kernel.lst || exit
popd

# Compile the device drivers
pushd src/devices
	echo "    [ Compilling 8254 driver ]    "
	nasm -f bin 8254.s -g -o ../../build/modules/pit.mod -l ../../lists/pit.lst || exit
	echo "    [ Compilling Keyboard driver ]    "
	nasm -f bin keyboard.s -g -o ../../build/modules/kbd.mod -l ../../lists/kbd.lst || exit
popd

# Compile the user programs
pushd src/programs
	echo "    [ Compiling User Program: Demo ]    "
	nasm -f bin demo.s -g -o ../../build/programs/demo.com -l ../../lists/demo.lst || exit
popd

# Build the floppy image
echo "    [ Creating disk image ]    "
rm -f disk_images/boot.flp
mkdosfs -C disk_images/boot.flp 1440 || exit

# mount the Disk image
echo "    [ Copy needed files to the floppy image ]    "
runas mount disk_images/boot.flp temp || exit

# Copy the files needed to the floppy
echo "    [ Copy files to floppy ]    "
runas cp build/loader temp/loader || exit
runas cp build/modules/guru.mod temp/guru.mod || exit
runas cp build/modules/kernel.mod temp/kernel.mod || exit
runas cp build/modules/despchr.mod temp/despchr.mod || exit
runas cp build/modules/pit.mod temp/pit.mod || exit
runas cp build/modules/kbd.mod temp/kbd.mod || exit
runas cp build/programs/demo.com temp/demo.com || exit
#runas cp ~/asm/projects/megha/demo/keyboard/key.mod temp/key.mod || exit
#runas cp ~/asm/projects/megha/demo/vga/vga.mod temp/vga.mod || exit

# Unmount the image
echo "    [ Copy of files done. Unmounting image ]    "
runas umount temp || exit

# Wrtie the bootloader
echo "    [ Writing bootloader to floppy image ]    "
dd conv=notrunc if=build/boot of=disk_images/boot.flp || exit

echo "    [ Done ]"

# Display the size of files in Build and its Sub Directories
wc -c build/* build/modules/*.mod

