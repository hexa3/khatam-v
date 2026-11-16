# tests for khatam-v
#
# the chip needs a flash to run anything, so SpiMem below pretends to be the
# QSPI pmod (flash on uio[0], psram on uio[6]). it only does what qspi.v uses:
# 0x03 read and 0x02 write, mode 0, 1 bit.
#
# these only use the pins, so the same tests run on the gate level netlist.

import cocotb
from cocotb.clock import Clock
from cocotb.utils import get_sim_time
from cocotb.triggers import ClockCycles, FallingEdge, First, RisingEdge

# hand assembled (clang -march=rv32e_zmmul, then objdump)
PROGRAM = [
    0x01000537,  # 00  lui   a0, 0x1000        a0 = psram
    0x123455B7,  # 04  lui   a1, 0x12345
    0x67858593,  # 08  addi  a1, a1, 0x678
    0x00B52023,  # 0c  sw    a1, 0(a0)         ram[0]  = 0x12345678
    0x00700613,  # 10  li    a2, 7
    0x00600693,  # 14  li    a3, 6
    0x02D60733,  # 18  mul   a4, a2, a3
    0x00E52223,  # 1c  sw    a4, 4(a0)         ram[4]  = 42
    0x00000613,  # 20  li    a2, 0
    0x00A00693,  # 24  li    a3, 10
    0x00D60633,  # 28  add   a2, a2, a3        <-
    0xFFF68693,  # 2c  addi  a3, a3, -1          |
    0xFE069CE3,  # 30  bnez  a3, 28            --
    0x00C52423,  # 34  sw    a2, 8(a0)         ram[8]  = 55
    0x00052703,  # 38  lw    a4, 0(a0)         read it back from the psram
    0x01075713,  # 3c  srli  a4, a4, 16
    0x00E51623,  # 40  sh    a4, 12(a0)        ram[12] = 0x1234
    0x020007B7,  # 44  lui   a5, 0x2000        a5 = io
    0x0D07A283,  # 48  lw    t0, 0xd0(a5)      buttons
    0x00550723,  # 4c  sb    t0, 14(a0)        ram[14] = ui_in
    0x0000006F,  # 50  j     50
]

BUTTONS = 0xA5


class SpiMem:
    def __init__(self, dut, flash):
        self.dut = dut
        self.flash = bytearray(flash)
        self.ram = bytearray(256)
        self.written = set()   # ram addresses the chip wrote

    async def run(self):
        dut = self.dut
        mem = None
        nbits = 0
        cmd_addr = 0
        byte = 0

        while True:
            await First(RisingEdge(dut.sck), FallingEdge(dut.sck),
                               RisingEdge(dut.flash_cs), RisingEdge(dut.ram_cs))

            # everything is X until reset gets to it
            if not all(s.value.is_resolvable for s in (dut.sck, dut.flash_cs, dut.ram_cs)):
                continue

            if dut.flash_cs.value == 1 and dut.ram_cs.value == 1:
                # nothing selected, next one starts from scratch
                mem = None
                nbits = 0
                continue

            if mem is None:
                mem = self.flash if dut.flash_cs.value == 0 else self.ram

            if dut.sck.value == 1:
                # rising: take a bit in
                # mosi is X during reads (it's shifting out whatever is in the
                # write data, the flash doesn't care), so only look at it for writes
                bit = 1 if dut.mosi.value == 1 else 0
                if nbits < 32:
                    cmd_addr = (cmd_addr << 1) | bit
                else:
                    byte = (byte << 1) | bit
                nbits += 1

                cmd = (cmd_addr >> 24) & 0xFF
                if cmd == 0x02 and nbits > 32 and (nbits - 32) % 8 == 0:
                    a = ((cmd_addr & 0xFFFFFF) + (nbits - 32) // 8 - 1) % len(mem)
                    mem[a] = byte & 0xFF
                    if mem is self.ram:
                        self.written.add(a)
            else:
                # falling: put the next bit out (reads only)
                cmd = (cmd_addr >> 24) & 0xFF
                if nbits >= 32 and cmd == 0x03:
                    d = nbits - 32
                    a = ((cmd_addr & 0xFFFFFF) + d // 8) % len(mem)
                    dut.miso.value = (mem[a] >> (7 - d % 8)) & 1


def program_bytes(words):
    out = bytearray()
    for w in words:
        out += w.to_bytes(4, "little")
    return out + bytes(256 - len(out))


async def start(dut, flash):
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())   # 25 MHz

    spi = SpiMem(dut, flash)
    cocotb.start_soon(spi.run())

    dut.ena.value = 1
    dut.ui_in.value = BUTTONS
    dut.miso.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)

    # in reset the uio pins should all be inputs so the rp2040 can get to the flash
    assert dut.uio_oe.value == 0, "uio pins should be inputs during reset"

    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    return spi


@cocotb.test()
async def test_cpu(dut):
    """runs PROGRAM out of the fake flash and checks what it wrote to the psram"""
    spi = await start(dut, program_bytes(PROGRAM))

    # ~50 instructions, each fetch is ~70 clocks. give it plenty
    for _ in range(200):
        await ClockCycles(dut.clk, 500)
        if 14 in spi.written:
            break
    else:
        assert False, f"program never finished, psram writes: {sorted(spi.written)}"

    ram = spi.ram
    word = lambda a: int.from_bytes(ram[a:a + 4], "little")

    assert word(0) == 0x12345678, f"lui/addi/sw: {word(0):#x}"
    assert word(4) == 42, f"mul: {word(4)}"
    assert word(8) == 55, f"loop: {word(8)}"
    assert ram[12] == 0x34 and ram[13] == 0x12, f"lw/srli/sh: {ram[12]:#x} {ram[13]:#x}"
    assert ram[14] == BUTTONS, f"buttons: {ram[14]:#x}"


@cocotb.test()
async def test_hsync(dut):
    """640x480: 800 clocks a line, hsync low for 96"""
    await start(dut, bytes(256))

    await FallingEdge(dut.hsync)
    t0 = get_sim_time("ns")
    await RisingEdge(dut.hsync)
    t1 = get_sim_time("ns")
    await FallingEdge(dut.hsync)
    t2 = get_sim_time("ns")

    low = (t1 - t0) / 40
    line = (t2 - t0) / 40
    assert low == 96, f"hsync pulse is {low} clocks"
    assert line == 800, f"line is {line} clocks"
