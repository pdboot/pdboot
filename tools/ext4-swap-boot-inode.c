#include <asm-generic/ioctl.h>
#include <fcntl.h>
#include <stdio.h>

/* This is not part of any official headers, as it is internal to the kernel. */
#define EXT4_IOC_SWAP_BOOT _IO('f', 17)

int main(int argc, char *argv[])
{
  int fd, err;

  if (argc != 2) {
    printf("usage: ext4-swap-boot-inode FILE-TO-SWAP\n");
    return 1;
  }

  fd = open(argv[1], O_RDWR);

  if (fd < 0) {
    perror("open");
    return 1;
  }

  err = ioctl(fd, EXT4_IOC_SWAP_BOOT);
  if (err < 0) {
    perror("ioctl");
    return 1;
  }

  close(fd);
  return 0;
}
