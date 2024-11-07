nasm -f bin -o boot.bin boot.asm
nasm -f bin -o loader.bin loader.asm
dd if=/dev/zero of=boot.img bs=512 count=6144
dd if=boot.bin of=boot.img bs=512 count=1 conv=notrunc
dd if=loader.bin of=boot.img bs=512 count=5 seek=1 conv=notrunc
qemu-system-x86_64 -drive file=boot.img,format=raw