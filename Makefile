.PHONY: all clean static exec

all: auxv

auxv: auxv.o
	gcc -nostartfiles auxv.o -o auxv
	strip --strip-all auxv

static: auxv.o
	gcc -no-pie -nostartfiles auxv.o -o auxv_static
	strip --strip-all auxv_static

exec: static

auxv.o: auxv.asm
	fasm auxv.asm

clean:
	rm -f auxv.o auxv auxv_static
