;==================================================================
;Ed Kurlyak 2023
;Reverse Engineering MS-DOS 2.00 boot sector. NASM source code.
;Final two bytes being the boot signature (AA55h). 
;==================================================================

	BITS 16

	org 7C00h

os_start:

	jmp short dos_main	;3 bytes takes jmp (jmp short takes 2 bytes need add nop 1 byte)
						;Bios Parameter Block starts in 3 bytes offset
	nop					;for padding	
; ------------------------------------------------------------------
;Bios parameter block BPB
;Values are those used for 720KB diskette

OSLabel         	db "MSDOS20 " 	;8 bytes name
BytesPerSector   	dw 200h 		;bytes per logical sector
SectorsPerCluster	db 2 			;logical sectors per cluster
ReservedForBoot  	dw 1 			;reserved sectors for boot record
NumberOfFats     	db 2 			;number of fat
RootDirEntries   	dw 70h 			;number of entries in root dir
LogicalSectors    	dw 2D0h 		;total logical sectors
;MediaByte			db 0F0h			;medium descriptor 1440 KB diskette
MediaByte         	db 0F9h 		;media desctiptor 720 KB diskette
;MediaByte         	db 0FDh 		;media desctiptor 360 KB diskette
;MediaByte         	db 0F8h 		;media desctiptor for HDD
SectorsPerFat    	dw 2 			;logical sectors per FAT
SectorsPerTrack  	dw 9 			;physical sectors per track
Sides            	dw 2 			;number of sides/heads
HiddenSectors    	dw 0 			;number of hidden sectors

;end of bios parameter block

        			db    0 		;os_start + 1Eh DriveAndHead
        			db    0 		;os_start + 1Fh HeadToRead
        			db  0Ah 		;os_start + 20h how much sectors read
DiskParamTable		db 0DFh 		;disk parameter table 11 byte
        			db    2
        			db  25h
        			db    2
       				db    9
           			db  2Ah
           			db 0FFh
         			db  50h
        			db 0F6h
         			db    0
       				db    2
; ------------------------------------------------------------------
;MAIN CODE SECTION

;variables are placed in Bios Parameter Block to save memory
StartRootDir				EQU	os_start + 03h 	;start logicalsector root directory
StartUserData 				EQU	os_start + 13h 	;start logical sector user data
PhysicalSectorToRead	  	EQU os_start + 15h 	;var physical sector to read disk
DriveAndHead				EQU os_start + 1Eh 	;word - drive and head
HeadToRead 					EQU	os_start + 1Fh 	;var head to read disk
TrackToRead 				EQU	os_start + 08h 	;var track to read disk
SectorsReadCount			EQU	os_start + 20h 	;how much sectors remains to read

reboot:
	int 19h

dos_main:		;INPUT DL = 0 for floppy, DL = 80h for HDD

	cli				;disable interrupts while changing stack

	xor ax, ax
	mov ss, ax 		
	mov sp, 7C00h 
	mov ds, ax

	mov ds:7Ah, ax
	;mov word ds:78h, 7C21h
	mov word ds:78h, DiskParamTable 	;set up new disk parameter table 11 byte

	sti 		;enable interrupts	

	int 13h 	;DISK - RESET DISK SYSTEM
				;DL = drive

	jnb short calculate_start_sector
	jmp print_disk_error_msg

	;now calculate start sector for root dir and user data

	;start of root = ReservedForBoot + HiddenSectors + NumberOfFats * SectorsPerFat
	;number of root = RootDirEntries * 32 bytes/entry / 512 bytes/sector
	;start of user data = (start of root) + (number of root)

calculate_start_sector:
	push cs
	pop ds

	mov al, [NumberOfFats]
	cbw 						;convert byte to word cbw
	mul word [SectorsPerFat]
	add ax, [HiddenSectors]
	add ax, [ReservedForBoot]
	mov [StartRootDir], ax
	mov [StartUserData], ax
	mov ax, 20h 				;32 bytes per root entry
	mul word [RootDirEntries]
	add ax, 1FFh 				
	mov bx, 200h 				
	div bx
	add [StartUserData], ax

	call read_root_dir_into_memory
	jb short reboot

	mov ax, [StartUserData] 	;this var changing, should make copy
	mov [StartUserDataVal], ax

	;IBMBIO.COM for DOS should be loaded at 70h:0
	mov ax, 70h 		;location 0h:0700h is for read IBMBIO.COM for MS-DOS
	mov es, ax 			;0h:0700h is DOS interface to ROM I/O routines
	mov ds, ax 			;that is unnecessary
	mov bx, 0 			;ES:BX = 70h:0h address to load IBMBIO.COM

