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

  // ---------------- the chip ----------------
  wire [7:0] uo_out, uio_out, uio_oe;

  tt_um_khatam_v chip (
      .ui_in  ({6'd0, ~button}),
      .uo_out (uo_out),
      .uio_in (8'd0),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (1'b1),
      .clk    (clk_pix),
      .rst_n  (rst_n)
  );

  assign gpdi_dp = 4'd0;   // TODO hdmi

endmodule
