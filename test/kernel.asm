[BITS 64]
[ORG 0x200000]

start:    
    mov rdi, idt_start          ; 将Idt 表的起始地址加载到 rdi 寄存器中，rdi 在此用作指针
    mov rax, handler0           ; 将中断处理程序 handler0 的地址加载到 rax 中
    ; 分几步将 handler0 地址存入 IDT 的第一个条目
    mov [rdi], ax               ; 将 handler0 的低 16 位写入 Idt 表的第一个条目的 Offset [15:0]
    shr rax, 16                 ; 右移 16 位，将 handler0 的中间 16 位移入低位
    mov [rdi+6], ax             ; 将 handler0 的中间 16 位写入 Offset [31:16]
    shr rax, 16                 ; 再次右移 16 位，以获得 handler0 的高 32 位
    mov [rdi+8], eax            ; 将 handler0 的高 32 位写入 Offset [63:32]


    ; 设置idt第32条，即timer
    mov rax, timer
    add rdi, 32*16
    mov [rdi], ax               ; 将 handler0 的低 16 位写入 Idt 表的第一个条目的 Offset [15:0]
    shr rax, 16                 ; 右移 16 位，将 handler0 的中间 16 位移入低位
    mov [rdi+6], ax             ; 将 handler0 的中间 16 位写入 Offset [31:16]
    shr rax, 16                 ; 再次右移 16 位，以获得 handler0 的高 32 位
    mov [rdi+8], eax            ; 将 handler0 的高 32 位写入 Offset [63:32]

    lidt [idt_descriptor]       ; 加载 IDT 表
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


    push 8                      ; 将代码段选择子 8 压入栈中。这里的 8 是在GDT中定义的代码段选择子，表示64位代码段
    push kernel_entry           ; 将标签 kernel_entry 的地址压入栈中，表示要跳转到的目标地址
    db 0x48                     ; 这一步插入字节 0x48，表示下一条指令是远返回（retf）所需的字节数。这里 0x48 是操作码（OpCode），没有特别含义，只是为了和 retf 配合使用
    retf                        ; 远返回指令。远返回会从栈中弹出代码段选择子（8）和指令指针 kernel_entry，然后跳转到 kernel_entry 标签处。这一步的作用是切换到新的代码段（64位模式代码段）并跳转到内核入口。

kernel_entry:
    mov rsi, message            ; 加载字符串地址到 RSI
    mov rdi, 0                  ; 行数
    mov rcx, 0                  ; 列数
    call print_string           ; 调用打印函数

    ; xor rbx,rbx                 ; 测试除0异常
    ; div rbx



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

switch_user_mode:
    ; 在 x86-64 架构中，为了从内核态（Ring 0）切换到用户态（Ring 3），需要将5 个 8 字节数据（总共 40 字节）压入栈中。
    ; 这些数据包括用户态的段选择子和状态信息，用于恢复用户态的执行环境。下面逐一解释这些数据的含义和作用。

    ; 1. 压栈的数据结构
    ; 从低地址到高地址依次为：

    ; RIP（指令指针寄存器）
    ; CS（代码段选择子）
    ; RFLAGS（标志寄存器）
    ; RSP（栈指针寄存器）
    ; SS（栈段选择子）
    ; 逐项解释

    ; RIP（Instruction Pointer，指令指针寄存器）
    ; 长度：8 字节。
    ; 作用：RIP 寄存器保存即将执行的指令的地址。在从内核态切换到用户态时，RIP 中的值会指定用户态的代码从哪里开始执行。
    ; 用途：在切换到用户态时，RIP 的值会被恢复为用户态代码的入口地址，确保切换后在正确的位置继续执行。
    
    ; CS（Code Segment Selector，代码段选择子）
    ; 长度：8 字节。
    ; 作用：CS 寄存器保存代码段选择子，指定当前的代码段及其特权级。
    ; 特权级：在用户态中，CS 的低两位必须设置为 3，表示 Ring 3 的特权级。
    ; 用途：切换到用户态后，CS 确保代码段具有用户态权限，防止用户态代码执行具有内核权限的操作。

    ; RFLAGS（Flags Register，标志寄存器）
    ; 长度：8 字节。
    ; 作用：RFLAGS 保存当前的标志状态，包含了条件标志（如进位、零标志等）和控制标志（如中断使能标志等）。
    ; 用途：在特权级切换时，RFLAGS 的状态会被恢复，从而保持中断状态和其他控制位的正确性。

    ; RSP（Stack Pointer，栈指针寄存器）
    ; 长度：8 字节。
    ; 作用：RSP 指向当前栈的顶部，用户态代码使用该值作为其栈基址。
    ; 用途：从内核态切换到用户态时，RSP 设置为用户态栈顶地址，确保切换后用户态代码的栈操作不会影响内核栈。

    ; SS（Stack Segment Selector，栈段选择子）
    ; 长度：8 字节。
    ; 作用：SS 寄存器指定栈段选择子，指向用户态的数据段。
    ; 特权级：SS 必须是用户态的段选择子（低两位为 3），以确保用户态栈段权限是用户态的。
    ; 用途：切换到用户态后，SS 确保栈的访问在用户态权限范围内，防止用户态代码访问内核栈段。

    ; 切换过程的原理
    ; 在从 Ring 0 切换到 Ring 3 的过程中，需要通过 iretq 指令恢复 RIP、CS、RFLAGS、RSP 和 SS 的值，从而将控制权转交给用户态。
    ; iretq 指令会从栈中弹出这 5 个 8 字节数据，恢复用户态的执行环境，保证代码在用户态下执行，并且使用用户态的栈和权限。

    ; RIP 和 CS：确保指令流在用户态执行，并且限制在用户态代码段。
    ; RFLAGS：恢复标志寄存器状态，保持中断状态和控制标志的一致性。
    ; RSP 和 SS：确保用户态的栈在正确的位置，并且具有用户态的特权级。
    ; 切换到用户态的过程    
    push 0x18 | 3       ; 将 0x18 | 3 压入栈中.这里 0x18 是用户态的栈段选择子，3 表示用户态的特权级（Ring 3）.0x18 | 3 的结果就是设置了特权级 3 的用户栈段选择子，用于在用户态栈段中指向用户态的栈
    push 0x7c00         ; 将 0x7c00 压入栈中.这是用户态的栈顶地址，用于在切换到用户态后初始化用户态的栈指针（rsp）。

    push 0x202          ; 63....9....1 0   bit
                        ; 0 ....1....1 0   =  0x202.
                        ; 第9位设置为1表示中断被启用。当返回到user_entry后，中断被启用
                        ; 将 0x202 压入栈中.这里 0x202 是要加载到标志寄存器 RFLAGS 中的值，通常用于设置或清除特定的标志位

    push 0x10 | 3       ; 将 0x10 | 3 压入栈中.0x10 是用户态的代码段选择子，3 表示用户态的特权级（Ring 3）,这样可以确保切换后进入用户态代码段（cs 寄存器会被更新为用户态的代码段选择子）
    push user_entry     ; 用户态代码的入口地址，在切换到用户态后会从该地址开始执行代码
    iretq               ; iretq 是 x86-64 架构中用于恢复中断时上下文的指令，它会从栈中弹出 RIP、CS、RFLAGS、RSP 和 SS 的值，完成特权级的切换
                        ; 通过执行 iretq，CPU 会将栈中的这 5 个值弹出到对应的寄存器中，从而完成从内核态到用户态的切换，并将控制权转移到 user_entry 处执行
                        
