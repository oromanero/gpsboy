
A little introduction...

GPS BOY is a portable GPS (Global Positioning System) receiver system
based on a commercial GPS integrable module (Trimble's Lassen SK II)
and a Game Boy Color. It provides typical GPS receiver functions
(longitude, latitude, speed, heading, etc.) through the GBC's LCD
screen. It also includes a nice map function, that you won't be able to
use it unless you're located in the city of Seville, Spain (my home
place).

To use GPS BOY, follow the steps below:

1. Connect the Lassen SK II board to the GBC's link port. See CONNECT.GIF
   picture.

2. The Lassen SK II requires a 5V power source able to supply a minimum  of
   300mA intensity. Pin 1 of the GBC link port is a 5V output, but
   unfortunately it seems not to provide more than 200mA, so you'll need an
   external battery or something. Values ranging from 4.75V to 5.25V are
   accepted by the Lassen SK II board (I personally use a 4.8V rechargeable
   battery from an old cellular phone).

3. Don't forget to attach the antenna to the Lassen SK II's antenna
   connector.

4. Burn the provided GPSBOY.GB rom image file into your favourite flash card
   and insert it into your GBC.

5. Turn both devices on. Use SELECT button to switch navigation/map
   mode.


To build up the executable file from the sources, run MAKE.BAT under
MSDOS. You need the ASMotor (RGBDS) package to compile, link, etc.
Place the RGBASM, XLINK and RGBFIX utilities into a subdirectory called
DEV (or modify MAKE.BAT to another location).


You can use this software freely. I don't mind if you modify it and/or
distribute it as long as you don't use it for commercial purposes. You
can also tell your friends that you wrote it yourself, it's up to you to
join the World Wide Club of Lamers.


Thanks go to Carsten Sorensen for his *great* ASMotor package and
Martin Korth for his *awesome* NO$GMB (yo, Martin).


For any comment, email me at:
    e-sanchez@mixmail.com   or   enrique_sanchez_rosa@hotmail.com
    (Enrique Sanchez)

For info about the Lassen SK II board:
    www.trimble.com/lassenskii.html

