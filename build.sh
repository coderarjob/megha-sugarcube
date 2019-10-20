#! /bin/sh

# Directory structure
# -------------------
# 1. The source files are placed in src folder or any of its subfolders.
# 2. Compilled binaries are placed in the Build folder.
# 3. Disk images for the OS is placed in the disk_images folder.

# Compile the bootloader
pushd src/bootloader
	echo "=== Compilling bootloader ==="
	nasm -f bin boot.s -g -o ../../build/boot -l ../../lists/boot.lst|| exit

	echo "=== Compilling loader ==="
	nasm -f bin loader.s -g -o ../../build/loader -l ../../lists/loader.lst|| exit
popd

pushd src/modules
	echo "=== Compilling guru.mod ==="
	nasm -f bin guru/guru.s  -o ../../build/modules/guru.mod -l ../../lists/guru.lst||exit
	echo "=== Compilling kernel.mod ==="
	nasm -f bin kernel/kernel.s  -o ../../build/modules/kernel.mod -l ../../lists/kernel.lst || exit
	echo "=== Compilling despchr.mod ==="
	nasm -f bin despatcher/despatcher.s  -o ../../build/modules/despchr.mod -l ../../lists/despatcher.lst || exit
popd


# Build the floppy image
echo "=== Creating disk image ==="
rm -f disk_images/boot.flp
mkdosfs -C disk_images/boot.flp 1440 || exit

# mount the Disk image
echo "=== Copy needed files to the floppy image ==="
runas mount disk_images/boot.flp temp || exit

# Copy the files needed to the floppy
echo "=== Copy ossplash.bin ==="
runas cp bitmaps/bins/megha_boot_image_v2.data temp/ossplash.bin || exit
runas cp build/loader temp/loader || exit
runas cp build/modules/kernel.mod temp/kernel.mod || exit
runas cp build/modules/guru.mod temp/guru.mod || exit
runas cp build/modules/despchr.mod temp/despchr.mod || exit

# Unmount the image
echo "=== Copy of files done. Unmounting image ==="
runas umount temp || exit

# Wrtie the bootloader
echo "=== Writing bootloader to floppy image ==="
dd conv=notrunc if=build/boot of=disk_images/boot.flp || exit

echo "Done"
