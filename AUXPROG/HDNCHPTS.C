#include<stdio.h>

main()
{	int i;
	FILE *f=fopen("..\\hdnchpts.bin","wb");

	for (i=0;i<=45;i++)
	{	fputc(((i+1)*24*6) & 0xFF,f);
		fputc(((i+1)*24*6) >> 8,f);
	}
	fclose(f);
}