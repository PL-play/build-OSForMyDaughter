nasm -f bin -o boot.bin boot.asm
nasm -f bin -o loader.bin loader.asm
nasm -f elf64 -o kernel.o  kernel.asm

gcc -std=c11 -mcmodel=large -ffreestanding -fno-stack-protector -mno-red-zone -c main.c -o main.o
# -mcmodel=large：指定大内存模型，使编译器生成适合内核的大地址访问代码。
# -ffreestanding：告知编译器这个代码在一个“独立环境”中运行（无标准库）。
# -fno-stack-protector：禁用栈保护功能，以避免生成额外的代码用于检测栈溢出。
# -mno-red-zone：禁用64位下的“红色区域”，在操作系统内核中通常需要禁用该区域。
# 以上选项是为了确保编译的内核代码适合运行在裸机上，避免依赖操作系统功能和标准库

ld -nostdlib -T link.lds -o kernel kernel.o main.o 
# 使用自定义链接脚本link.lds将kernel.o和main.o链接成一个单独的ELF可执行文件kernel。
# -nostdlib：不使用标准库，避免链接标准C库函数。
# -T link.lds：指定使用自定义的链接脚本link.lds，从而对内核的内存布局进行精确控制。

objcopy -O binary kernel kernel.bin 
# 将链接生成的kernel文件转为二进制文件kernel.bin，以便写入磁盘映像中

dd if=/dev/zero of=boot.img bs=512 count=6144
dd if=boot.bin of=boot.img bs=512 count=1 conv=notrunc
dd if=loader.bin of=boot.img bs=512 count=5 seek=1 conv=notrunc
dd if=kernel.bin of=boot.img bs=512 count=100 seek=6 conv=notrunc
qemu-system-x86_64 -drive file=boot.img,format=raw