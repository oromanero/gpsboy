#include<stdio.h>
#include<graphics.h>
#include<math.h>

#define NP 2

main()
{	int a=VGA,b=VGAHI,ang=0,i,j,x,y,byte0,byte1;
	int pto[NP*2]={0,8,0,0},pt[NP*2];
	double rad;
	FILE *f=fopen("..\\hdnpics.bin","wb");

	initgraph(&a,&b,"");

	for (ang=-2;ang<=90;ang+=2)
	{	setfillstyle(SOLID_FILL,BLUE);
		bar(0,0,23,23);

		setcolor(BLACK);
		circle(11,11,10);
		circle(12,11,10);
		circle(11,12,10);
		circle(12,12,10);
		setfillstyle(SOLID_FILL,LIGHTRED);
		floodfill(12,12,BLACK);

		setcolor(WHITE);

		if (ang>=0)
		{	rad=M_PI*ang/180;
			for (j=0;j<4;j++)
			{	for (i=0;i<NP;i++)
				{	pt[i*2] = 11.5 + j%2
								+ (pto[i*2]*cos(rad) + pto[i*2+1]*sin(rad));
					pt[i*2+1] = 11.5 + j/2
							 - (-pto[i*2]*sin(rad) + pto[i*2+1]*cos(rad));
				}
				line(pt[0],pt[1],pt[2],pt[3]);
			}
		}

		for (j=0;j<3;j++)
			for (i=0;i<3;i++)
				for (y=0;y<8;y++)
				{	byte0=0;
					byte1=0;
					for (x=0;x<8;x++)
					{   byte0<<=1;
						byte1<<=1;
						switch (getpixel(i*8+x,j*8+y))
						{	case WHITE:		byte1|=1; byte0|=1; break;
							case LIGHTRED:	byte1|=1; byte0|=0; break;
							case BLACK:		byte1|=0; byte0|=1; break;
							case BLUE:      byte1|=0; byte0|=0; break;
						}
					}
					fputc(byte0,f);
					fputc(byte1,f);
				}
		/*getch();*/

	}
	fclose(f);
	restorecrtmode();
}