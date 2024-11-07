[BITS 64]
[ORG 0x200000]

start:    
    lgdt [gdt64_descriptor]     ; 加载64位模式的GDT表指针
    push 8                      ; 将代码段选择子 8 压入栈中。这里的 8 是在GDT中定义的代码段选择子，表示64位代码段
    push kernel_entry           ; 将标签 kernel_entry 的地址压入栈中，表示要跳转到的目标地址
    db 0x48                     ; 这一步插入字节 0x48，表示下一条指令是远返回（retf）所需的字节数。这里 0x48 是操作码（OpCode），没有特别含义，只是为了和 retf 配合使用
    retf                        ; 远返回指令。远返回会从栈中弹出代码段选择子（8）和指令指针 kernel_entry，然后跳转到 kernel_entry 标签处。这一步的作用是切换到新的代码段（64位模式代码段）并跳转到内核入口。

kernel_entry:
    mov rsi, message            ; 加载字符串地址到 RSI
    mov rdi, 9                  ; 行数
    mov rcx, 0                  ; 列数
    call print_string           ; 调用打印函数
end:
    hlt                         ; 停止 CPU（可根据需要调整其他代码）
    jmp end

print_string:
    ; 输入: RSI - 指向要打印的字符串
    ;       RDI - 起始行数
    ;       RCX - 起始列数

    mov rbx, 0xB8000            ; 显存的起始地址
    shl rdi, 7                  ; 行数 * 80 * 2 = rdi << 7 (128) 计算行偏移
    add rbx, rdi                ; 将行偏移加到显存基址
    shl rcx, 1                  ; 列数 * 2，计算列偏移
    add rbx, rcx                ; 将列偏移加到地址

.next_char:
    lodsb                       ; 从 [RSI] 加载一个字节到 AL，并递增 RSI
    test al, al                 ; 检查是否是空字符（字符串结尾）
    jz .done                    ; 如果是空字符（0），结束打印
    mov [rbx], al               ; 将字符写入显存位置
    mov byte [rbx + 1], 0x0A    ; 设置颜色（亮绿色）
    add rbx, 2                  ; 每个字符占用2字节，移动到下一个字符位置
    jmp .next_char              ; 循环处理下一个字符

.done:
    ret                         ; 返回

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


message db "Welcome to My Operating System!", 0  ; 要打印的字符串，以 0 结尾