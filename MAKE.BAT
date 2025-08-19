dev\rgbasm -ogpsboy.obj gpsboy.asm
dev\xlink -z0 -ngpsboy.sym -mgpsboy.map gpsboy.lnk
copy /b gpsboy.x + mapsevi.bin gpsboy.gb
dev\rgbfix -v gpsboy.gb

