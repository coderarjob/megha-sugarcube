
#include "fs.h"
#include "vfs.h"
#include <string.h>
#include "panic.h"

static struct mount_point mounts[10];
static int mount_counts;

static struct filesystem fses[10] = {0};
static int count;

void register_fs(char *fsname,struct fsinfo *fsi)
{
	struct filesystem *newfs = &fses[count++];	
	strcpy(newfs->fsname, fsname);
	memcpy(&newfs->fsi, fsi, sizeof(struct fsinfo));

	printf("register_fs: Registering file system: %s\n", fsname);
}

void mount(struct file *source, char *fsname, char *drive)
{
	// Search for the particular file system
	struct filesystem *fs = NULL;
	for(int i = 0; i < count; i++)
	{
		struct filesystem *_fs = &fses[i];
		if (strcmp(_fs->fsname, fsname) == 0)
		{
			fs = _fs;
			break;
		}
	}

	if (fs == NULL)
		panic("File system not found",2);
	
	struct mount_point *mp = &mounts[mount_counts++];
	mp->fs = fs;
	if (source != NULL)
		memcpy(&mp->source_f,source, sizeof(struct file));
	strcpy(mp->mount_point,drive);

	printf("mount: mounted filesystem: %s into drive %s\n",fs->fsname,drive);
}

struct mount_point *get_mount_point(char *drive)
{
		
	// Search for the particular mount point
	struct mount_point *mp = NULL;
	for(int i = 0; i < mount_counts; i++)
	{
		struct mount_point *_mp = &mounts[i];
		if (strcmp(_mp->mount_point,drive) == 0)
		{
			mp = _mp;
			break;
		}
	}

	return mp;
}
