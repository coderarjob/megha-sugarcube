

#include "device.h"
#include "fs.h"
#include <string.h>	// strcpy
#include <stdlib.h> // malloc
#include <stdio.h>
#include "panic.h"
#include "devfs.h"
#include "vfs.h"

static struct file devices[10];
static int device_count;
int devfs_read(struct file *mounted_f, char *buffer, int size);
struct file* devfs_open(struct file *mounted_f, char *filename);

struct file_operations devfs_fo = {
	.open = devfs_open,
	.read = devfs_read,
};

struct fsinfo devfs_fsi = {
	.fso = NULL,
	.fo = &devfs_fo
};

static struct file files[10];
static int file_count;

void devfs_init()
{
	printf("Registering devfs file system.\n");
	register_fs("devfs", &devfs_fsi);
}

void register_devfs(device_t device, struct file_operations *fo, char
					*device_name)
{

	struct file *newfile = &devices[device_count++];
	newfile->type = DEVICE;
	strcpy(newfile->filename,device_name);
	newfile->base.device = device;
	memcpy(&newfile->fo, fo, sizeof(struct file_operations));

	printf("register_devfs: Registering: %s\n", device_name);
}

struct file* devfs_open(struct file *mounted_f, char *filename)
{
	printf(" devfs_open: %s, %s\n", mounted_f->filename,filename);
	
	// Search for the deivce file
	struct file *f = NULL;
	for (int i = 0; i < device_count;i++)
	{
		struct file *tf = &devices[i];
		if (strcmp(tf->filename, filename) == 0){
			f = tf;
			break;
		}
	}

	if (f == NULL)
		panic("DEVICE not found",1);	

	// read 2 bytes
	f->fo.read(f,NULL,2);

	struct file *newfile = &files[file_count++];
	newfile->type = FILESYSTEM;
	strcpy(newfile->filename,filename);
	newfile->base.file = f;
	memcpy(&newfile->fo, &devfs_fo, sizeof(struct file_operations));
	
	return newfile;
}

int devfs_read(struct file *current_f, char *buffer, int size)
{
	struct file *device = current_f->base.file;
	current_f->sector += (size+10);

	printf (" devfs_read: current: %s [type: %u] device: %s [type: %u]",
			current_f->filename, current_f->type, device->filename,
			device->type);
	printf(" sector: %u\n", current_f->sector);
	
	return device->fo.read(device, buffer, size);
}
