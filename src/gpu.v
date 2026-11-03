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

  assign hsync = ~((hcount >= 656) && (hcount < 752));
  assign vsync = ~((vcount >= 490) && (vcount < 492));

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

  // outline = the star minus a smaller star (3 less)
  wire in_inner = ((ax <= 5'd17) && (ay <= 5'd17)) || (sum_a <= 6'd24);
  wire line_star = in_star & ~in_inner;

  assign rgb = !visible ? 6'd0 : line_star ? 6'b00_00_01 : in_star ? 6'b00_01_11 : 6'b11_11_11;

endmodule
