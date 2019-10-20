
#ifndef _H_DEVFS
#define _H_DEVFS

#include "fs.h"

void register_devfs(device_t device, struct file_operations *fo, char
					*device_name);
#endif // _H_DEVFS
