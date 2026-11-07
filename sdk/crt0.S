# startup code
.section .text.start
.global _start
_start:
    li   sp, 0x1800000      # top of the psram
    call main
1:  j    1b
