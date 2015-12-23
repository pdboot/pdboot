# mbr: public domain MBR

This is a standard MBR, which loads the VBR of the active partition to 0x7c00 and jumps to it.

## Preconditions

* MBR is loaded to the physical address 0x7c00
* dl contains the disk ID the system was booted from

## Postconditions

* If loading was successful
  - VBR is loaded to the physical addres 0x7c00
  - dl contains the disk ID the system was booted from
  - ds:si points to the partition entry the VBR was loaded from

* If loading was unsuccessful
  - Error message is displayed on screen
  - System hangs

## Errors

This MBR will output an error message and hang if:

* There are no active partitions
* The active partition has a partition type of 0
* The BIOS does not support LBA extensions
* The disk cannot be read
* The VBR does not end with the boot signature (0xaa55)
