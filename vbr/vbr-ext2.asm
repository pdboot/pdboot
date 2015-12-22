[BITS 16]
base equ 0x1600
temp_base equ 0x7c00
[ORG base]

; Disable interrupts during initialization
cli

; Initialize segment registers
mov ax,(temp_base - base) >> 4
mov fs,ax
xor ax,ax
mov es,ax
mov ss,ax
mov sp,temp_base   ; temporary stack below VBR
cld

; Save MBR info and disk ID
; Via stack, to ensure we don't eg. overwrite lba_length when copying lba_start
push dword[ds:si+12]
push dword[ds:si+8]
mov ds,ax
; Zero out data section
mov di,data
mov cx,base - data
rep stosb
pop dword[boot_data.lba_start_low]
pop dword[boot_data.lba_length_low]
mov byte[boot_data.disk_id],dl

; New stack below data section, where we actually want it to be
mov sp,data

; Allow interrupts
; See http://forum.osdev.org/viewtopic.php?p=236455#p236455 for more information
sti

; Check BIOS LBA extensions exist
mov ah,0x41
mov bx,0x55aa
int 0x13
mov bp,no_lba_extensions
jc fatal_error
cmp bx,0xaa55
jnz fatal_error

; Read remained of VBR and first sector of superblock
; Set up packet
mov cx,3
mov di,base
mov eax,[boot_data.lba_start_low]
xor edx,edx
; Read sectors
call read_sectors_to_di

; Jump to the relocated VBR
jmp 0:relocated
relocated:

; Now we're relocated, fs should be 0 to make fatal_error work
xor ax,ax
mov fs,ax

; Check validity of ext2 filesystem
mov bp,invalid_ext2
; Check for the ext2 signature.
cmp word[sb.ext2_sig],0xef53
jnz fatal_error
; Check that the block size is <= 32KB.
mov eax,dword[sb.log_block_size]
cmp eax,5 ; log_block_size = 5 => block_size = 32KB, the maximum this bootloader supports
ja fatal_error
; Check that the fragment size is equal to the block size.
cmp eax,dword[sb.log_fragment_size]
jnz fatal_error
; Check that the superblock is in the block we expect.
; If the block size is 1k, the superblock is in block 1.
; If the block size is 2k or larger, the superblock is in block 0.
cmp eax,edx ; eax still has log_block_size in it, edx is still 0
ja blocks_larger_than_1k
inc edx
blocks_larger_than_1k:
cmp edx,dword[sb.superblock_block]
jnz fatal_error
; Check that inodes per group is not too large for the inode bitmap to
; fit in a single block.
mov cl,al ; al still has log_block_size in it
add cl,13 ; number of bits in a block = 2^(log_block_size + 13)
mov eax,dword[sb.inodes_per_group]
dec eax
shr eax,cl
cmp eax,0 ; inodes_per_group <= 2^cl iff (inodes_per_group-1)>>cl == 0
jnz fatal_error

; Check major version >=1 fields
mov dl,7 ; 128-byte inode
cmp dword[sb.major_version],1
ja fatal_error
jb .not_v1
mov ax,word[sb.inode_size]
cmp ax,128
jz .inode_size_check_done
inc dl
cmp ax,256
jz .inode_size_check_done
inc dl
cmp ax,512 ; cope with up to 512-byte inodes
jnz fatal_error
.inode_size_check_done:
mov eax,dword[sb.required_features]
test eax,0xfffffffd ; only directory typing (0x02) is supported
jnz fatal_error
.not_v1:
mov byte[log_inode_size],dl

; Check that inodes per group is a multiple of the number of inodes
; that fit in one block.
mov eax,dword[sb.inodes_per_group]
mov cl,byte[log_inode_size]
sub cl,byte[sb.log_block_size] ; log_block_size has been checked to be <= 5
sub cl,2
shl eax,cl
cmp al,0
jnz fatal_error

; Calculate starting block of the block group descriptor table
mov eax,dword[sb.superblock_block]
inc eax
call get_sector_from_block
mov dword[bgd_start_low],eax
mov dword[bgd_start_high],edx

