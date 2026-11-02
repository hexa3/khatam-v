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

  // 640x480 vga at 25 MHz, 800 clocks per line, 525 lines
  reg [9:0] hcount, vcount;

  always @(posedge clk) begin
    if (!rst_n) begin
      hcount <= 0;
      vcount <= 0;
    end else if (hcount == 799) begin
      hcount <= 0;
      if (vcount == 524)
        vcount <= 0;
      else
        vcount <= vcount + 1;
    end else begin
      hcount <= hcount + 1;
    end
  end

  wire visible = (hcount < 640) && (vcount < 480);

  // sync pulses, both negative for 640x480
  wire hsync = ~((hcount >= 656) && (hcount < 752));
  wire vsync = ~((vcount >= 490) && (vcount < 492));

  // khatam star, one per 64x64 cell
  // fold the cell so the middle is at 0,0 and every quarter looks the same
  wire [5:0] px = hcount[5:0];
  wire [5:0] py = vcount[5:0];
  wire [4:0] ax = px[5] ? px[4:0] : ~px[4:0];
  wire [4:0] ay = py[5] ? py[4:0] : ~py[4:0];
  wire [5:0] sum_a = ax + ay;

  // 8 point star = a square OR a diamond (the square turned 45 degrees)
  // 28 = 20 * 1.375, close enough to sqrt(2) so the points look even
  wire in_star = ((ax <= 5'd20) && (ay <= 5'd20)) || (sum_a <= 6'd28);

  wire [5:0] rgb = !visible ? 6'd0 : in_star ? 6'b00_01_11 : 6'b11_11_11;

  // tinyvga pmod: R1 G1 B1 vs R0 G0 B0 hs
  assign uo_out = {hsync, rgb[0], rgb[2], rgb[4], vsync, rgb[1], rgb[3], rgb[5]};

  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused = &{ena, ui_in, uio_in, 1'b0};

endmodule
