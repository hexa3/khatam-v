// 32 bit Kogge-Stone adder

`default_nettype none

module adder (
    input  wire [31:0] x,
    input  wire [31:0] y,
    input  wire        cin,
    output wire [31:0] s,
    output wire        cout
);

  wire [31:0] p0 = x ^ y;

  // fold the carry in into bit 0's generate
  wire [31:0] g0 = (x & y) | {31'd0, p0[0] & cin};

  wire [31:0] g [0:5];
  wire [31:0] p [0:5];
  assign g[0] = g0;
  assign p[0] = p0;

  genvar lvl, i;
  generate
    for (lvl = 0; lvl < 5; lvl = lvl + 1) begin : step
      for (i = 0; i < 32; i = i + 1) begin : bits
        if (i >= (1 << lvl)) begin : comb
          assign g[lvl+1][i] = g[lvl][i] | (p[lvl][i] & g[lvl][i - (1 << lvl)]);
          assign p[lvl+1][i] = p[lvl][i] & p[lvl][i - (1 << lvl)];
        end else begin : pass
          assign g[lvl+1][i] = g[lvl][i];
          assign p[lvl+1][i] = p[lvl][i];
        end
      end
    end
  endgenerate

  wire [31:0] carry = g[5];   // carry OUT of each bit

  assign s    = p0 ^ {carry[30:0], cin};
  assign cout = carry[31];

endmodule
