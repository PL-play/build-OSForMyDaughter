[BITS 16]
[ORG 0x7e00]



start:
    call set_video_mode

    mov si, empty_msg
    call print_string

    mov si, text_mode_msg
    call print_string

    mov si, msg
    call print_string

    mov [driveid],dl

    mov si, long_mode_test_msg
    call print_string

    call check_long_mode
    
    call load_kernel

    mov si, load_kernel_msg
    call print_string

    call get_memory_info
    mov si, meminfo_msg
    call print_string

    call test_a20
    mov si, a20_test_msg
    call print_string

    jmp swith_protected_mode

    


check_long_mode:
    mov eax, 0x80000000         ; 将 0x80000000 加载到 EAX 寄存器，这是 CPUID 指令的一个特定调用号，用于查询支持的扩展功能级别
    cpuid
    cmp eax, 0x80000001         ; 比较 eax 的值与 0x80000001。如果 eax 小于 0x80000001，说明 CPU 不支持该扩展级别
    jb long_mode_test_error  ;
    mov eax, 0x80000001
    cpuid
    test edx,(1<<29)            ; 测试 EDX 寄存器的第29位是否为1。这一位表示CPU是否支持长模式（64位模式）。(1<<29) 表示将第29位设置为1
    jz long_mode_test_error               ; 如果 eax 小于 0x80000001，跳转到 print_long_mode_err_msg 标签，表示该CPU不支持这些扩展功能
    ret

set_video_mode:
    mov si, text_mode_msg
    call print_string
    mov ax, 3           ; 将寄存器 AX 设置为 3。这表示将视频模式设置为 80x25 的文本模式，具有 16 种颜色
    int 0x10            ; 调用 BIOS 中断 0x10，用于视频服务。这里用来设置指定的视频模式
    ; mov si, text_mode_msg
    ; call print_string
    
;     mov si, text_mode_msg   ; 将 SI 寄存器设置为消息的地址，text_mode_msg 是字符串数据的起始位置
;     mov ax, 0xb800          ; 将 AX 设置为 0xB800，这是文本模式下的显存段地址
;     mov es, ax              ; 将 ES 段寄存器设置为 0xB800，表示显存段
;     xor di, di              ; 将 DI 寄存器清零，用于存储显存的偏移地址
;     mov cx, text_mode_msg_len   ;将 CX 寄存器设置为消息的长度，作为循环计数器

; print_set_video_msg:
;     mov al, [si]                ; 将 SI 所指向的消息字符加载到 AL 寄存器中
;     mov [es:di], al             ; 将 AL 中的字符写入显存的 ES:DI 位置，这样字符就会显示在屏幕上
;     mov byte [es:di+1], 0xa     ; 将颜色属性 0xA（亮绿色）写入显存的下一个字节，用于设置字符的颜色

;     add di, 2                   ; 将 DI 增加 2，指向显存中的下一个字符位置（每个字符占用两个字节：一个用于字符本身，一个用于颜色）
;     add si, 1                   ; 将 SI 增加 1，指向消息的下一个字符
;     loop print_set_video_msg    ; CX 寄存器递减，如果 CX 不为零，则继续循环
;     call print_newline
    ret

load_kernel:
    mov si, ReadPacket           ; 将 SI 寄存器指向 ReadPacket 数据包
    mov word[si], 0x10           ; 设置数据包大小为16字节（0x10）
    mov word[si+2], 100          ; 读取 100 个扇区
    mov word[si+4], 0            ; offset
    mov word[si+6], 0x1000       ; segment. 0x1000:0 = 0x1000*16+0=0x10000
    mov dword[si+8], 6           ; 读取的起始LBA地址为6（从磁盘第7个扇区开始），因为MBR在以第一个扇区，loader本身占5个扇区，内核将在第7个扇区
    mov dword[si+0xc], 0         ; LBA地址的高32位设为0（仅支持32位LBA的情况）
    mov dl, [driveid]            ; 将驱动器ID加载到 DL（如0x80代表第一个硬盘）
    mov ah, 0x42                 ; 设置AH寄存器为0x42，表示扩展磁盘读操作
    int 0x13                     ; 调用 BIOS 磁盘服务中断
    jc  read_kernel_error        ; 如果Carry Flag被设置，则读取失败，跳转到 print_read_kernel_err_msg
    ret


