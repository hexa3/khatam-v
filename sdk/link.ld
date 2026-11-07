/* flash at 0, ram at 0x1000000 */

MEMORY
{
  FLASH (rx)  : ORIGIN = 0x0000000, LENGTH = 16M
  RAM   (rwx) : ORIGIN = 0x1000000, LENGTH = 8M
}

ENTRY(_start)

SECTIONS
{
  .text : {
    *(.text.start)
    *(.text*)
    *(.rodata*)
  } > FLASH

  .data : { *(.data*) } > RAM
  .bss  : { *(.bss*) } > RAM
}
