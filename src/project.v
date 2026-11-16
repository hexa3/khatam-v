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

  wire is_io  = mem_addr[25];
  wire is_ram = mem_addr[24];

  // flash + psram
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

  // io
  wire        io_req  = mem_req && is_io;
  reg         io_done;
  wire        io_wr   = io_req && mem_we && !io_done;
  reg  [31:0] io_rdata;
  reg  [7:0]  buttons;

  always @(posedge clk) begin
    if (!rst_n) begin
      io_done <= 0;
    end else begin
      buttons <= ui_in;
      io_done <= io_req && !io_done;
    end
  end

  wire [15:0] frame;
  wire [9:0]  line;
  wire        vblank;
  wire [11:0] collide;
  wire [5:0]  rgb;
  wire        hsync, vsync;
  wire        audio_out;

  always @(*) begin
    case (mem_addr[7:0])
      8'hC0:   io_rdata = {16'd0, frame};
      8'hC4:   io_rdata = {15'd0, vblank, 6'd0, line};
      8'hC8:   io_rdata = {20'd0, collide};
      8'hD0:   io_rdata = {24'd0, buttons};
      default: io_rdata = 0;
    endcase
  end

  assign mem_rdata = is_io ? io_rdata : spi_rdata;
  assign mem_done  = is_io ? io_done  : spi_done;

  gpu gpu0 (
      .clk  (clk),
      .rst_n(rst_n),
      .wr   (io_wr && mem_addr[7:5] != 3'b111),   // everything below 0xE0
      .waddr(mem_addr[7:0]),
      .wdata(mem_wdata),
      .rgb  (rgb),
      .hsync(hsync),
      .vsync(vsync),
      .frame(frame),
      .line (line),
      .vblank(vblank),
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

  // tinyvga pmod: R1 G1 B1 vs R0 G0 B0 hs
  assign uo_out = {hsync, rgb[0], rgb[2], rgb[4], vsync, rgb[1], rgb[3], rgb[5]};

  // uio: 0 flash cs, 1 mosi, 2 miso (input), 3 sck, 4+5 io2/io3 (held high), 6 psram cs, 7 audio
  assign uio_out = {audio_out, cs_ram, 1'b1, 1'b1, sck, 1'b0, mosi, cs_flash};
  assign uio_oe  = 8'b1111_1011;

  wire _unused = &{ena, uio_in[7:3], uio_in[1:0], 1'b0};

endmodule