; Calculate sectors per block
mov ax,2
mov cl,byte[sb.log_block_size] ; log_block_size has been checked to be <= 5
shl ax,cl
mov word[sectors_per_block],ax
shl ax,5
mov word[paragraphs_per_block],ax
shl ax,4
movzx eax,ax
mov dword[bytes_per_block],eax

; Load stage 2
mov eax,5 ; inode number of bootloader
call read_inode

; Set up boot data and jump to 2nd stage bootloader.
cmp byte[sb.major_version],1
jnz no_uuid
mov cx,16
mov di,boot_data.uuid
mov si,sb.file_system_id
rep movsb
no_uuid:
mov si,boot_data
jmp 0x0000:0x2000

; Input:  fs:bp = pointer to '!'-terminated error message
; Output: Error message is written to screen
;         Function never returns
fatal_error:
mov ah,0x0e     ; BIOS teletype
mov bx,0x0007   ; page 0, grey-on-black
mov al,[fs:bp]  ; get next char
int 0x10        ; output
inc bp
cmp al,'!'      ; check for end of string
jnz fatal_error
hang:
; Bochs magic breakpoint, for unit testing purposes.
; It can safely be left in release, as it is a no-op.
xchg bx,bx
sti
hlt
jmp hang

; Input:  0000:di = pointer to read to
;         edx:eax = LBA address to use
;         cx = number of sectors to read
; Output: Sectors have been read
;         Top 16 bits of edi are cleared
;         All other registers preserved
read_sectors_to_di:
movzx edi,di
mov dword[lba_packet.offset],edi

; Input:  lba_packet.offset and lba_packet.segment set up
;         edx:eax = LBA address to use
;         cx = number of sectors to read
; Output: Sectors have been read
;         All registers preserved
read_sectors:
o32 pusha
mov word[lba_packet.size],0x10
mov word[lba_packet.sectors],cx
mov dword[lba_packet.lba_low],eax
mov dword[lba_packet.lba_high],edx
mov cx,3
.try_read:
mov ah,0x42
mov dl,[boot_data.disk_id]
mov si,lba_packet
int 0x13
jnc .success
mov ah,0
int 0x13
loop .try_read
mov bp,disk_read_error
jmp fatal_error
.success:
o32 popa
ret

no_lba_extensions:        db "BIOS does not support LBA extensions!"
disk_read_error:          db "Error reading disk!"
invalid_ext2:             db "Invalid or unsupported ext2 filesystem!"

; Padding and boot signature
times 510-($-$$) db 0
dw 0xaa55

out_of_low_memory:        db "Out of low memory!"
missing_bootloader:       db "Bootloader is missing or empty!"

; Input:  eax = inode number
; Output: File contents written to 0x02000
;         si = byte offset of the inode within sector read at inode_table
;         Assume all other registers destroyed
read_inode:
; Get the BGD number
dec eax
xor edx,edx
mov ebx,dword[sb.inodes_per_group]
div ebx
; eax now contains the BGD number, and edx the inode number within the block group
mov bx,0x000f
and bx,ax
shr eax,4 ; 16 BGD entries per 512 byte sector
shl bx,5  ; 32 bytes per BGD entry
; eax now contains the sector offset of the BGD within the BGD table
;  bx now contains the byte offset of the BGD within that sector

push edx ; inode number within block group

; Calculate absolute sector of BGD
mov edx,dword[bgd_start_high]
add eax,dword[bgd_start_low]
adc edx,0
; Read in the sector of the block group descriptor table
mov cx,1
mov di,bgd_table
call read_sectors_to_di

mov eax,dword[bgd_table + bx + bgd.inode_table] ; starting block of inode table
call get_sector_from_block

pop ebx ; inode number within block group
; Effect of this code, where i = inode number and l = log of inode size:
;  si = (bottom 9-l bits of i) << l
; ebx = i >> (9-l)
; This is much the same algorithm as getting the BGD near the beginning of
; read_inode, but more complicated because inodes have variable size.
mov cx,0xff09
sub cl,byte[log_inode_size]
shl ch,cl
not ch
and ch,bl
shr ebx,cl
movzx si,ch
mov cl,byte[log_inode_size]
shl si,cl
; ebx now contains the sector offset of the inode within the inode table
;  si now contains the byte offset of the inode within that sector

