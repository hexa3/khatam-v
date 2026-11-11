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

  wire [5:0] rgb;
  wire       hsync, vsync;

  gpu gpu0 (
      .clk    (clk),
      .rst_n  (rst_n),
      .pattern(ui_in[1:0]),
      .cellsize(ui_in[3:2]),
      .scroll (ui_in[4]),
      .rgb    (rgb),
      .hsync  (hsync),
      .vsync  (vsync)
  );

  // no memory yet, feed it nops
  assign mem_rdata = 32'h00000013;
  assign mem_done  = 1;

  // TinyVGA pmod: rgb = {R1, R0, G1, G0, B1, B0}
  assign uo_out = {hsync, rgb[0], rgb[2], rgb[4], vsync, rgb[1], rgb[3], rgb[5]};

  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused = &{ena, ui_in[7:5], uio_in, mem_addr, mem_wdata, mem_size, mem_we, mem_req, 1'b0};

endmodule
