




#ifndef _H_PANIC
#define _H_PANIC
	#include<stdlib.h> // for exit
	#include <stdio.h>
	#define panic(s,r) do{printf("%s\n",s);exit(r);}while(0)
#endif // _H_PANIC
