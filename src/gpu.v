`default_nettype none

module gpu (
    input  wire        clk,
    input  wire        rst_n,

    output reg  [5:0]  rgb,        // RRGGBB
    output reg         hsync,
    output reg         vsync
);

  // VGA timing 640x480
  reg [9:0] hcount, vcount;

  always @(posedge clk) begin
    if (!rst_n) begin
      hcount <= 0;
      vcount <= 0;
    end else if (hcount == 800) begin
      hcount <= 0;
      if (vcount == 525) begin
        vcount <= 0;
      end else begin
        vcount <= vcount + 1;
      end
    end else begin
      hcount <= hcount + 1;
    end
  end

  wire visible = (hcount < 640) && (vcount < 480);

  // khatam star pattern
  wire [9:0] x = hcount;
  wire [9:0] y = vcount;

  wire [5:0] px = x[5:0];
  wire [5:0] py = y[5:0];

  wire [4:0] ax = px[5] ? px[4:0] : ~px[4:0];
  wire [4:0] ay = py[5] ? py[4:0] : ~py[4:0];
  wire [5:0] sum_a = ax + ay;

  wire [4:0] r = 5'd20;
  wire [4:0] r3  = r - 5'd3;
  wire [4:0] rs  = (r >> 2) + 5'd3;

  function [5:0] diag;  // 1.375 * rr
    input [4:0] rr;
    begin
      diag = rr + (rr >> 1) - (rr >> 3);
    end
  endfunction

  function star;
    input [4:0] a, b;
    input [5:0] s;
    input [4:0] rr;
    begin
      star = ((a <= rr) && (b <= rr)) || (s <= diag(rr));
    end
  endfunction

  function octagon;
    input [4:0] a, b;
    input [5:0] s;
    input [4:0] rr;
    begin
      octagon = (a <= rr) && (b <= rr) && (s <= diag(rr));
    end
  endfunction

  wire in_star    = star(ax, ay, sum_a, r);
  wire line_star  = in_star & ~star(ax, ay, sum_a, r3);
  wire rosette    = octagon(ax, ay, sum_a, rs);

  wire [5:0] color = line_star ? 6'b00_00_01 :
                     rosette   ? 6'b00_10_01 :
                     in_star   ? 6'b00_01_11 : 6'b11_11_11;

  always @(posedge clk) begin
    if (!rst_n) begin
      rgb   <= 0;
      hsync <= 1;
      vsync <= 1;
    end else begin
      rgb   <= visible ? color : 6'd0;
      hsync <= ~((hcount >= 656) && (hcount < 752));
      vsync <= ~((vcount >= 490) && (vcount < 492));
    end
  end

endmodule
