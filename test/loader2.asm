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

    call swith_protected_mode



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
    cli
    lgdt [Gdt32Ptr]
    lidt [Idt32Ptr]

    mov eax,cr0
    or eax,1
    mov cr0,eax

    jmp 8:PMEntry

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
ReadError:
NotSupport:
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
PMEntry:
    mov ax,0x10
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,0x7c00

    mov byte[0xb8000], 'P'   ; 尝试在屏幕上打印字符 'P'
    mov byte[0xb8001], 0xa  ; 设置字符属性


PEnd:
    hlt
    jmp PEnd




Gdt32:
    dq 0
Code32:
    dw 0xffff
    dw 0
    db 0
    db 0x9a
    db 0xcf
    db 0
Data32:
    dw 0xffff
    dw 0
    db 0
    db 0x92
    db 0xcf
    db 0
    
Gdt32Len: equ $-Gdt32

Gdt32Ptr: dw Gdt32Len-1
          dd Gdt32

Idt32Ptr: dw 0
          dd 0


Gdt64:
    dq 0
    dq 0x0020980000000000

Gdt64Len: equ $-Gdt64


Gdt64Ptr: dw Gdt64Len-1
          dd Gdt64

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