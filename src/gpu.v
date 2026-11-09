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

  // test stripes
  wire [5:0] color = {hcount[7:6], hcount[7:6], vcount[7:6]};

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
