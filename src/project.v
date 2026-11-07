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

  // cpu
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

  wire is_ram = mem_addr[24];

  // flash + psram
  wire        sck, mosi, cs_flash, cs_ram;

  qspi spi0 (
      .clk     (clk),
      .rst_n   (rst_n),
      .req     (mem_req),
      .we      (mem_we),
      .ram     (is_ram),
      .addr    (mem_addr[23:0]),
      .wdata   (mem_wdata),
      .size    (mem_size),
      .rdata   (mem_rdata),
      .done    (mem_done),
      .sck     (sck),
      .mosi    (mosi),
      .miso    (uio_in[2]),
      .cs_flash(cs_flash),
      .cs_ram  (cs_ram)
  );

  wire [5:0] rgb;
  wire       hsync, vsync;

  gpu gpu0 (
      .clk  (clk),
      .rst_n(rst_n),
      .sw   (ui_in[5:0]),
      .rgb  (rgb),
      .hsync(hsync),
      .vsync(vsync)
  );

  // tinyvga pmod: R1 G1 B1 vs R0 G0 B0 hs
  assign uo_out = {hsync, rgb[0], rgb[2], rgb[4], vsync, rgb[1], rgb[3], rgb[5]};

  // uio: 0 flash cs, 1 mosi, 2 miso, 3 sck, 4+5 io2/io3 (held high), 6 psram cs
  assign uio_out = {1'b0, cs_ram, 1'b1, 1'b1, sck, 1'b0, mosi, cs_flash};
  assign uio_oe  = 8'b1111_1111;

  wire _unused = &{ena, ui_in[7:6], uio_in[7:3], uio_in[1:0], 1'b0};

endmodule
