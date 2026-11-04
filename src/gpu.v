`default_nettype none

module gpu (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [5:0] sw,
    output reg  [5:0] rgb,
    output reg        hsync,
    output reg        vsync
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


  // khatam star, one per 64x64 cell
  // fold the cell so the middle is at 0,0 and every quarter looks the same
  // scrolls sideways by 1 pixel every 2 frames
  wire [9:0] x = hcount + frame[10:1];
  wire [9:0] y = vcount;

  wire [5:0] px = x[5:0];
  wire [5:0] py = y[5:0];
  wire [4:0] ax = px[5] ? px[4:0] : ~px[4:0];
  wire [4:0] ay = py[5] ? py[4:0] : ~py[4:0];
  wire [5:0] sum_a = ax + ay;

  // radius goes up and down, 16 .. 23 (frame counts up then down)
  wire [6:0] tri_wave = frame[7] ? ~frame[6:0] : frame[6:0];
  wire [4:0] r = 5'd16 + tri_wave[6:4];

  function [5:0] diag;  // 1.375 * rr
    input [4:0] rr;
    begin
      diag = rr + (rr >> 1) - (rr >> 3);
    end
  endfunction

  // 8 point star = a square OR a diamond (the square turned 45 degrees)
  function star;
    input [4:0] a, b;
    input [5:0] s;
    input [4:0] rr;
    begin
      star = ((a <= rr) && (b <= rr)) || (s <= diag(rr));
    end
  endfunction

  // octagon = the square AND the diamond, so the corners are cut off
  function octogon;
    input [4:0] a, b;
    input [5:0] s;
    input [4:0] rr;
    begin
      octogon = (a <= rr) && (b <= rr) && (s <= diag(rr));
    end
  endfunction

  wire [4:0] r3  = r - 5'd3;
  wire [4:0] rs  = (r >> 2) + 5'd3;
  wire [4:0] ro  = r + 5'd8;
  wire [4:0] ro3 = ro - 5'd3;

  wire in_star     = star(ax, ay, sum_a, r);
  wire line_star   = in_star & ~star(ax, ay, sum_a, r3);
  wire rosette     = octogon(ax, ay, sum_a, rs);
  wire in_oct      = octogon(ax, ay, sum_a, ro);
  wire line_oct    = in_oct & ~octogon(ax, ay, sum_a, ro3);
  wire small_star  = star(ax, ay, sum_a, rs);

  // no cpu yet so the switches pick the pattern
  wire [1:0] pattern = sw[1:0];

  // bands of 2 colours that slide across the cells
  wire [1:0] cx = x[7:6];
  wire [1:0] cy = y[7:6];
  wire [1:0] band = cx + cy - frame[6:5];

  // colours, RRGGBB
  localparam C_BG    = 6'b11_11_11;
  localparam C_FILL  = 6'b00_01_11;
  localparam C_FILL2 = 6'b00_00_10;
  localparam C_LINE  = 6'b00_00_01;
  localparam C_ACCENT = 6'b00_10_01;

  localparam BG = 3'd0, FILL = 3'd1, LINE = 3'd3, ACCENT = 3'd4;

  reg [2:0] kind;
  always @(*) begin
    case (pattern)
      2'd0: begin
        if (line_star)    kind = LINE;
        else if (rosette) kind = ACCENT;
        else if (in_star) kind = FILL;
        else              kind = BG;
      end
      default: begin
        if (line_oct)        kind = LINE;
        else if (small_star) kind = ACCENT;
        else if (in_oct)     kind = FILL;
        else                 kind = BG;
      end
    endcase
  end

  reg [5:0] color;
  always @(*) begin
    case (kind)
      FILL:    color = band[1] ? C_FILL2 : C_FILL;
      LINE:    color = C_LINE;
      ACCENT:  color = C_ACCENT;
      default: color = C_BG;
    endcase
  end

  // registered outputs so nothing glitches
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
