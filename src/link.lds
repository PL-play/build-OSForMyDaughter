OUTPUT_FORMAT("elf64-x86-64") /* 设置输出文件格式为64位 ELF */
ENTRY(start)    /* 定义程序的入口点为 start */
SECTIONS
{
    . = 0x200000;   /* 将内核的起始地址设为 0x200000 */
    .text : {
        *(.text)    /* 代码段*/
    }

    .rodata : {

        *(.rodata)  /* 只读数据段 */
    }

    . = ALIGN(16);  /*确保数据段的地址对齐到16字节*/
    .data : {
        *(.data)    /* 已初始化的数据段 */
    }

    .bss : {    
        *(.bss)     /*未初始化的数据段*/
    }



}