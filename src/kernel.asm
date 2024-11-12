section .data
gdt64_start:
    dq 0x0000000000000000  ; 空描述符，GDT中的第一个描述符必须是空的
    code_segment:
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
        
        dq 0x0020F80000000000   ; D L    P DPL 1 1 C
                                ; 0 1    1 11      0
                                ; 用户态代码段描述符.该段的特权级为 3，即用户态
                                ; DPL = 3：该段的特权级为 3，即用户态
                                ; Type = 1011：表示该段为代码段，可执行、不可读
                                ; P = 1：该段存在且有效
                                ; L = 1：该段为 64 位代码段
                                ; D = 0：D 位在 64 位模式中被忽略

        dq 0x0000F20000000000   ;这是一个用户态数据段描述符。
                                ; DPL = 3：特权级为 3，即用户态。
                                ; Type = 0010：表示该段为数据段，可读可写。
                                ; P = 1：该段存在且有效。
                                ; L = 0：该段不作为代码段。
                                ; D = 0：D 位被忽略。

    tss_descriptor:
        dw tss_len-1 ; 段限长（Limit），设置为 tss_len - 1，表示 TSS 的长度减去 1。这个值用于限制 TSS 的访问范围
        dw 0        ; base address的低24位，暂时设为0, 后续赋值
        db 0        ; 
        db 0x89     ; 属性字段 P DPL TYPE
                    ;         1 00  01001 -> 表示64位tss

        db 0        ; 用于填充和对齐描述符字段  
        db 0
        dq 0


gdt64_end:


gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1     ; GDT的大小减1（因为GDT描述符需要大小-1）
    dq gdt64_start                     ; GDT的起始地址




tss:
    ; 定义 TSS 结构的起始地址。TSS 是一个存储与任务状态相关的数据结构，在 64 位模式下主要用于中断栈表（IST）和内核栈指针（RSP0 等）的管理
    dd 0            ; TSS 结构的第一个双字（4 字节）通常为保留字段
    dq 0x150000     ; 这是内核栈指针 RSP0 的值，指向内核栈的地址（例如 0x150000）。当从用户态切换到内核态时，CPU 会加载 RSP0 的值作为内核栈的起始地址
    times 88 db 0   ; 填充 TSS 的剩余字段，用 88 个字节的零来填充，以符合 TSS 的长度要求
    dd tss_len      ; 存储 TSS 的长度，便于后续设置描述符长度

tss_len: equ $-tss  ; 计算 TSS 的总长度（从 Tss 起始地址到当前位置），为后续的 GDT 描述符设置长度信息


message         db "   Welcome to My Operating System!", 0  ; 要打印的字符串，以 0 结尾
divide_by_0     db "Divided by 0                      ", 0  
timer_msg       db "T", 0  
user_mode_msg   db "Switched to User Mode", 0



section .text
extern kernel_main
global start

start:    
  
    lgdt [gdt64_descriptor]     ; 加载64位模式的GDT表指针


set_tss:
    ; 这部分代码将 TSS 的基地址写入到 TSS 描述符的相应位置中，以便 CPU 能够识别 TSS 在内存中的实际位置

    mov rax, tss                    ; 将 TSS 的基地址加载到 rax 寄存器中
    mov [tss_descriptor+2], ax      ; 将基地址的低 16 位写入 TssDesc+2 处
    shr rax, 16                     ; 右移 rax 16 位，以获取基地址的中间 8 位
    mov [tss_descriptor+4], al      ; 将基地址的中间 8 位写入 TssDesc+4
    shr rax, 8                      ; 继续右移 8 位，以获取基地址的更高 8 位
    mov [tss_descriptor+7], al      ; 将基地址的更高 8 位写入 TssDesc+7
    shr rax, 8                      ; 继续右移 8 位，以获取基地址的最高 32 位
    mov [tss_descriptor+8], eax     ; 将基地址的最高 32 位写入 TssDesc+8.将 
                                    ; TSS 的 64 位基地址分段写入 TSS 描述符的不同字段，从而在 GDT 中建立 TSS 描述符。
    ; 加载 TSS 描述符
    mov ax, 0x20        ;  GDT 中 TSS 描述符的选择子(第5条)加载到 ax 寄存器中
    ltr ax              ; 加载任务寄存器（Task Register）。ltr 指令会将选择子的内容加载到任务寄存器中，从而启用 TSS


   



