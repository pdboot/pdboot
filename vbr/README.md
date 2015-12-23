# vbr-ext2: public domain VBR for ext2

This VBR reads inode 5 (`EXT2_BOOT_LOADER_INO`) to 0x2000 and jumps to it.

## Preconditions

* VBR is loaded to the physical addres 0x7c00
* dl contains the disk ID the system was booted from
* ds:si points to the partition entry the VBR was loaded from

## Postconditions

* If loading was successful
  - Inode 5 from the ext2 filesystem is loaded to the physical address 0x2000
  - ds:si points to a data structure with the following information:
```
struct boot_data {
  uint64_t lba_start;  // LBA start of the partition
  uint64_t lba_length; // LBA length of the partition
  char uuid[16];       // ext2 UUID of the partition
  char disk_id;        // BIOS disk ID the partition is on
};
```

* If loading was unsuccessful
  - Error message is displayed on screen
  - System hangs

## Errors

This VBR will output an error message and hang if:

* The BIOS does not support LBA extensions
* The ext2 filesystem is invalid
  - Signature missing
  - Superblock block number incorrect
  - Inodes per group is too large for the inode bitmap to fit in one block
  - Inodes per group is not a multiple of the number of inodes per block
  - References to blocks past the end of the partition
* The ext2 filesystem is unsupported
  - Block size larger than 32KiB
  - Fragment size different to block size
  - Inode size larger than 512 bytes
  - Required features other than directory typing are enabled
  - Bootloader is sparse
* The bootloader inode is invalid or too large
  - Not a regular file
  - File size is zero
  - Too large to fit in low memory
* The disk cannot be read
