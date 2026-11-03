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

  // second pattern: octagons. bigger than the star, so the corners get cut off
  // by the diamond instead of poking out
  wire [4:0] r_oct = r + 5'd8;
  wire [5:0] r_oct_diag = r_oct + (r_oct >> 1) - (r_oct >> 3);
  wire in_oct = (ax <= r_oct) && (ay <= r_oct) && (sum_a <= r_oct_diag);
  wire [4:0] r_oct_in = r_oct - 5'd3;
  wire [5:0] r_oct_in_diag = r_oct_in + (r_oct_in >> 1) - (r_oct_in >> 3);
  wire in_oct_inner = (ax <= r_oct_in) && (ay <= r_oct_in) && (sum_a <= r_oct_in_diag);
  wire line_oct = in_oct & ~in_oct_inner;

  // little shape in the middle of each one, other kind than the big one
  wire [4:0] r_small = (r >> 2) + 5'd3;
  wire [5:0] r_small_diag = r_small + (r_small >> 1) - (r_small >> 3);
  wire rosette = (ax <= r_small) && (ay <= r_small) && (sum_a <= r_small_diag);
  wire small_star = ((ax <= r_small) && (ay <= r_small)) || (sum_a <= r_small_diag);

  wire pattern = 1'b0;   // 0 = star, 1 = octagons. change it by hand for now

  // bands of 2 colours that slide across the cells
  wire [1:0] cx = hcount[7:6];
  wire [1:0] cy = vcount[7:6];
  wire [1:0] band = cx + cy - frame[6:5];
  wire [5:0] fill = band[1] ? 6'b00_00_10 : 6'b00_01_11;

  wire line = pattern ? line_oct : line_star;
  wire in_shape = pattern ? in_oct : in_star;

  wire accent = pattern ? small_star : rosette;

  assign rgb = !visible ? 6'd0 : line ? 6'b00_00_01 : accent ? 6'b00_10_01 : in_shape ? fill : 6'b11_11_11;

endmodule