label3:
	mov ax, cs:[StartUserData] 	;start sector for user data
	call logical2chs 			;convert logical sector to chs for disk read
	mov al, cs:[SectorsPerTrack]
	sub al, cs:[PhysicalSectorToRead]
	inc al
	xor ah, ah
	push ax
	mov ah, 2 			;function 02h read sectors int 13h
	call read_sectors
	pop ax
	jb short print_disk_error_msg
	sub cs:[SectorsReadCount], al
	jbe short label2 		;we are finished read IBMBIO.COM
	add cs:[StartUserData], ax 			;ax = 5
	mul word cs:[BytesPerSector] 		;5 * 512
	add bx, ax 							;bx offset to read
	jmp short label3	;continue read IBMBIO.COM

;finished read IBMBIO.COM
label2:

	push cs
	pop ds
	int 11h 		;EQUIPMENT DETERMINATION
					;Return: AX = equipment flag bits	
	rol al, 1
	rol al, 1
	and ax, 3
	jnz short go_to_end
	inc ax

go_to_end:
	inc ax

	mov cx, ax
	test byte [DriveAndHead], 80h
	jnz load_bios
	xor ax, ax

load_bios:
	mov bx, [StartUserDataVal]

	jmp 70h:0 		;start DOS!

;------------------------------------------------------------------
;SUBROUTINE SECTION

print_disk_error_msg:

	mov si, disk_error_msg
	call print_msg

	jmp $

;------------------------------------------------------------------

print_msg:
	;lods byte cs:[si]
	lodsb
	and al, 7Fh
	jz short func_ret
	mov ah, 0Eh
	mov bx, 7
	int 10h 	;VIDEO - WRITE CHARACTER AND ADVANCE CURSOR
				;AL = character, BH = display page (alpha modes)
				;BL = foreground color (graphics modes)

	jmp short print_msg			

;------------------------------------------------------------------

read_root_dir_into_memory:
	mov ax, 50h		;root dir should be loaded at 0h:0500h
	mov es, ax		;this is DOS reserved communication area
					;booting process will be failure
					;if load root dir into another location
					;ES:BX - buffer for load root dir
	push cs
	pop ds
	mov ax, cs:[StartRootDir] 	;sector start for floppy root directory
	call logical2chs 		;convert logical sector of root to chs for disk read
	mov bx, 0 				;offset in memory for read root dir
	mov ax, 201h 			;02h = function read disk, 01h read one sector of root dir
	call read_sectors
	jb print_non_system_disk_msg
	xor di, di 				;prepare di change file names in lowercase its unnecessary
	mov cx, 11 				;filename length

label1:
	or byte es:[di], 20h 		;make filename IBMBIO.COM in lowercase
	or byte es:[di + 20h], 20h 	;make filename IBMDOS.COM in lowercase
	inc di
	loop label1 		;loop 11 times - filename length
	xor di, di
	mov si, IBMBIO
	mov cx, 11 				;filename length
	cld
	repe cmpsb 				;check root directory for presence IBMBIO.COM
	jnz short print_non_system_disk_msg
	mov di, 20h 			;32 length of root dir entry
	mov si, IBMDOS
	mov cx, 11 				;file name length
	repe cmpsb 				;check root directory for presence IBMDOS.COM
	jnz short print_non_system_disk_msg

func_ret:
	ret

;------------------------------------------------------------------

print_non_system_disk_msg:

	mov si, non_system_disk_msg
	call print_msg

	mov ah, 0
	int 16h
	stc

	ret

;------------------------------------------------------------------

;convert logical sector to chs for disk read
logical2chs:
	push ds
	push cs
	pop ds
	xor dx, dx
	div word [SectorsPerTrack] 	;physical sector = logical sector % sectors per track
								;AX = logical sector for start root dir
								;AX % SectorsPerTrack = DX remainder (physical sector)
	inc dl 								;physical sectors start at 1
	mov [PhysicalSectorToRead], dl 		;store physical sector we calculated
	xor dx, dx
	div word [Sides]		;head = (start logical sector / SectorsPerTrack) % NumHeads
							;AX = (start logical sector / SectorsPerTrack)
							;AX % NumHeads = heads
	mov [HeadToRead], dl 	;which head/side
	mov [TrackToRead], ax  	;which track							
	pop ds
	ret

;------------------------------------------------------------------

read_sectors:
	mov dx, cs:[TrackToRead]
	mov cl, 6
	shl dh, cl 			;shl 6 = mul 64
	or dh, cs:[PhysicalSectorToRead]
	mov cx, dx 			;CL = sector to read, CH = track to read
	xchg ch, cl
	mov dx, cs:[DriveAndHead]		;DL = drive to read, DH = head to read
	int 13h
	ret

;------------------------------------------------------------------
;DATA SECTION
	 	 		
	StartUserDataVal	dw	 0			

	non_system_disk_msg db 13, 10, "Non-System disk or disk error",0Dh,0Ah,"Replace and strike any key when ready",0Dh,0Ah,0

	disk_error_msg db 13, 10, "Disk Boot Failure", 13, 10, 0
		
	IBMBIO 		db "ibmbio  com"
	IBMDOS		db "ibmdos  com"

; ------------------------------------------------------------------
; END OF BOOT SECTOR

	times 510-($-$$) db 0	;padding of boot sector
	dw 0AA55h				;signature determines boot sector
