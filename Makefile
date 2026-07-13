.PHONY: all clean static

all: auxv

auxv: auxv.o
	gcc -nostartfiles auxv.o -o auxv

static: auxv.o
	gcc -no-pie -nostartfiles auxv.o -o auxv_static

auxv.o: auxv.asm
	fasm auxv.asm

clean:
	rm -f auxv.o auxv auxv_static
