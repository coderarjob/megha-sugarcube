

#include<stdio.h>

static int port_20_value;
static int port_21_value;

void out(int port,int value)
{
	if (port == 20)
		port_20_value = value;
	else if (port == 21)
		port_21_value = value;
}

int in(int port)
{
	if (port == 20)
		return port_20_value;
	else if (port == 21)
		return port_21_value;
}
