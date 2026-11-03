`default_nettype none

module gpu (
    input  wire       clk,
    input  wire       rst_n,
    output wire [5:0] rgb,
    output wire       hsync,
    output wire       vsync
);

  // vga timing, moved here from project.v
  reg [9:0] hcount, vcount;
  reg [15:0] frame;

  always @(posedge clk) begin
    if (!rst_n) begin
      hcount <= 0;
      vcount <= 0;
      frame  <= 0;
    end else if (hcount == 799) begin
      hcount <= 0;
      if (vcount == 524) begin
        vcount <= 0;
        frame  <= frame + 1;
      end else begin
        vcount <= vcount + 1;
      end
    end else begin
      hcount <= hcount + 1;
    end
  end

  wire visible = (hcount < 640) && (vcount < 480);

  assign hsync = ~((hcount >= 656) && (hcount < 752));
  assign vsync = ~((vcount >= 490) && (vcount < 492));

  // khatam star, one per 64x64 cell
  // fold the cell so the middle is at 0,0 and every quarter looks the same
  wire [5:0] px = hcount[5:0];
  wire [5:0] py = vcount[5:0];
  wire [4:0] ax = px[5] ? px[4:0] : ~px[4:0];
  wire [4:0] ay = py[5] ? py[4:0] : ~py[4:0];
  wire [5:0] sum_a = ax + ay;

  // radius goes up and down, 16 .. 23 (frame counts up then down)
  wire [6:0] tri_wave = frame[7] ? ~frame[6:0] : frame[6:0];
  wire [4:0] r = 5'd16 + tri_wave[6:4];

  // 8 point star = a square OR a diamond (the square turned 45 degrees)
  // diamond size = r * 1.375, close enough to sqrt(2) so the points look even
  wire [5:0] r_diag = r + (r >> 1) - (r >> 3);
  wire in_star = ((ax <= r) && (ay <= r)) || (sum_a <= r_diag);

  // outline = the star minus a smaller star (3 less)
  wire [4:0] r_in = r - 5'd3;
  wire [5:0] r_in_diag = r_in + (r_in >> 1) - (r_in >> 3);
  wire in_inner = ((ax <= r_in) && (ay <= r_in)) || (sum_a <= r_in_diag);
  wire line_star = in_star & ~in_inner;

  assign rgb = !visible ? 6'd0 : line_star ? 6'b00_00_01 : in_star ? 6'b00_01_11 : 6'b11_11_11;

endmodule