get_memory_info:
    mov eax,0xe820
    mov edx,0x534d4150          ; 'SMAP'
    mov ecx,20                  ; Buffer size
    mov dword[0x9000],0         ; EDI points to buffer at 0x9000
    mov edi,0x9008
    xor ebx,ebx                 ; EBX = 0 to start
    int 0x15                    ; BIOS call
    jc get_memory_info_error
                                ; ECX 返回结构
                                ; Offset | Size  | Description
                                ; -------|-------|-----------------------
                                ; 0x00   | 8     | 基地址（Base Address）
                                ; 0x08   | 8     | 长度（Length）
                                ; 0x10   | 4     | 类型（Type）
                                ; 0x14   | 4     | 扩展属性（Extended Attributes, 可选）

                                ; 4 字节表示内存区域的类型，确定该区域的用途和可用性。常见的类型包括：
                                ; 1：可用内存（Usable）。操作系统可以使用的普通 RAM。
                                ; 2：保留内存（Reserved）。不可用于操作系统的 RAM，通常被硬件或 BIOS 占用。
                                ; 3：ACPI 可回收内存（ACPI Reclaimable）。用于 ACPI 表格的内存，可以在操作系统启动后释放。
                                ; 4：ACPI NVS（Non-Volatile Storage）。用于保存 ACPI 的非易失性存储数据，操作系统不能使用。
                                ; 5：坏内存（Bad Memory）。被检测为存在错误的内存区域，不应该被操作系统使用。
                                ; 扩展属性（Extended Attributes）（4字节，可选）：

                                ; 有些 BIOS 版本可能会返回这个字段，用于描述额外的内存属性。通常情况下这个字段被忽略或设为 0。
                                ; 标准的 0xE820 调用返回的结构体仅包含上述的 20 字节内容，如果有扩展属性，它会出现在返回结构的后面。


iter_mem_map:
    add edi,20
    inc dword[0x9000]           ; EDI points to buffer at 0x9000
    test ebx,ebx                ; Check if more entries are available
    jz GetMemDone               ; If EBX != 0, continue

    mov eax,0xe820  
    mov edx,0x534d4150          ; 'SMAP'
    mov ecx,20
    int 0x15
    jnc iter_mem_map

GetMemDone:
    ret

test_a20:
    mov ax,0xffff
    mov es,ax
    mov word[ds:0x7c00],0xa200          ; 0:0x7c00 = 0 * 16 + 0x7c00 = 0x7c00 ,使用随机数0xa200测试
    cmp word[es:0x7c10],0xa200          ; 0xffff:0x7c10 = 0xffff * 16 + 0x7c10 = 0x107c00
    jne test_a20_ret
    mov word[0x7c00],0xb200             ; 重复测试 
    cmp word[es:0x7c10],0xb200
    je test_a20_fail                              
                                                     ;  20                       0
                                                     ;  ^                        ^
                                                     ;  |                        | 
                                    ; 0x107c00    ->    1 0000 0111 1100 0000 0000
                                    ; 0x007c00    <-    0 0000 0111 1100 0000 0000 
    
test_a20_ret:
    xor ax,ax
    mov es,ax
    ret

swith_protected_mode:
    cli                         ; 禁用中断
    lgdt [gdt_descriptor]       ; 将GDT加载到GDTR寄存器中
    lidt [idt_descriptor]       ; 加载idt

    mov eax, cr0                ; 设置CR0寄存器的保护模式位来启用保护模式
    or eax, 0x1                 ; 设置CR0的保护模式位
    mov cr0, eax

    jmp 8:protected_mode_entry  ; 不能使用mov更新cs寄存器。

                                ; 00001 0 00b
                                ; ||||| | ||
                                ; ||||| | |+-- (Bit 0-1) RPL位
                                ; ||||| |+--- (Bit 2) TI，0表示GDT，1,LDT
                                ; |||||
                                ; ||||+----- (Bit 3-16) GDT索引

long_mode_test_error:
    mov si, long_mode_err_msg
    call print_string
    jmp End
read_kernel_error:
    mov si, read_kernel_err_msg
    call print_string
    jmp End
get_memory_info_error:
    mov si, meminfo_err_msg
    call print_string
    jmp End
test_a20_fail:
    mov si,a20_disabled_msg
    call print_string
    jmp End

End:
    hlt
    jmp End



print_string:
    lodsb                ; 加载 SI 寄存器指向的字符到 AL，并递增 SI
    or al, al            ; 检查是否是空字符（字符串结尾）
    jz end               ; 如果是，则跳转到 end
    mov ah, 0x0E         ; 使用 BIOS 中断 0x10 的 0x0E 功能：显示字符
    mov bh, 0            ; 页号
    mov bl, 0x07         ; 字符颜色（灰色）
    int 0x10             ; 调用 BIOS 中断
    jmp print_string        ; 显示下一个字符
end:
    ret

[BITS 32]
protected_mode_entry:
    mov ax, 0x10            ; 将段选择子 0x10（通常为数据段选择子）加载到 AX 寄存器中。0x10 应该指向 GDT 中的数据段描述符
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x7c00         ; 设置堆栈指针 ESP 为 0x7C00。在保护模式下，需要重新初始化堆栈指针，确保堆栈地址有效
    
    mov byte [0xb8000], 'P'   ; 尝试在屏幕上打印字符 'P'
    mov byte [0xb8001], 0x0a  ; 设置字符属性
    mov byte [0xb8002], 'M'   ; 尝试在屏幕上打印字符 'M'
    mov byte [0xb8003], 0x0a  ; 设置字符属性


