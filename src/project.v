/*
 * Khatam-V : a RISC-V game console on one Tiny Tapeout chip
 *
 *   cpu.v    RV32E + multiply, runs C code
 *   qspi.v   code from SPI flash, RAM in SPI PSRAM (QSPI Pmod)
 *   gpu.v    VGA graphics: khatam star patterns + sprites + collisions
 *   audio.v  2 square voices + noise
 *
 * Memory map
 *   0x0000000  flash   (16 MB, read only, program starts at 0)
 *   0x1000000  PSRAM   (8 MB)
 *   0x2000000  I/O
 *      000-0FF  gpu registers           (write)
 *      0C0      FRAME   frame counter   (read)
 *      0C4      LINE    [9:0] current line, [16] vblank (read)
 *      0C8      COLLIDE collision flags (read, write anything to clear)
 *      0D0      BUTTONS ui_in           (read)
 *      0E0-0EF  audio registers         (write)
 *
 * Pins
 *   ui_in      8 buttons
 *   uo_out     TinyVGA pmod
 *   uio[0]     flash CS        uio[4]  IO2 (held high)
 *   uio[1]     MOSI            uio[5]  IO3 (held high)
 *   uio[2]     MISO            uio[6]  PSRAM CS
 *   uio[3]     SCK             uio[7]  audio out (PWM)
 *
 * While rst_n is low every uio pin is an input, so something else (like the
 * RP2040 on the demo board) can program the flash.
 */

`default_nettype none

module tt_um_khatam_v (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  // ---------------- CPU ----------------
  wire [25:0] mem_addr;
  wire [31:0] mem_wdata;
  wire [2:0]  mem_size;
  wire        mem_we;
  wire        mem_req;
  wire [31:0] mem_rdata;
  wire        mem_done;

  cpu cpu0 (
      .clk      (clk),
      .rst_n    (rst_n),
      .mem_addr (mem_addr),
      .mem_wdata(mem_wdata),
      .mem_size (mem_size),
      .mem_we   (mem_we),
      .mem_req  (mem_req),
      .mem_rdata(mem_rdata),
      .mem_done (mem_done)
  );

  wire is_io  = mem_addr[25];
  wire is_ram = mem_addr[24];

  // ---------------- flash + PSRAM ----------------
  wire [31:0] spi_rdata;
  wire        spi_done;
  wire        sck, mosi, cs_flash, cs_ram;

  qspi spi0 (
      .clk     (clk),
      .rst_n   (rst_n),
      .req     (mem_req && !is_io),
      .we      (mem_we),
      .ram     (is_ram),
      .addr    (mem_addr[23:0]),
      .wdata   (mem_wdata),
      .size    (mem_size),
      .rdata   (spi_rdata),
      .done    (spi_done),
      .sck     (sck),
      .mosi    (mosi),
      .miso    (uio_in[2]),
      .cs_flash(cs_flash),
      .cs_ram  (cs_ram)
  );

  // ---------------- I/O ----------------
  wire io_req = mem_req && is_io;
  reg  io_done;
  reg  [31:0] io_rdata;
  reg  [7:0]  buttons;
  wire io_wr = io_req && mem_we && !io_done;

  wire [15:0] frame;
  wire [9:0]  line;
  wire        vblank;
  wire [11:0] collide;
  wire [5:0]  rgb;
  wire        hsync, vsync;
  wire        audio_out;

  always @(posedge clk) begin
    if (!rst_n) begin
      io_done <= 0;
    end else begin
      buttons <= ui_in;
      io_done <= io_req && !io_done;
    end
  end

  always @(*) begin
    case (mem_addr[7:0])
      8'hC0:   io_rdata = {16'd0, frame};
      8'hC4:   io_rdata = {15'd0, vblank, 6'd0, line};
      8'hC8:   io_rdata = {20'd0, collide};
      8'hD0:   io_rdata = {24'd0, buttons};
      default: io_rdata = 0;
    endcase
  end

  gpu gpu0 (
      .clk    (clk),
      .rst_n  (rst_n),
      .wr     (io_wr && mem_addr[7:5] != 3'b111),   // everything below 0xE0
      .waddr  (mem_addr[7:0]),
      .wdata  (mem_wdata),
      .rgb    (rgb),
      .hsync  (hsync),
      .vsync  (vsync),
      .frame  (frame),
      .line   (line),
      .vblank (vblank),
      .collide(collide)
  );

  audio audio0 (
      .clk  (clk),
      .rst_n(rst_n),
      .wr   (io_wr && mem_addr[7:4] == 4'hE),
      .waddr(mem_addr[3:0]),
      .wdata(mem_wdata),
      .pwm  (audio_out)
  );

  assign mem_rdata = is_io ? io_rdata : spi_rdata;
  assign mem_done  = is_io ? io_done  : spi_done;

  // ---------------- pins ----------------
  // TinyVGA pmod: rgb = {R1, R0, G1, G0, B1, B0}
  assign uo_out = {hsync, rgb[0], rgb[2], rgb[4], vsync, rgb[1], rgb[3], rgb[5]};

  assign uio_out = {audio_out, cs_ram, 1'b1, 1'b1, sck, 1'b0, mosi, cs_flash};
  assign uio_oe  = rst_n ? 8'b1111_1011 : 8'b0000_0000;

  wire _unused = &{ena, uio_in[7:3], uio_in[1:0], 1'b0};

endmodule
