`default_nettype none

module gpu (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        wr,
    input  wire [7:0]  waddr,
    input  wire [31:0] wdata,

    output reg  [5:0]  rgb,        // RRGGBB
    output reg         hsync,
    output reg         vsync,

    output reg  [15:0] frame,
    output wire [9:0]  line,
    output wire        vblank
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
  assign line   = vcount;
  assign vblank = (vcount >= 480);

  // registers (the cpu writes these)
  reg [1:0]  pattern;
  reg [1:0]  cellsize;
  reg        breathe;
  reg        pattern_on;
  reg [4:0]  radius;
  reg [9:0]  scroll_x, scroll_y;
  reg [5:0]  pal0, pal1, pal2, pal3, pal4;

  // 4 shape sprites
  reg [9:0]  sx [0:3];
  reg [9:0]  sy [0:3];
  reg [4:0]  ssize [0:3];
  reg [1:0]  sshape [0:3];
  reg        son [0:3];
  reg [5:0]  scol [0:3];

  always @(posedge clk) begin
    if (!rst_n) begin
      pattern    <= 0;
      cellsize   <= 0;
      breathe    <= 1;
      pattern_on <= 1;
      radius     <= 5'd20;
      scroll_x   <= 0;
      scroll_y   <= 0;
      // boot up in the Fez colours so you see something straight away
      pal0 <= 6'b11_11_11;
      pal1 <= 6'b00_01_11;
      pal2 <= 6'b00_00_10;
      pal3 <= 6'b00_00_01;
      pal4 <= 6'b00_10_01;
      son[0] <= 0; son[1] <= 0; son[2] <= 0; son[3] <= 0;
    end else if (wr) begin
      case (waddr)
        8'h00: begin
          pattern    <= wdata[1:0];
          cellsize   <= wdata[3:2];
          breathe    <= wdata[4];
          pattern_on <= wdata[5];
        end
        8'h04: radius   <= wdata[4:0];
        8'h08: scroll_x <= wdata[9:0];
        8'h0C: scroll_y <= wdata[9:0];
        8'h10: pal0 <= wdata[5:0];
        8'h14: pal1 <= wdata[5:0];
        8'h18: pal2 <= wdata[5:0];
        8'h1C: pal3 <= wdata[5:0];
        8'h20: pal4 <= wdata[5:0];
        default: begin
          // shape sprites 0x40..0x7F
          if (waddr[7:6] == 2'b01) begin
            case (waddr[3:2])
              2'd0: sx[waddr[5:4]] <= wdata[9:0];
              2'd1: sy[waddr[5:4]] <= wdata[9:0];
              2'd2: begin
                ssize[waddr[5:4]]  <= wdata[4:0];
                sshape[waddr[5:4]] <= wdata[6:5];
                son[waddr[5:4]]    <= wdata[7];
                scol[waddr[5:4]]   <= wdata[13:8];
              end
              default: ;
            endcase
          end
        end
      endcase
    end
  end

  // khatam star pattern
  wire [9:0] x = hcount + scroll_x;
  wire [9:0] y = vcount + scroll_y;

  // cell size: 0 = 64px, 1 = 32px, 2 = 128px
  reg [5:0] px, py;
  reg [1:0] cx, cy;
  always @(*) begin
    case (cellsize)
      2'd1: begin
        px = {x[4:0], 1'b0}; py = {y[4:0], 1'b0};
        cx = x[6:5];         cy = y[6:5];
      end
      2'd2: begin
        px = x[6:1];         py = y[6:1];
        cx = x[8:7];         cy = y[8:7];
      end
      default: begin
        px = x[5:0];         py = y[5:0];
        cx = x[7:6];         cy = y[7:6];
      end
    endcase
  end

  wire [4:0] ax = px[5] ? px[4:0] : ~px[4:0];
  wire [4:0] ay = py[5] ? py[4:0] : ~py[4:0];
  wire [5:0] sum_a = ax + ay;
  wire [4:0] bx_ = ~ax;
  wire [4:0] by_ = ~ay;
  wire [5:0] sum_b = bx_ + by_;

  // breathing: radius goes up and down with the frame counter
  wire [6:0] tri_wave = frame[7] ? ~frame[6:0] : frame[6:0];
  wire [4:0] r   = breathe ? (5'd16 + tri_wave[6:4]) : radius;
  wire [4:0] r3  = r - 5'd3;
  wire [4:0] rs  = (r >> 2) + 5'd3;
  wire [4:0] ro  = (r > 5'd23) ? 5'd31 : r + 5'd8;
  wire [4:0] ro3 = ro - 5'd3;
  wire [4:0] rb  = r - 5'd6;
  wire [4:0] rb3 = rb - 5'd3;

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
  wire in_starb   = star(bx_, by_, sum_b, rb);
  wire line_starb = in_starb & ~star(bx_, by_, sum_b, rb3);
  wire in_oct     = octagon(ax, ay, sum_a, ro);
  wire line_oct   = in_oct & ~octagon(ax, ay, sum_a, ro3);
  wire small_star = star(ax, ay, sum_a, rs);
  wire [5:0] dd   = r + 5'd9;
  wire in_dia     = (sum_a <= dd);
  wire line_dia   = in_dia && (sum_a > dd - 6'd3);
  wire [5:0] ripple = sum_a + frame[6:3];

  localparam BG = 3'd0, FILL = 3'd1, FILL2 = 3'd2, LINE = 3'd3, ACCENT = 3'd4;

  reg [2:0] kind;
  reg       on_b;
  always @(*) begin
    on_b = 0;
    case (pattern)
      2'd0: begin
        if (line_star)    kind = LINE;
        else if (rosette) kind = ACCENT;
        else if (in_star) kind = FILL;
        else              kind = BG;
      end
      2'd1: begin
        if (line_oct)        kind = LINE;
        else if (small_star) kind = ACCENT;
        else if (in_oct)     kind = FILL;
        else                 kind = BG;
      end
      2'd2: begin
        // second set of stars sitting in the gaps of the first
        if (line_star && line_starb)  kind = (px[5] ^ py[5]) ? LINE : ACCENT;
        else if (line_star)           kind = LINE;
        else if (line_starb)          kind = ACCENT;
        else if (in_star && in_starb) kind = FILL2;
        else if (in_star)             kind = FILL;
        else if (in_starb) begin      kind = FILL; on_b = 1; end
        else                          kind = BG;
      end
      default: begin
        if (line_dia)                 kind = LINE;
        else if (sum_a <= {1'b0, rs}) kind = ACCENT;
        else if (in_dia)              kind = ripple[2] ? FILL : FILL2;
        else                          kind = BG;
      end
    endcase
  end

  // colour bands that move across the screen
  // the b stars belong to the cell next door, so they get its band
  wire [1:0] cx2  = on_b ? cx + px[5] : cx;
  wire [1:0] cy2  = on_b ? cy + py[5] : cy;
  wire [1:0] band = cx2 + cy2 - frame[6:5];

  reg [5:0] bg_color;
  always @(*) begin
    if (!pattern_on) bg_color = pal0;
    else case (kind)
      FILL:    bg_color = band[1] ? pal2 : pal1;
      FILL2:   bg_color = band[1] ? pal1 : pal2;
      LINE:    bg_color = pal3;
      ACCENT:  bg_color = pal4;
      default: bg_color = pal0;
    endcase
  end

  // shape sprites
  function in_shape;
    input [9:0] h, v, cx_, cy_;
    input [4:0] sz;
    input [1:0] shp;
    reg   [10:0] dx, dy;
    reg   [9:0]  adx, ady;
    begin
      dx  = {1'b0, h} - {1'b0, cx_};
      dy  = {1'b0, v} - {1'b0, cy_};
      adx = dx[10] ? -dx[9:0] : dx[9:0];
      ady = dy[10] ? -dy[9:0] : dy[9:0];
      if (adx > 31 || ady > 31)
        in_shape = 0;
      else
        in_shape = (adx[4:0] <= sz) && (ady[4:0] <= sz);   // square
    end
  endfunction

  wire shape_hit0 = son[0] && in_shape(hcount, vcount, sx[0], sy[0], ssize[0], sshape[0]);
  wire shape_hit1 = son[1] && in_shape(hcount, vcount, sx[1], sy[1], ssize[1], sshape[1]);
  wire shape_hit2 = son[2] && in_shape(hcount, vcount, sx[2], sy[2], ssize[2], sshape[2]);
  wire shape_hit3 = son[3] && in_shape(hcount, vcount, sx[3], sy[3], ssize[3], sshape[3]);

  // sprites go on top of the background
  reg [5:0] color;
  always @(*) begin
    if (shape_hit0)      color = scol[0];
    else if (shape_hit1) color = scol[1];
    else if (shape_hit2) color = scol[2];
    else if (shape_hit3) color = scol[3];
    else                 color = bg_color;
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
