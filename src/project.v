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

  wire [5:0] rgb;
  wire       hsync, vsync;

  gpu gpu0 (
      .clk    (clk),
      .rst_n  (rst_n),
      .rgb    (rgb),
      .hsync  (hsync),
      .vsync  (vsync)
  );

  // TinyVGA pmod: rgb = {R1, R0, G1, G0, B1, B0}
  assign uo_out = {hsync, rgb[0], rgb[2], rgb[4], vsync, rgb[1], rgb[3], rgb[5]};

  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused = &{ena, ui_in, uio_in, 1'b0};

endmodule
