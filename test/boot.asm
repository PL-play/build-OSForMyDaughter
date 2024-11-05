[BITS 16]
[ORG 0x7C00]

start:
    xor ax, ax           ; 清空 AX
    mov ds, ax           ; 初始化数据段
    mov es, ax           ; 初始化额外段
    mov ss, ax           ; 初始化堆栈段
    mov sp, 0x7C00       ; 设置栈顶指针

test_disk_extension:
    mov [driveid], dl        ; 保存驱动器ID到变量 [DriveId] 中
    mov ah, 0x41             ; 设置 int 0x13 的功能号为 0x41，用于检测扩展磁盘服务支持
    mov bx, 0x55aa           ; BX 设为 0x55AA，作为调用的签名，用于验证
    int 0x13                 ; 调用BIOS磁盘服务中断，检测 扩展磁盘支持
    jc not_support           ; 如果CF标志位（Carry Flag）设置为1，则跳转到 not_support，表示不支持
    cmp bx, 0xaa55           ; 检查BX寄存器是否返回 0xAA55，如果不是，则表示不支持
    jne not_support          ; 如果BX不等于0xAA55，则跳转到 not_support，表示不支持

load_loader:
    mov si, ReadPacket           ; 将 SI 寄存器指向 ReadPacket 数据包
    mov word[si], 0x10           ; 设置数据包大小为16字节（0x10）
    mov word[si+2], 5            ; 读取 5 个扇区
    mov word[si+4], 0x7e00       ; 将数据读取到内存地址 0x7E00
    mov word[si+6], 0            ; 设置 ES 段寄存器为 0（目标段）
    mov dword[si+8], 1           ; 读取的起始LBA地址为1（从磁盘第一个扇区开始）
    mov dword[si+0xc], 0         ; LBA地址的高32位设为0（仅支持32位LBA的情况）
    mov dl, [driveid]            ; 将驱动器ID加载到 DL（如0x80代表第一个硬盘）
    mov ah, 0x42                 ; 设置AH寄存器为0x42，表示扩展磁盘读操作
    int 0x13                     ; 调用 BIOS 磁盘服务中断
    jc read_error                ; 如果Carry Flag被设置，则读取失败，跳转到 ReadError
    
    mov dl,[driveid]
    jmp 0x7e00            ; 跳转到加载的引导程序代码（0x7E00内存地址）


not_support:
read_error:
print_msg:
    mov si, msg          ; 将消息的地址加载到 SI
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

msg: db "Error in boot process!", 0 ; 定义消息，0 表示字符串结束
driveid: db 0                       ; 定义drive id
ReadPacket: times 16 db 0           ; 定义结构体16字节

times (0x1BE - ($ - $$)) db 0    ; 填充到分区表起始位置

    ; 分区表的第一个分区条目
    db 0x80                    ; 分区状态，0x80表示活动分区
    db 0, 2, 0                 ; 分区的起始 CHS（磁头/扇区/柱面）
    db 0xF0                    ; 起始柱面高位
    db 0xFF, 0xFF, 0xFF        ; 分区的结束 CHS
    dd 1                       ; 分区的起始LBA地址
    dd (20*16*63 - 1)          ; 分区的扇区数

times (16*3) db 0              ; 填充其他3个分区条目为0

    ; MBR 结束标志
    db 0x55
    db 0xAA
