[BITS 64]
[ORG 0x200000]

start:    
    mov rsi, message            ; 加载字符串地址到 RSI
    mov rdi, 9                  ; 行数
    mov rcx, 0                  ; 列数
    call print_string           ; 调用打印函数

    hlt                         ; 停止 CPU（可根据需要调整其他代码）

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



message db "Welcome to My Operating System!", 0  ; 要打印的字符串，以 0 结尾