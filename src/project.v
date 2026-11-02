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
    end else if (hcount == 800) begin
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

  // sync pulses
  wire hsync = (hcount >= 656) && (hcount < 752);
  wire vsync = (vcount >= 490) && (vcount < 492);

  // just stripes for now
  wire [5:0] rgb = visible ? hcount[8:3] : 6'd0;

  // tinyvga pmod: R1 G1 B1 vs R0 G0 B0 hs
  assign uo_out = {hsync, rgb[0], rgb[2], rgb[4], vsync, rgb[1], rgb[3], rgb[5]};

  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused = &{ena, ui_in, uio_in, 1'b0};

endmodule