; Calculate absolute sector containing the inode
add eax,ebx
adc edx,0
; Read in the sector containing the inode
mov cx,1
mov di,inode_table
call read_sectors_to_di

; Check the file mode
mov bp,missing_bootloader
mov ax,word[inode_table + si + inode.mode]
cmp ax,0x8000 ; regular file
jnz fatal_error

; TODO if this extracted to a function that can read both files and directories,
; we might need to check the top 32 bits of the file size is 0.
int 0x12 ; BIOS get lower memory size
sub ax,8 ; first 8KB used by IVT and bootloader
movzx edx,ax
shl edx,10 ; Convert kb -> bytes
mov eax,dword[inode_table + si + inode.file_size_lower]
test eax,eax
jz fatal_error
mov bp,out_of_low_memory
cmp eax,edx
ja fatal_error

; Read direct blocks
mov bx,0x0200
mov di,inode_table + inode.direct0
add di,si
mov cx,12
call read_blocks
jae .done

; Read indirect block
mov eax,dword[inode_table + si + inode.indirect]
call read_indirect_block
jae .done

; Read doubly indirect block
mov eax,dword[inode_table + si + inode.dbl_indirect]
call get_sector_from_block
mov cx,1
mov di,indirect_block
call read_sectors_to_di
mov eax,dword[di]
push dword[di + 4]
call read_indirect_block
pop eax
; If we're not done, call read_indirect_block using a jump
; ie. read_indirect_block will return to our return address.
jnae read_indirect_block

.done:
ret

; Input:  eax = block number of indirect block
;         si = byte offset of the inode withing inodeTable
;         bx = segment to read to
; Output: blocks read to bx:0000
;         bytes_read updated
;         bx = next segment to read to
;         si = unchanged
;         flags = comparison between bytes read and file size
;         Assume all other registers destroyed
read_indirect_block:
call get_sector_from_block
mov cx,word[sectors_per_block]
.loop:
push cx
push eax
push edx
mov cx,1
mov di,indirect_block
call read_sectors_to_di
mov cx,128 ; 128 block pointers per sector of an indirect block
call read_blocks
pop edx
pop eax
pop cx
jae .done
pushf
add eax,1
adc edx,0
popf
loop .loop
.done:
ret

; Input:  di = pointer to array of block numbers
;         si = byte offset of the inode within inodeTable
;         cx = array size
;         bx = segment to read to
; Output: blocks read to bx:0000
;         bytes_read updated
;         bx = next segment to read to
;         si = unchanged
;         flags = comparison between bytes read and file size
;         Assume all other registers destroyed
read_blocks:
mov word[lba_packet.offset],0x0000
mov word[lba_packet.segment],bx
mov eax,[di]
call get_sector_from_block
push cx
mov cx,[sectors_per_block]
call read_sectors
pop cx
add di,4
add bx,word[paragraphs_per_block]
mov eax,dword[bytes_read]
add eax,dword[bytes_per_block]
mov dword[bytes_read],eax
cmp eax,dword[inode_table + si + inode.file_size_lower]
jae .done
loop read_blocks
.done:
ret

; Input:  eax     = block number
; Output: bp      = invalid_ext2
;         edx:eax = sector number
get_sector_from_block:
mov bp,invalid_ext2
test eax,eax
jz fatal_error
push cx
; Calculate number of sectors from beginning of partition
xor edx,edx
mov cl,byte[sb.log_block_size] ; log_block_size has been checked to be <= 5
inc cl
shld edx,eax,cl
; Partition length is a 32-bit value, so if edx is not zero, we're definitely past the end.
jnz fatal_error
shl eax,cl
; Check we're not beyond the end of the partition
cmp eax,dword[boot_data.lba_length_low]
jae fatal_error
; Add on the sector number of the beginning of the
; partition to give an absolute sector number
add eax,dword[boot_data.lba_start_low]
adc edx,0
pop cx
ret

times 1024-($-$$) db 0

