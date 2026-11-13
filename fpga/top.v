// Icepi Zero test build for Khatam-V
`default_nettype none

module top (
    input  wire       clk,       // 50 MHz
    input  wire [1:0] button,    // active low
    output wire [3:0] gpdi_dp
);

  // ---------------- clocks + reset ----------------
  wire clk_pix, clk_shift, locked;
  pll pll_i (.clk_in(clk), .clk_shift(clk_shift), .clk_pix(clk_pix), .locked(locked));

  reg [7:0] rst_cnt = 0;
  always @(posedge clk_pix) begin
    if (!locked)
      rst_cnt <= 0;
    else if (rst_cnt != 8'hff)
      rst_cnt <= rst_cnt + 1;
  end
  wire rst_n = (rst_cnt == 8'hff);

  // ---------------- buttons ----------------
  reg [1:0] btn_s1 = 0, btn_s2 = 0;
  always @(posedge clk_pix) begin
    btn_s1 <= ~button;
    btn_s2 <= btn_s1;
  end
  wire [7:0] ui_in = {6'd0, btn_s2};

  // ---------------- the chip ----------------
  wire [7:0] uo_out, uio_out, uio_oe;
  wire       miso_flash, miso_ram;
  wire       miso = !uio_out[0] ? miso_flash : miso_ram;

  tt_um_khatam_v chip (
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in ({5'd0, miso, 2'd0}),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (1'b1),
      .clk    (clk_pix),
      .rst_n  (rst_n)
  );

  // ---------------- fake QSPI Pmod ----------------
  spi_bram #(.INIT("firmware.hex")) flash (
      .clk(clk_pix), .cs_n(uio_out[0]), .sck(uio_out[3]), .mosi(uio_out[1]), .miso(miso_flash));

  spi_bram psram (
      .clk(clk_pix), .cs_n(uio_out[6]), .sck(uio_out[3]), .mosi(uio_out[1]), .miso(miso_ram));

  // ---------------- VGA -> HDMI ----------------
  wire [1:0] red   = {uo_out[0], uo_out[4]};
  wire [1:0] green = {uo_out[1], uo_out[5]};
  wire [1:0] blue  = {uo_out[2], uo_out[6]};
  wire       vsync = uo_out[3];
  wire       hsync = uo_out[7];

  // DVI needs a "visible area" signal the chip doesn't have, so follow the
  // sync pulses with our own counters (hsync falls at x=656, vsync at y=490)
  reg [9:0] h = 0, v = 0;
  reg       hsync_d = 1, vsync_d = 1;
  always @(posedge clk_pix) begin
    hsync_d <= hsync;
    vsync_d <= vsync;

    if (hsync_d && !hsync)
      h <= 657;
    else if (h == 799)
      h <= 0;
    else
      h <= h + 1;

    if (vsync_d && !vsync)
      v <= 490;
    else if (h == 799)
      v <= (v == 524) ? 0 : v + 1;
  end
  wire de = (h < 640) && (v < 480);

  dvi_out dvi (
      .clk_pix  (clk_pix),
      .clk_shift(clk_shift),
      .r        ({4{red}}),
      .g        ({4{green}}),
      .b        ({4{blue}}),
      .hsync    (hsync),
      .vsync    (vsync),
      .de       (de),
      .gpdi_dp  (gpdi_dp)
  );

endmodule
