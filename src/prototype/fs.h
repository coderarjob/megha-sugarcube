

#ifndef _H_FILE
#define _H_FILE

#include "device.h"

typedef enum {DEVICE, FILESYSTEM} file_t;

struct file_operations
{
	struct file *(*open)(struct file*, char *filename);
	int (*read)(struct file*, char *buffer, int size);
	int (*write)(struct file*, char *buffer, int size);
	int (*close)(struct file*);
	struct file_attributes (*get_attr)(struct file*);
	int (*set_attr)(struct file*,struct file_attributes*);
};

struct filesystem_operations
{

};

struct fsinfo
{
	struct filesystem_operations *fso;
	struct file_operations *fo;
};

struct filesystem
{
	char fsname[10];
	struct fsinfo fsi;
};

struct file
{
	file_t type;
	char filename[10];
	union{
		device_t device;
		struct file *file;
	} base;
	struct file_operations fo;
	int sector;
};

#endif // _H_FILE