struc data,0x15b0
  ; Packet used in BIOS LBA read
  lba_packet:
    .size             resw 1
    .sectors          resw 1
    .offset           resw 1
    .segment          resw 1
    .lba_low          resd 1 ; low 32 bits
    .lba_high         resd 1 ; high 32 bits
  ; Boot data passed to 2nd stage bootloader
  boot_data:
    .lba_start_low:   resd 1
    .lba_start_high:  resd 1
    .lba_length_low:  resd 1
    .lba_length_high: resd 1
    .uuid:            resb 16
    .disk_id:         resb 1
  ; Other variables used in this bootloader
  log_inode_size:     resb 1
  alignb 2
  sectors_per_block:  resw 1
  paragraphs_per_block:resw 1
  alignb 4
  bgd_start_low:      resd 1
  bgd_start_high:     resd 1
  bytes_per_block:    resd 1
  bytes_read:         resd 1
  times base-($-$$)   resb 1 ; ensure data doesn't go past base
endstruc

struc sb,base+0x400 ; superblock
  .total_inodes         resd 1
  .total_blocks         resd 1
  .reserved_blocks      resd 1 ; reserved for superuser
  .unused_blocks        resd 1
  .unused_inodes        resd 1
  .superblock_block     resd 1 ; block number containing the superblock
  .log_block_size       resd 1 ; log2(block size in bytes) - 10
  .log_fragment_size    resd 1 ; log2(fragment size in bytes) - 10
  .blocks_per_group     resd 1 ; blocks in each block group
  .fragments_per_group  resd 1 ; fragments in each block group
  .inodes_per_group     resd 1 ; inodes in each block group
  .last_mount_time      resd 1
  .last_write_time      resd 1
  .mounts_since_fsck    resw 1
  .max_mounts_before_fsck resw 1
  .ext2_sig             resw 1
  .state                resw 1
  .error_action         resw 1
  .minor_version        resw 1
  .last_fsck_time       resd 1
  .max_time_before_fsck resd 1
  .operating_system_id  resd 1
  .major_version        resd 1
  .superuser_uid        resw 1
  .superuser_gid        resw 1
; Major version >= 1 only
  .first_nonreserved_inode resd 1
  .inode_size           resw 1 ; in bytes
  .block_group          resw 1 ; block group this superblock is in
  .optional_features    resd 1
  .required_features    resd 1
  .readonly_features    resd 1
  .file_system_id       resb 16
  .volume_name          resb 16
  .last_mount_path      resb 64
  .compression_alg      resd 1
  .file_preallocate_blocks resb 1
  .dir_preallocate_blocks resb 1
                        resb 2 ; unused
  .journal_id           resb 16
  .journal_inode        resd 1
  .journal_device       resd 1
  .orphan_inode_list    resd 1
endstruc

indirect_block equ base+0x600
bgd_table equ base+0x600

struc bgd ; block group descriptor
  .block_usage_bitmap   resd 1 ; block address
  .inode_usage_bitmap   resd 1 ; block address
  .inode_table          resd 1 ; block address
  .unused_blocks        resw 1
  .unused_inodes        resw 1
  .directories          resw 1 ; number of directories
endstruc

inode_table equ base+0x800

struc inode
  .mode                 resw 1 ; type & permissions
  .uid                  resw 1
  .file_size_lower      resd 1 ; low 32 bits of file size
  .atime                resd 1
  .ctime                resd 1
  .mtime                resd 1
  .dtime                resd 1 ; deletion
  .gid                  resw 1
  .hard_links           resw 1
  .disk_sectors         resd 1 ; number of disk sectors (not blocks) used by the file
  .flags                resd 1
  .os_specific_1        resb 4
  .block_pointers:
    .direct0            resd 1
    .direct1            resd 1
    .direct2            resd 1
    .direct3            resd 1
    .direct4            resd 1
    .direct5            resd 1
    .direct6            resd 1
    .direct7            resd 1
    .direct8            resd 1
    .direct9            resd 1
    .direct10           resd 1
    .direct11           resd 1
    .indirect           resd 1
    .dbl_indirect       resd 1
    .tri_indirect       resd 1
  .generation           resd 1 ; aparently "primarily used for NFS"?
  .acl                  resd 1 ; for major_version >= 1, ACL block
  .file_size_higher_acl resd 1 ; for major_version >= 1, high 32 bits of file size for files, ACL block for directories
  .fragment             resd 1 ; block address
  .os_specific_2        resb 12
endstruc
