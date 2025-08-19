#include<stdio.h>
main()
{	unsigned long i,j;
	FILE *f;

    f=fopen("..\\xcrd2map.bin","wb");
	for (i=0;i<6382;i+=2)
	{	j=608L*i/4490;
		fputc(j&0xFF,f);
		fputc((j>>8)&0xFF,f);
	}
	fclose(f);

    f=fopen("..\\ycrd2map.bin","wb");
	for (i=0;i<8378;i+=2)
	{	j=628L*i/3961;
		fputc(j&0xFF,f);
		fputc((j>>8)&0xFF,f);
	}
	fclose(f);
}
