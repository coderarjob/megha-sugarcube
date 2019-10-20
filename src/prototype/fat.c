
#include "device.h"
#include "fs.h"
#include <string.h>	// strcpy
#include <stdlib.h> // malloc
#include <stdio.h>
#include "panic.h"
#include "vfs.h"

static struct file files[10];
static int device_count;
int fat_read(struct file *mounted_f, char *buffer, int size);
struct file* fat_open(struct file *mounted_f, char *filename);

struct file_operations fat_fo = {
	.open = fat_open,
	.read = fat_read,
};

struct fsinfo fat_fsi = {
	.fso = NULL,
	.fo = &fat_fo
};

static struct file files[10];
static int file_count;

void fat_init()
{
	printf("Registering fat file system.\n");
	register_fs("fat", &fat_fsi);
}


struct file* fat_open(struct file *mounted_f, char *filename)
{
	printf(" fat_open: mounted_f->filename: %s, type: %u, file to open:%s\n", 
				mounted_f->filename,mounted_f->type, filename);

	//struct file *base_f = mounted_f->base.file;
	//base_f->fo.open(base_f, base_f->filename);
	
	struct file *newfile = &files[file_count++];
	newfile->type = FILESYSTEM;
	strcpy(newfile->filename,filename);
	newfile->base.file = mounted_f;
	memcpy(&newfile->fo, &fat_fo, sizeof(struct file_operations));
	
	return newfile;
}

int fat_read(struct file *current_f, char *buffer, int size)
{
	struct file *parent = current_f->base.file;
	current_f->sector += size;

	printf (" fat_read: current: %s [type: %u] parent: %s [type: %u]",
			current_f->filename, current_f->type, parent->filename,
			parent->type);
	printf(" sector: %u\n", current_f->sector);

	return parent->fo.read(parent, buffer, size);
}
