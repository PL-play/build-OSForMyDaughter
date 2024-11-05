[BITS 16]
[ORG 0x7e00]



start:
    call print_string
    mov [DriveId],dl

    mov eax,0x80000000
    cpuid
    cmp eax,0x80000001
    jb NotSupport

    call print_string

    mov eax,0x80000001
    cpuid
    test edx,(1<<29)
    jz NotSupport
    
    call print_string

LoadKernel:
    
    mov si,ReadPacket
    mov word[si],0x10
    mov word[si+2],100
    mov word[si+4],0
    mov word[si+6],0x1000
    mov dword[si+8],6
    mov dword[si+0xc],0
    mov dl,[DriveId]
    mov ah,0x42
    int 0x13
    jc  ReadError


    mov si,ReadPacket
    mov word[si],0x10
    mov word[si+2],10
    mov word[si+4],0
    mov word[si+6],0x4000
    mov dword[si+8],126
    mov dword[si+0xc],0
    mov dl,[DriveId]
    mov ah,0x42
    int 0x13
    jc  ReadError

GetMemInfoStart:
    mov eax,0xe820
    mov edx,0x534d4150
    mov ecx,20
    mov dword[0x9000],0
    mov edi,0x9008
    xor ebx,ebx
    int 0x15
    jc NotSupport

GetMemInfo:
    add edi,20
    inc dword[0x9000]   
    test ebx,ebx
    jz GetMemDone

    mov eax,0xe820
    mov edx,0x534d4150
    mov ecx,20
    int 0x15
    jnc GetMemInfo


GetMemDone:
TestA20:
    mov ax,0xffff
    mov es,ax
    mov word[ds:0x7c00],0xa200
    cmp word[es:0x7c10],0xa200
    jne SetA20LineDone
    mov word[0x7c00],0xb200
    cmp word[es:0x7c10],0xb200
    je End
    
SetA20LineDone:
    xor ax,ax
    mov es,ax

SetVideoMode:
    mov ax,3
    int 0x10
    
    cli
    lgdt [Gdt32Ptr]
    lidt [Idt32Ptr]

    mov eax,cr0
    or eax,1
    mov cr0,eax

    jmp 8:PMEntry

ReadError:
NotSupport:
End:
    hlt
    jmp End

print_string:
    mov si, msg 
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


DriveId:    db 0
ReadPacket: times 16 db 0

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

    

msg: db "111- ", 0 ; 定义消息，0 表示字符串结束