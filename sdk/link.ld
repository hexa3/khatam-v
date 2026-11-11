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
    *(.srodata*)
  } > FLASH

  .data : {
    _data_start = .;
    *(.data*)
    *(.sdata*)
    _data_end = .;
  } > RAM AT > FLASH
  _data_load = LOADADDR(.data);

  .bss (NOLOAD) : {
    _bss_start = .;
    *(.bss*)
    *(.sbss*)
    *(COMMON)
    _bss_end = .;
  } > RAM

  _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
