#include "devfs.h"
#include <stddef.h>
#include <stdio.h>

struct file *dev_open(struct file *mounted_f, char *filename);
int dev_read(struct file *mounted_f, char *buffer, int size);

struct file_operations dev_fo = {
	.open = dev_open,
	.read = dev_read
};

void device_init()
{
	device_t dev = DEVICE(1,0);
	printf("device_init: Registering device, major: %u, minor: %u\n",
			MAJOR(dev), MINOR(dev));

	register_devfs(dev,&dev_fo,"floppy0");
}

struct file *dev_open(struct file *mounted_f, char *filename)
{
	printf(" dev_open: %s, major = %u, minor = %u, filename = %s\n",
				mounted_f->filename,
				MAJOR(mounted_f->base.device),
				MINOR(mounted_f->base.device),
				filename);
	return NULL;
}

int dev_read(struct file *current_f, char *buffer, int size)
{
	current_f->sector += size;
	printf(" dev_read: %s, major = %u, minor = %u, sector: %u\n",
				current_f->filename,
				MAJOR(current_f->base.device),
				MINOR(current_f->base.device),
				current_f->sector);
}