switch_long_mode:
    ; 清空内存区域0x80000到0x90000，这是一个页面表（page table）的空间
    cld                         ; 清除方向标志位（DF），确保后续的字符串操作（如stosd）是自增操作，即从低地址到高地址写入数据
    mov edi, 0x80000            ; 将寄存器EDI设置为0x80000，即目标内存地址0x80000，这是将要初始化分页表的起始地址
    xor eax, eax                ; 将寄存器EAX置零（EAX=0），准备写入0值
    mov ecx, 0x10000 / 4        ; 将寄存器ECX设置为0x10000 / 4，表示将要写入的DWORD（32位）数量。0x10000字节除以4得到0x4000个DWORD
    rep stosd                   ; 重复将EAX的值（0）写入EDI指向的内存区域，共写入0x4000个DWORD，初始化内存区域0x80000到0x90000为0

    mov dword [0x80000], 0x81007    ;将值0x81007写入内存地址0x80000。这个值通常是一个页目录项（Page Directory Entry），指向下一级的页表地址0x81000
    mov dword [0x81000], 10000111b  ;将二进制值10000111b写入地址0x81000。这是一个页表项（Page Table Entry），表示映射的具体页面信息：
                                    ; 低三位111表示页面有效、可读写和用户级别权限。
                                    ; 高位10000表示特定页面的物理地址。

    lgdt [gdt64_descriptor]         ; 将GDT加载到GDTR寄存器中

    ; 启用PAE（Physical Address Extension）是启用64位模式的必要条件，因为它允许CPU使用4级页表结构，以支持超过32位地址空间的寻址
    mov eax, cr4            ; 将控制寄存器 CR4 的值加载到 EAX
    or eax, (1 << 5)        ; 设置 CR4 的第5位为1，即启用PAE
    mov cr4, eax            ; 将修改后的值写回 CR4

    ; 设置页目录基地址
    mov eax, 0x80000        ; 将页目录表的物理地址（这里为 0x80000）加载到 EAX
    mov cr3, eax            ; 将 EAX 的值加载到 CR3 中，设置页表的基地址。CR3 控制页表的根地址，长模式下的分页机制依赖CR3的内容来定位页表

    ; 启用EFER寄存器中的LME（Long Mode Enable）位
    mov ecx, 0xC0000080     ; 设置 ECX 为 0xC0000080，这是 EFER（Extended Feature Enable Register）寄存器的地址
    rdmsr                   ; 读取 EFER 的值到 EDX:EAX。EFER 是一个MSR（Model-Specific Register），包含启用长模式的标志
    or eax, (1 << 8)        ; 设置 EAX 的第8位为1，启用LME（Long Mode Enable）
    wrmsr                   ; 更新后的值写回 EFER，正式启用长模式支持（但还未进入长模式）
    ; 启用分页,分页是64位模式的基础，只有在分页开启的情况下，CPU才会真正进入长模式
    mov eax, cr0            ; 将 CR0 的值加载到 EAX
    or eax, (1 << 31)       ; 设置 EAX 的第31位为1，即启用分页
    mov cr0, eax            ; 将更新后的值写回 CR0，正式启用分页机制

    jmp 8:long_mode_entry   ; 通过远跳转加载代码段选择子，并跳转到 long_mode_entry 标签处

[BITS 64]
long_mode_entry:
    mov rsp, 0x7c00
    mov byte [0xb8004], 'L'   ; 尝试在屏幕上打印字符 'L'
    mov byte [0xb8005], 0x0a  ; 设置字符属性
    mov byte [0xb8006], 'M'   ; 尝试在屏幕上打印字符 'M'
    mov byte [0xb8007], 0x0a  ; 设置字符属性


halt:
    hlt
    jmp halt


