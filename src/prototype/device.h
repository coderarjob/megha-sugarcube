

#ifndef _H_DEVICE
#define _H_DEVICE
	
#include<stdint.h> 
typedef uint16_t device_t;

#define DEVICE(m,n) (((m) << 8) | (n))
#define MAJOR(d) ((d >> 8) & 0xFF)
#define MINOR(d) (d & 0xFF)

#endif // _H_DEVICE
