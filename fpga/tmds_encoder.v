// TMDS encoder, from the DVI spec (section 3.3 flowchart)
// 8 bit pixel -> 10 bit symbol
`default_nettype none

module tmds_encoder (
    input  wire       clk,
    input  wire [7:0] d,     // pixel data
    input  wire [1:0] c,     // control bits (hsync/vsync on the blue channel)
    input  wire       de,    // 1 = pixel data, 0 = send control symbol
    output reg  [9:0] q
);

  // step 1: xor or xnor chain, whichever gives fewer transitions
  wire [3:0] ones_d = d[0] + d[1] + d[2] + d[3] + d[4] + d[5] + d[6] + d[7];
  wire use_xnor = (ones_d > 4) || (ones_d == 4 && d[0] == 0);

  wire [8:0] qm;
  assign qm[0] = d[0];
  assign qm[1] = use_xnor ? ~(qm[0] ^ d[1]) : (qm[0] ^ d[1]);
  assign qm[2] = use_xnor ? ~(qm[1] ^ d[2]) : (qm[1] ^ d[2]);
  assign qm[3] = use_xnor ? ~(qm[2] ^ d[3]) : (qm[2] ^ d[3]);
  assign qm[4] = use_xnor ? ~(qm[3] ^ d[4]) : (qm[3] ^ d[4]);
  assign qm[5] = use_xnor ? ~(qm[4] ^ d[5]) : (qm[4] ^ d[5]);
  assign qm[6] = use_xnor ? ~(qm[5] ^ d[6]) : (qm[5] ^ d[6]);
  assign qm[7] = use_xnor ? ~(qm[6] ^ d[7]) : (qm[6] ^ d[7]);
  assign qm[8] = ~use_xnor;

  always @(posedge clk) begin
    if (!de) begin
      case (c)
        2'b00: q <= 10'b1101010100;
        2'b01: q <= 10'b0010101011;
        2'b10: q <= 10'b0101010100;
        2'b11: q <= 10'b1010101011;
      endcase
    end else begin
      q <= {1'b0, qm};   // TODO dc balance
    end
  end

endmodule
