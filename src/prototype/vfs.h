
#ifndef _H_VFS
#define _H_VFS

	#include "fs.h"

	struct mount_point
	{
		struct filesystem *fs;	
		struct file source_f;
		char mount_point[10];
	};

void register_fs(char *fsname,struct fsinfo *fs);
void mount(struct file *source, char *fsname, char *drive);
struct mount_point *get_mount_point(char *drive);
#endif // _H_VFS
