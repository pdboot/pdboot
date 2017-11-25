# pdboot: public domain bootloaders

**pdboot** is a collection of bootloaders that are in the public domain. Currently, the project
contains a Master Boot Record, and a Volume Boot Record for ext2, written by
Mark Raymond.

## Building

The bootloaders are written in NASM x86 assembly. On a Debian/Ubuntu based system, running

```
sudo apt-get install build-essential nasm
```

is sufficient to install everything needed to build pdboot. To build, run

```
make
```

in the root of this repository.

## Running the tests

The tests use Python 3, pytest and Bochs. To install pytest on a Debian/Ubuntu based system, run

```
sudo apt-get install python3-pytest
```

The version of Bochs in the package repositories usually isn't compiled with the debugging features
that pdboot tests use, so you will need to compile Bochs yourself. This configuration will work
with pdboot tests:

```
LIBS=-lpthread ./configure --enable-x86-64 --enable-smp --enable-all-optimizations --enable-vmx=2 --enable-svm --enable-avx --enable-evex --enable-usb --enable-usb-ohci --enable-ne2000 --enable-pnic --enable-e1000 --enable-debugger --disable-debugger-gui --with-nogui --without-x11
make
```

Once you have compiled Bochs, the test framework needs to know where to find it. This is done
through `tests/config.py`. `tests/default_config.py` provides a template for what this file should
look like. Then, running

```
make test
```

will run all the tests.
