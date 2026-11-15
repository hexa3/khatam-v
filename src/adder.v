// 32 bit adder, carry select
`default_nettype none

module adder (
    input  wire [31:0] x,
    input  wire [31:0] y,
    input  wire        cin,
    output wire [31:0] s,
    output wire        cout
);

  // 4 blocks of 8 bits. every block adds with carry 0 and with carry 1 at the
  // same time, then the carry coming in picks the right one
  wire [3:0] c;           // carry into each block
  assign c[0] = cin;

  wire [8:0] r0 [0:3];
  wire [8:0] r1 [0:3];

  genvar blk;
  generate
    for (blk = 0; blk < 4; blk = blk + 1) begin : b
      assign r0[blk] = x[8*blk +: 8] + y[8*blk +: 8];
      assign r1[blk] = x[8*blk +: 8] + y[8*blk +: 8] + 9'd1;
      assign s[8*blk +: 8] = c[blk] ? r1[blk][7:0] : r0[blk][7:0];
      if (blk < 3) begin : nxt
        assign c[blk+1] = c[blk] ? r1[blk][8] : r0[blk][8];
      end
    end
  endgenerate

  assign cout = c[3] ? r1[3][8] : r0[3][8];

endmodule
