// VGA style signals -> DVI on the Icepi Zero GPDI connector
// clk_shift = 125 MHz, 2 bits per clock with the DDR flops = 10 bits per pixel
`default_nettype none

module dvi_out (
    input  wire       clk_pix,
    input  wire       clk_shift,
    input  wire [7:0] r,
    input  wire [7:0] g,
    input  wire [7:0] b,
    input  wire       hsync,
    input  wire       vsync,
    input  wire       de,
    output wire [3:0] gpdi_dp    // 0 blue, 1 green, 2 red, 3 clock
);

  // ---- encode (pixel clock domain) ----
  wire [9:0] tmds_r, tmds_g, tmds_b;
  tmds_encoder enc_b (.clk(clk_pix), .d(b), .c({vsync, hsync}), .de(de), .q(tmds_b));
  tmds_encoder enc_g (.clk(clk_pix), .d(g), .c(2'b00),          .de(de), .q(tmds_g));
  tmds_encoder enc_r (.clk(clk_pix), .d(r), .c(2'b00),          .de(de), .q(tmds_r));

  // flips every pixel clock, the fast side watches this so it knows when
  // a fresh word is ready (instead of just hoping its counter lines up)
  reg toggle = 0;
  always @(posedge clk_pix) toggle <= ~toggle;

  // ---- shift out (125 MHz domain) ----
  reg [2:0] toggle_sync = 0;
  reg       load = 0;
  reg [9:0] sh_r = 0, sh_g = 0, sh_b = 0, sh_c = 0;

  always @(posedge clk_shift) begin
    toggle_sync <= {toggle_sync[1:0], toggle};
    load <= toggle_sync[2] ^ toggle_sync[1];   // fires once every 5 clocks

    if (load) begin
      sh_r <= tmds_r;
      sh_g <= tmds_g;
      sh_b <= tmds_b;
      sh_c <= 10'b0000011111;                  // the TMDS clock lane is just this
    end else begin
      sh_r <= sh_r >> 2;
      sh_g <= sh_g >> 2;
      sh_b <= sh_b >> 2;
      sh_c <= sh_c >> 2;
    end
  end

  // DDR output: D0 goes out first, then D1. TMDS is LSB first.
  ODDRX1F ddr_b (.SCLK(clk_shift), .RST(1'b0), .D0(sh_b[0]), .D1(sh_b[1]), .Q(gpdi_dp[0]));
  ODDRX1F ddr_g (.SCLK(clk_shift), .RST(1'b0), .D0(sh_g[0]), .D1(sh_g[1]), .Q(gpdi_dp[1]));
  ODDRX1F ddr_r (.SCLK(clk_shift), .RST(1'b0), .D0(sh_r[0]), .D1(sh_r[1]), .Q(gpdi_dp[2]));
  ODDRX1F ddr_c (.SCLK(clk_shift), .RST(1'b0), .D0(sh_c[0]), .D1(sh_c[1]), .Q(gpdi_dp[3]));

endmodule
