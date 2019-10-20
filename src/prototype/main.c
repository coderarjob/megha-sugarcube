#include <stdio.h>
#include "vfs.h"
#include "panic.h"

void devfs_init();
void device_init();
void fat_init();
struct file *open(char *filename);
void filename_split(char *filewithpath, char *drive, char *filetitle);

int main()
{
	device_init(); // register_devfs(DEVICE(1,0),&dev_fo,"floppy0");
	devfs_init();  // register_fs("devfs", &devfs_fsi);
	fat_init();    // register_fs("fat", &fat_fsi);

	mount(NULL,"devfs","d");
	struct file *f = open("d:/floppy0");
	mount(f,"fat","c");

	struct file *f1 = open("c:/images");
	mount(f1, "fat", "i");

	struct file *f2 = open("i:/view");
	f2->fo.read(f2,NULL,10);
}

struct file *open(char *filename)
{
	char drive[5], filetitle[11];
	filename_split(filename, drive, filetitle);
	printf("Open: Drive: %s, Filetitle: %s\n", drive, filetitle);

	struct mount_point *mp = get_mount_point(drive);
	if (mp == NULL)
		panic("Drive was not found",3);
	else
		printf("Mount point %s found.\n",mp->mount_point);
	
	struct filesystem *fs = mp->fs;
	struct file_operations *fs_fo = fs->fsi.fo;

	return fs_fo->open(&mp->source_f,filetitle);
}

void filename_split(char *filewithpath, char *drive, char *filetitle)
{
	char c;
	while ((c = *filewithpath++) != ':')
		*drive++ = c;
	*drive = '\0';	
	*filewithpath++;

	while ((c = *filewithpath++))
		*filetitle++ = c;
	
	*filetitle = '\0';
}
