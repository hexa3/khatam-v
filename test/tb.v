`default_nettype none
`timescale 1ns / 1ps

// the chip + some wires with names so test.py doesn't have to remember
// which uio bit is which. the flash and psram are in test.py (SpiMem)

module tb ();

  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg miso;
  wire [7:0] uio_in = {5'b0, miso, 2'b0};
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  wire flash_cs = uio_out[0];
  wire mosi     = uio_out[1];
  wire sck      = uio_out[3];
  wire ram_cs   = uio_out[6];
  wire audio    = uio_out[7];
  wire hsync    = uo_out[7];
  wire vsync    = uo_out[3];

  tt_um_khatam_v user_project (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

endmodule