init_PIT:
    ; 设置 PIT 模式
    mov al, (1<<2) | (3<<4)     ; 设置了控制字，用于配置 PIT 的工作模式 将 1 左移 2 位，结果为 0000 0100（二进制），表示选择 通道 0
                                ; 将 3 左移 4 位，结果为 0011 0000（二进制），表示 模式 3（方波生成模式）.控制字是 0011 0100，即 0x36

    out 0x43, al                ; 将控制字 0x36 输出到 0x43 端口。端口 0x43 是 PIT 的控制端口，用于设置定时器的工作模式。这里配置了通道 0，使其工作在模式 3 下，以便生成方波


    ; 设置定时时间
    mov ax, 11931       ; 将计数值 11931 加载到 ax 寄存器中.这个值决定了定时器的频率。PIT 的输入频率通常为 1.19318 MHz，通过设置计数值可以调整定时器的输出频率
    out 0x40, al        ; 将计数值的低 8 位输出到端口 0x40. 0x40 是通道 0 的数据端口，用于设置通道 0 的计数值
    mov al, ah          ; 将计数值的高 8 位存储到 al 寄存器中，准备输出
    out 0x40, al        ; 将计数值的高 8 位输出到端口 0x40，完成计数值的设置
                        ; PIT 的输入频率是 1.193182 MHz（也就是 1,193,182 Hz）。这个频率是固定的，由硬件生成
                        ; PIT 的计数器工作原理如下：
                        ; PIT 计数器从设定的计数值（比如这里的 11931）开始倒数，每次倒数到 0 时，计数器会重置并触发一个中断信号。
                        ; 计数值越大，倒数时间越长，触发中断的频率越低；计数值越小，倒数时间越短，触发中断的频率越高。


init_PIC:
    ;PIC 初始化过程通常需要 4 个初始化控制字（ICW1、ICW2、ICW3 和 ICW4）来配置各个参数，指定主从 PIC 的基址、中断映射关系和工作模式。
    ; 每个初始化控制字通过端口发送到主 PIC（0x20/0x21）和从 PIC（0xA0/0xA1）。
    
    ; 发送 ICW1：初始化命令.这一操作告诉主从 PIC 进入初始化模式，并期待接收接下来的 ICW2、ICW3 和 ICW4
    mov al, 0x11        ; 将 0x11 加载到 al 中,x11 表示的二进制是 00010001，这是 ICW1 的值。
                        ; 0x11 的具体含义：
                        ; 位 4 设为 1：表示这是一个初始化命令。
                        ; 位 0 设为 1：表示需要 ICW4。
    out 0x20, al        ; 将 al 的值写入端口 0x20，发送给主 PIC
    out 0xA0, al        ; 将 al 的值写入端口 0xA0，发送给从 PIC

    ; 发送 ICW2：中断向量基址
    mov al, 32          ; 将 32（十进制）加载到 al 中,0-31是系统中断向量，32开始自定义中断向量
    out 0x21, al        ; 将 al 的值写入端口 0x21，配置主 PIC 的中断基址,主 PIC 的 IRQ 0 到 IRQ 7 将映射到 IDT 的 0x20 到 0x27
    mov al, 40          ; 将 40（十进制）加载到 al 中
    out 0xA1, al        ; 将 al 的值写入端口 0xA1，配置从 PIC 的中断基址,从 PIC 的 IRQ 8 到 IRQ 15 将映射到 IDT 的 0x28 到 0x2F

    ; 发送 ICW3：主从关系
    mov al, 4           ; 主 PIC 需要知道从 PIC 连接在哪一条 IRQ 线上,这里设置 al 为 4，即二进制 00000100，表示从 PIC 连接到主 PIC 的 IRQ2
    out 0x21, al        ; 将 al 的值写入端口 0x21，告诉主 PIC 从 PIC 连接在 IRQ2
    mov al, 2           ; 从 PIC 需要知道它连接到主 PIC 的哪条线路,这里设置 al 为 2，即二进制 00000010，表示它连接到主 PIC 的 IRQ2
    out 0xA1, al        ; 将 al 的值写入端口 0xA1，配置从 PIC 的连接信息

    ; 发送 ICW4：附加配置
    mov al, 1           ; al 设置为 1，即二进制 00000001，表示 PIC 进入 8086/88 模式
    out 0x21, al        ; 将 al 的值写入端口 0x21，发送到主 PIC
    out 0xA1, al        ; 将 al 的值写入端口 0xA1，发送到从 PIC

    ; 配置 IMR（中断屏蔽寄存器）
    mov al, 11111110b   ; 示屏蔽主 PIC 上除了 IRQ0 之外的所有中断请求（IRQ0 通常用于系统定时器）
    out 0x21, al        ; 将 al 的值写入端口 0x21，更新主 PIC 的 IMR
    mov al, 11111111b   ; 表示屏蔽从 PIC 上的所有中断请求
    out 0xA1, al        ; 将 al 的值写入端口 0xA1，更新从 PIC 的 IMR
    ; 开启中断
    ; sti               
    
    push 8                      ; 将代码段选择子 8 压入栈中。这里的 8 是在GDT中定义的代码段选择子，表示64位代码段
    push kernel_entry           ; 将标签 kernel_entry 的地址压入栈中，表示要跳转到的目标地址
    db 0x48                     ; 这一步插入字节 0x48，表示下一条指令是远返回（retf）所需的字节数。这里 0x48 是操作码（OpCode），没有特别含义，只是为了和 retf 配合使用
    retf                        ; 远返回指令。远返回会从栈中弹出代码段选择子（8）和指令指针 kernel_entry，然后跳转到 kernel_entry 标签处。这一步的作用是切换到新的代码段（64位模式代码段）并跳转到内核入口。

kernel_entry:
    mov rsp, 0x20000            ; 将内核栈指针设置为0x20000，这是将在c代码中使用的新栈指针
    call kernel_main            ; 调用c函数
    
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




  