`default_nettype none

module gpu (
    input  wire        clk,
    input  wire        rst_n,

    output reg  [5:0]  rgb,        // RRGGBB
    output reg         hsync,
    output reg         vsync,

    output reg  [15:0] frame
);

  // VGA timing 640x480
  reg [9:0] hcount, vcount;

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

  // khatam star pattern
  wire [9:0] x = hcount;
  wire [9:0] y = vcount;

  wire [5:0] px = x[5:0];
  wire [5:0] py = y[5:0];
  wire [1:0] cx = x[7:6];
  wire [1:0] cy = y[7:6];

  wire [4:0] ax = px[5] ? px[4:0] : ~px[4:0];
  wire [4:0] ay = py[5] ? py[4:0] : ~py[4:0];
  wire [5:0] sum_a = ax + ay;

  // breathing: radius goes up and down with the frame counter
  wire [6:0] tri_wave = frame[7] ? ~frame[6:0] : frame[6:0];
  wire [4:0] r   = 5'd16 + tri_wave[6:4];
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

  localparam BG = 3'd0, FILL = 3'd1, FILL2 = 3'd2, LINE = 3'd3, ACCENT = 3'd4;

  reg [2:0] kind;
  always @(*) begin
    if (line_star)    kind = LINE;
    else if (rosette) kind = ACCENT;
    else if (in_star) kind = FILL;
    else              kind = BG;
  end

  // colour bands that move across the screen
  wire [1:0] band = cx + cy - frame[6:5];

  reg [5:0] color;
  always @(*) begin
    case (kind)
      FILL:    color = band[1] ? 6'b00_00_10 : 6'b00_01_11;
      LINE:    color = 6'b00_00_01;
      ACCENT:  color = 6'b00_10_01;
      default: color = 6'b11_11_11;
    endcase
  end

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
