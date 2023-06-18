@echo off

SET MYPATH=C:\MS-DOS-2.0-Olivetti\

echo Remove attributes from system files
attrib -h -r -s %MYPATH%\MSDOS2_SYS\IBMBIO.COM
attrib -h -r -s %MYPATH%\MSDOS2_SYS\IBMDOS.COM
attrib -h -r -s %MYPATH%\MSDOS2_SYS\COMMAND.COM
rem attrib -h -r -s %MYPATH%\MSDOS2_SYS\FORMAT.COM
rem attrib -h -r -s %MYPATH%\MSDOS2_SYS\SYS.COM


echo Assembling boot sector dosboot.asm
%MYPATH%\nasm.exe -O0 -f bin -o %MYPATH%\dosboot.bin %MYPATH%\dosboot.asm

echo Copying files
copy dosboot.bin msdos2.img

echo Mounting disk image...
%MYPATH%\imdisk.exe -a -f %MYPATH%\msdos2.img -s 720K -m B:

echo Copying system files to disk image...

copy %MYPATH%\MSDOS2_SYS\IBMBIO.COM b:\
copy %MYPATH%\MSDOS2_SYS\IBMDOS.COM b:\
copy %MYPATH%\MSDOS2_SYS\COMMAND.COM b:\
rem copy %MYPATH%\MSDOS2_SYS\FORMAT.COM b:\
rem copy %MYPATH%\MSDOS2_SYS\SYS.COM b:\

echo Dismounting disk image...
%MYPATH%\imdisk.exe -D -m B:

echo Change FAT in IMG file
Fix_FAT_img.exe

echo Done!

pause
