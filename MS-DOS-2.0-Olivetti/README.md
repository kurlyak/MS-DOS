# MS-DOS-2.0-Olivetti

MS-DOS 2.0 source code.

https://github.com/microsoft/MS-DOS

https://github.com/Microsoft/MS-DOS/blob/master/LICENSE.md

The folder contains the decompiled source code of the boot sector for the 720KB Microsoft MS-DOS 2.0 (Olivetti) floppy disk.

The dosboot.asm file contains the decompiled MS DOS 2.0 boot sector for a 720KB floppy disk. To compile the dosboot.asm source code, you need the NASM assembly language compiler nasm.exe.

The dosboot.bin file contains the original boot sector extracted from the Microsoft MS-DOS 2.0 (Olivetti) 360KB floppy boot disk.

The build_msdos2_img.bat file contains commands for building an IMG image. To create an IMG image, you will need the NASM compiler nasm.exe, the floppy for creation disk images imdisk.exe, and any HEX editor. You can run the created IMG image in VirtualBox.

If you make an IMG image based on this boot sector using the imdisk.exe program, then the IMG file must be edited in a HEX editor. Open the IMG file in a HEX editor, go to offset 200h, the first three bytes will be 0x00 0x00 0x00, replace them with 0xF9 0xFF 0xFF - otherwise the IMG image will not load (VirtualBox was used to load the IMG image).

In the IMG image, the FAT table is located at address 200h, the first byte 0xF9 indicates that this is a 720 KB disk. I.e. zero FAT cluster (the very first pointer to the FAT table), contains the value Bios Parameter Block - Media Byte. For example for HDD it value is 0xF8.

Some technical details about MS DOS booting. The root directory of the disk (that is used for boot MS-DOS) must be loaded into memory at 50h:0 (DOS Data Area). The IBMBIO.COM file must be loaded into memory at 70h:0. When creating an IMG image, the IBMBIO.COM file must be written to disk first, then the IBMDOS.COM file must be written to disk (this is a prerequisite IBMBIO.COM and IBMDOS.COM the first two files in the root directory), then COMMAND.COM and additionally any other files.

For success assembling IMG file create directory named MSDOS2_SYS (location build_msdos2_img.bat file) and place files in this directory: IBMBIO.COM, IBMDOS.COM,  COMMAND.COM. Additionally you can place any files you need, but not forget add this files to build_msdos2_img.bat file.