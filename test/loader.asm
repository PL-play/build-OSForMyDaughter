[BITS 16]
[ORG 0x7E00]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax              ; Initialize ES to 0
    mov ss, ax
    mov sp, 0x7C00          ; Set up stack
    mov [driveid], dl       ; Save drive ID
    call check_long_mode    ; Check for long mode support
    call get_memory_info    ; Print memory map
    call test_a20           ; Test a20
    jmp load_kernel         ; Load the kernel


check_long_mode:
    mov si, long_mode_test_msg
    call print_string
    o32 mov eax, 0x80000000         ; 将 0x80000000 加载到 EAX 寄存器，这是 CPUID 指令的一个特定调用号，用于查询支持的扩展功能级别
    cpuid
    o32 cmp eax, 0x80000001         ; 比较 eax 的值与 0x80000001。如果 eax 小于 0x80000001，说明 CPU 不支持该扩展级别
    jb print_long_mode_err_msg  ;
    o32 mov eax, 0x80000001
    cpuid
    test edx,(1<<29)            ; 测试 EDX 寄存器的第29位是否为1。这一位表示CPU是否支持长模式（64位模式）。(1<<29) 表示将第29位设置为1
    jz print_long_mode_err_msg  ; 如果 eax 小于 0x80000001，跳转到 print_long_mode_err_msg 标签，表示该CPU不支持这些扩展功能
    ret


check_huge_page:
    mov eax, 0x80000001
    cpuid
    test edx,(1<<26)
    jz print_huge_page_err_msg
    ret

get_memory_info:
    mov si, meminfo_start_msg
    call print_string
    
    mov ax, 0
    mov es, ax              ; Ensure ES is 0
    xor ebx, ebx        ; EBX = 0 to start
    mov eax, 0xE820 
    mov edx, 0x534D4150 ; 'SMAP'
    mov ecx, 20         ; Buffer size
    mov edi, 0x9000     ; EDI points to buffer at 0x9000
    int 0x15            ; BIOS call
    jc print_meminfo_err_msg

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
    mov eax, 0xE820 
    mov edx, 0x534D4150 ; 'SMAP'
    mov ecx, 20         ; Buffer size
    mov edi, 0x9000     ; EDI points to buffer at 0x9000
    int 0x15            ; BIOS call
    jc iter_return

    ; Check if more entries are available
    test ebx, ebx       ; EBX is continuation value
    jnz iter_mem_map        ; If EBX != 0, continue
    
iter_return:
    ret


test_a20:
    mov si, a20_test_msg
    call print_string
    mov ax, 0xffff
    mov es, ax
    mov word[0x7c00], 0xa200
    cmp word[es:0x7c10], 0xa200
    jne test_a20_ret
    mov word[0x7c00], 0xb200
    cmp word[es:0x7c10], 0xb200
    je print_a20_disabled_msg

test_a20_ret:
    ret


load_kernel:
    mov si, ReadPacket           ; 将 SI 寄存器指向 ReadPacket 数据包
    mov word[si], 0x10           ; 设置数据包大小为16字节（0x10）
    mov word[si+2], 100          ; 读取 100 个扇区
    mov word[si+4], 0            ; offset
    mov word[si+6], 0x1000       ; segment. 0x1000:0 = 0x1000*16+0=0x10000
    mov dword[si+8], 1           ; 读取的起始LBA地址为1（从磁盘第一个扇区开始）
    mov dword[si+0xc], 0         ; LBA地址的高32位设为0（仅支持32位LBA的情况）
    mov dl, [driveid]            ; 将驱动器ID加载到 DL（如0x80代表第一个硬盘）
    mov ah, 0x42                 ; 设置AH寄存器为0x42，表示扩展磁盘读操作
    int 0x13                     ; 调用 BIOS 磁盘服务中断
    jc print_read_kernel_err_msg ; 如果Carry Flag被设置，则读取失败，跳转到 print_read_kernel_err_msg
    

print_msg:
    mov si, msg          ; 将消息的地址加载到 SI 
    jmp next_char        ; 输出消息

print_long_mode_err_msg:
    mov si, long_mode_err_msg   ; 将消息的地址加载到 SI 
    jmp next_char               ; 输出消息

print_huge_page_err_msg:
    mov si, huge_page_err_msg   ; 将消息的地址加载到 SI 
    jmp next_char               ; 输出消息

print_read_kernel_err_msg:
    mov si, read_kernel_err_msg   ; 将消息的地址加载到 SI 
    jmp next_char               ; 输出消息

print_meminfo_err_msg:
    mov si, meminfo_err_msg   ; 将消息的地址加载到 SI 
    jmp next_char    

print_a20_disabled_msg:
    mov si, a20_disabled_msg   ; 将消息的地址加载到 SI 
    jmp next_char    

next_char:
    lodsb                ; 加载 SI 寄存器指向的字符到 AL，并递增 SI
    or al, al            ; 检查是否是空字符（字符串结尾）
    jz end               ; 如果是，则跳转到 end
    mov ah, 0x0E         ; 使用 BIOS 中断 0x10 的 0x0E 功能：显示字符
    mov bh, 0            ; 页号
    mov bl, 0x07         ; 字符颜色（灰色）
    int 0x10             ; 调用 BIOS 中断
    jmp next_char        ; 显示下一个字符

end:
    hlt                  ; 停止 CPU
    jmp end              ; 无限循环

; 子程序：打印分隔符（例如逗号和空格）
print_separator:
    mov ah, 0x0E
    mov al, ','                     ; 分隔符可以换成其他符号，如空格或分号
    int 0x10
    mov al, ' '                     ; 打印一个空格
    int 0x10
    ret

; 子程序：打印换行符
print_newline:
    mov ah, 0x0E
    mov al, 0x0D                      ; 回车
    int 0x10
    mov al, 0x0A                      ; 换行
    int 0x10
    ret

print_string:
    lodsb                ; 从 [SI] 加载一个字节到 AL，并递增 SI
    or al, al            ; 检查是否是空字符（字符串结尾）
    jz .done             ; 如果是，则跳转到 done，表示打印结束
    mov ah, 0x0E         ; 使用 BIOS 中断 0x10 的 0x0E 功能：显示字符
    int 0x10             ; 调用 BIOS 显示字符
    jmp print_string     ; 继续打印下一个字符
.done:
    ret


driveid: db 0  ; 定义驱动器id
msg: db "Start Loader Process", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
long_mode_test_msg: db "Long mode test", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
long_mode_err_msg: db "Long mode not supported", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
huge_page_err_msg: db "1G page not supported", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
meminfo_err_msg: db "Get memory info not supported", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
meminfo_start_msg: db "Get memory map", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
read_kernel_err_msg: db "Read kernel error", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
a20_test_msg: db "A20 line test", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
a20_disabled_msg: db "A20 line is disabled", 0ah, 0dh ,0 ; 定义消息，0 表示字符串结束
ReadPacket: times 16 db 0           ; 定义结构体16字节
hex_digits: db "0123456789ABCDEF"  ; 十六进制字符集