end:
    hlt                         ; 停止 CPU（可根据需要调整其他代码）
    jmp end


user_entry:
    ; mov ax, cs      ; 将 cs（代码段选择子）寄存器的值加载到 ax 中,cs 低两位包含当前的特权级（CPL），值为 3 表示用户态，值为 0 表示内核态
    ; and al, 11b     ; 保留了 cs 的低 2 位，得到当前的特权级
    ; cmp al, 3       ; 将 al 中的特权级与 3 进行比
    ; jne uend        ; 如果 al 中的特权级不是 3（即不处于用户态），则跳转到 UEnd 标签



    ; mov rsi, user_mode_msg        ; 打印输出
    ; mov rdi, 9
    ; mov rcx, -16
    ; call print_string 

    inc byte[0xb8004]
    mov byte[0xb8005], 0xf
   
uend:
    jmp user_entry        ; 如果不在用户态，则跳转到 uend，说明切换失败


handler0:
    ; 保存上下文
    push rax
    push rbx
    push rcx 
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11 
    push r12
    push r13
    push r14
    push r15


    mov rsi, divide_by_0        ; 打印输出
    mov rdi, 0
    mov rcx, 0
    call print_string 

    jmp end

    ; 恢复
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx 
    pop rbx
    pop rax


    iretq                   ; 返回到中断前的程序位置，这是 64 位模式下的中断返回指令


timer:
    ; 保存上下文
    push rax
    push rbx
    push rcx 
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11 
    push r12
    push r13
    push r14
    push r15

    inc byte[0xb8000]
    mov byte[0xb8001], 0xe

    mov al,0x20         ; 将 0x20 载入 al 寄存器。0x20 是 PIC 中的 EOI 命令，用于通知 PIC 当前的中断处理已完成。
    out 0x20,al         ; 将 al 寄存器中的值（即 0x20）输出到端口 0x20。端口 0x20 是主 PIC 的控制端口，发送 EOI 命令到该端口后，主 PIC 会将该中断的状态标记为结束，允许再次触发同类型的中断。

    ; 恢复
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx 
    pop rbx
    pop rax

    iretq

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


idt_start:
    %rep 256            ; DT 的起始地址。使用 %rep 256 定义了 256 个条目，因为 x86 架构中 IDT 表最多包含 256 个中断向量
        dw 0            ; 设置中断处理程序的低 16 位偏移量为 0
        dw 0x8          ; 选择子（Selector），通常为内核代码段的段选择子
        db 0            ; 保留字节，通常设置为 0
        db 0x8e         ; 设置属性字段，其中 0x8e 表示这是一个中断门，具有特定的特权级和存在位
        dw 0            ; 初始化高位偏移量为 0（即高 32 位）
        dd 0
        dd 0
    %endrep
idt_end:

idt_descriptor:
    dw idt_end-idt_start-1
    dq idt_start

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