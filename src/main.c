#include "stdint.h"
#include "stddef.h"

void kernel_main(void) {
    char* p = (char*) 0xb8010;

    *p = 'C';
    *(p+1)=  0xe;
}