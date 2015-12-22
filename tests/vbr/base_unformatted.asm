[BITS 16]
[ORG 0x0600]

; This is a very basic MBR that doesn't use LBA extensions or retry reads.

; Clear interrupts during initialization
cli

; Initialize segment registers and stack
xor ax,ax
mov ds,ax
mov es,ax
mov ss,ax
mov sp,0x7c00

; Allow interrupts
; See http://forum.osdev.org/viewtopic.php?p=236455#p236455 for more information
sti

; Relocate the MBR
mov si,0x7c00       ; Set source and destination
mov di,0x0600
mov cx,0x0100       ; 0x100 words = 512 bytes
rep movsw           ; Copy mbr to 0x0600
jmp 0:relocated     ; Far jump to copied MBR

relocated:

; Search partitions for one with active bit set
mov si,partition_table
mov cx,4
test_active:
test byte[si+partition.status],0x80
jnz found_active
add si,entry_length
loop test_active
; If we get here, no active partition was found,
; so output and error message and hang
jmp fatal_error

; Found a partition with active bit set
found_active:
cmp byte[si+partition.type],0; check partition type, should be non-zero
jz fatal_error

; Load volume boot record
mov ax,0x0201                     ; function 2, read 1 sector
mov dh,[si+partition.start_chs]   ; head
mov cx,[si+partition.start_chs+1] ; cylinder+sector
mov bx,0x7c00                     ; read to es:bx = 0000:7c00
int 0x13                          ; BIOS disk read (dl already set to disk number)
jc fatal_error

cmp word[0x7dfe],0xaa55 ; check boot signature
jnz fatal_error
jmp 0x0000:0x7c00   ; if boot signature passes, we can jump,
                    ; as ds:si and dl are already set

fatal_error:
mov bp,error
jmp start_output

output_loop:
int 0x10        ; output
inc bp
start_output:
mov ah,0x0e     ; BIOS teletype
mov al,[bp]     ; get next char
cmp al,0        ; check for end of string
jnz output_loop
hang:
; Bochs magic breakpoint, for unit testing purposes.
xchg bx,bx
sti
hlt
jmp hang

error:     db "Error loading VBR for VBR test!",0

; Pad to the end of the code section
times 440-($-$$) db 0

sig:         dd 0x3e922d38
padding:     dw 0
partition_table:

struc partition
.start:
.status:     resb 1
.start_chs:  resb 3
.type:       resb 1
.end_chs:    resb 3
.start_lba:  resd 1
.length_lba: resd 1
.end:
endstruc

entry_length equ partition.end - partition.start

; Partition 1 at sector 8, length 1000
istruc partition
at partition.status,     db 0x80
at partition.start_chs,  db 0,9,0
at partition.type,       db 0x83
at partition.end_chs,    db 15,63,0
at partition.start_lba,  dd 8
at partition.length_lba, dd 1000
iend

; Partitions 2-4 empty
times (3*entry_length) db 0

; Boot signature
dw 0xaa55

; Pad disk image to 63 tracks, 16 heads (minimum Bochs allows)
times (16*63*512)-($-$$) db 0
