// 32 bit adder, carry select: the top half gets worked out both ways (carry
// in 0 and 1) at the same time as the bottom half, then we just pick one
`default_nettype none

module adder (
    input  wire [31:0] x,
    input  wire [31:0] y,
    input  wire        cin,
    output wire [31:0] s,
    output wire        cout
);

  wire [16:0] lo_sum  = {1'b0, x[15:0]} + {1'b0, y[15:0]} + {16'd0, cin};
  wire [16:0] hi_sum0 = {1'b0, x[31:16]} + {1'b0, y[31:16]};
  wire [16:0] hi_sum1 = {1'b0, x[31:16]} + {1'b0, y[31:16]} + 17'd1;
  wire [16:0] hi_sum  = lo_sum[16] ? hi_sum1 : hi_sum0;

  assign s    = {hi_sum[15:0], lo_sum[15:0]};
  assign cout = hi_sum[16];

endmodule