gdt_start:
    dq 0x0000000000000000  ; 空描述符，GDT中的第一个描述符必须是空的
    code_segment:
        dw 0xFFFF          ; 段界限低16位
        dw 0x0000         ; 基地址低16位 0x7E00?
        db 0x00            ; 基地址中间8位
        db 10011010b       ; 访问权限位（可执行、只读、Ring 0特权级别）
                            ; 10011010b
                            ; ||||||||
                            ; |||||||+-- (Bit 0) Accessed 位：1表示段已被访问，0表示未被访问。CPU自动设置。
                            ; ||||||+--- (Bit 1) 可读/写位（对数据段是可写，对代码段是可读）：1表示允许读取，0表示不允许。
                            ; |||||+---- (Bit 2) DC 位（方向/一致性）：对于数据段，1表示向下扩展；对于代码段，1表示只允许相同特权级别调用。
                            ; ||||+----- (Bit 3) Executable 位：1表示代码段（可执行），0表示数据段。
                            ; |||+------ (Bit 4) Descriptor Type (S位)：1表示普通段（代码或数据），0表示系统段。
                            ; ||+------- (Bits 5-6) DPL (Descriptor Privilege Level) 特权级别：00表示Ring 0（最高特权级别）。
                            ; |+-------- (Bit 7) Present (P位)：1表示段有效，0表示段无效。
        db 11001111b       ; 段界限高4位和标志
                            ; 11001111b
                            ; ||||||||
                            ; ||||++++-- (Bits 0-3) 段界限的高4位
                            ; ||++------ (Bits 4-5) AVL (Available for system software)：可供系统软件使用，通常置0
                            ; |+-------- (Bit 6) L (Long)：1表示这是64位代码段（只在x86-64中有效），这里为0
                            ; +--------- (Bit 7) G (Granularity) 粒度位：1表示段界限以4KB为单位，0表示以字节为单位
        db 0x00             ; 基地址高8位
    data_segment:
        dw 0xFFFF          ; 段界限低16位
        dw 0x0000          ; 基地址低16位 0x7E00?
        db 0x00            ; 基地址中间8位
        db 10010010b       ; 访问权限位（可读、可写、Ring 0特权级别）
                            ; 10010010b
                            ; ||||||||
                            ; |||||||+-- (Bit 0) Accessed 位：1表示段已被访问，0表示未被访问。CPU自动设置。
                            ; ||||||+--- (Bit 1) 可读/写位（对数据段是可写，对代码段是可读）：1表示允许读取，0表示不允许。
                            ; |||||+---- (Bit 2) DC 位（方向/一致性）：对于数据段，1表示向下扩展；对于代码段，1表示只允许相同特权级别调用。
                            ; ||||+----- (Bit 3) Executable 位：1表示代码段（可执行），0表示数据段。
                            ; |||+------ (Bit 4) Descriptor Type (S位)：1表示普通段（代码或数据），0表示系统段。
                            ; ||+------- (Bits 5-6) DPL (Descriptor Privilege Level) 特权级别：00表示Ring 0（最高特权级别）。
                            ; |+-------- (Bit 7) Present (P位)：1表示段有效，0表示段无效。
        db 11001111b       ; 段界限高4位和标志
                            ; 11001111b
                            ; ||||||||
                            ; ||||++++-- (Bits 0-3) 段界限的高4位
                            ; ||++------ (Bits 4-5) AVL (Available for system software)：可供系统软件使用，通常置0
                            ; |+-------- (Bit 6) L (Long)：1表示这是64位代码段（只在x86-64中有效），这里为0
                            ; +--------- (Bit 7) G (Granularity) 粒度位：1表示段界限以4KB为单位，0表示以字节为单位

        db 0x00            ; 基地址高8位
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; GDT大小
    dd gdt_start                 ; GDT基地址

          
idt_descriptor: dw 0
                dd 0


gdt64_start:
    dq 0x0000000000000000  ; 空描述符，GDT中的第一个描述符必须是空的
    ccode_segment:
        dq 0x0020980000000000   
                                ; D L    P DPL 1 1 C
                                ; 0 1    1 00      0
                                ; Base（基址）：高32位和低32位均为0（0x000000000000），表示基址为0。在64位模式下，代码段的基址被忽略。
                                ; Limit（段界限）：高4位为0x0，低16位被省略，表示最大值，这在64位模式下同样被忽略。
                                ; DPL：00，表示最高权限级别（内核态）。
                                ; P：1，表示该段存在。
                                ; Type：1000，表示可执行代码段。
                                ; S：1，表示这是代码段。
                                ; L（长模式位）：1，表示这是一个64位代码段。
                                ; D/B：0，表示忽略该位。
                                ; G（粒度）：1，表示段界限以4KB为单位。
gdt64_end:


gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1     ; GDT的大小减1（因为GDT描述符需要大小-1）
    dq gdt64_start                     ; GDT的起始地址

driveid:    db 0
ReadPacket: times 16 db 0

empty_msg: db "", 0ah, 0dh, 0 ; 定义消息，0 表示字符串结束
msg: db "Start Loader Process", 0ah, 0dh, 0 ; 定义消息，0 表示字符串结束
text_mode_msg: db "Set up text mode",0ah, 0dh ,0

long_mode_test_msg: db "Long mode test", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
long_mode_err_msg: db "Long mode not supported", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束

read_kernel_err_msg: db "Read kernel error", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
load_kernel_msg: db "Load kernel", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束

meminfo_err_msg: db "Get memory info not supported", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
meminfo_msg: db "Get memory map", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束

a20_test_msg: db "A20 line test", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
a20_disabled_msg: db "A20 line is disabled", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束