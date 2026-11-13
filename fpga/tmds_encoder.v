// TMDS encoder (DVI spec)
// 8 bit pixel -> 10 bit symbol
`default_nettype none

module tmds_encoder (
    input  wire       clk,
    input  wire [7:0] d,     // pixel data
    input  wire [1:0] c,     // control bits (hsync/vsync on the blue channel)
    input  wire       de,    // 1 = pixel data, 0 = send control symbol
    output reg  [9:0] q
);

  // ---- step 1: xor or xnor chain, whichever gives fewer transitions ----
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

  // ---- step 2: keep the line DC balanced ----
  wire [3:0] ones_qm  = qm[0] + qm[1] + qm[2] + qm[3] + qm[4] + qm[5] + qm[6] + qm[7];
  wire [3:0] zeros_qm = 4'd8 - ones_qm;

  // running disparity (ones minus zeros sent so far). everything is 5 bit
  // two's complement so plain adds/subs just wrap correctly
  reg  [4:0] cnt = 0;
  wire       cnt_neg  = cnt[4];
  wire       cnt_zero = (cnt == 0);
  wire [4:0] diff = {1'b0, ones_qm} - {1'b0, zeros_qm};   // ones - zeros
  wire [4:0] two_qm8  = {3'b0, qm[8], 1'b0};               // 2 * qm[8]
  wire [4:0] two_nqm8 = {3'b0, ~qm[8], 1'b0};              // 2 * ~qm[8]

  always @(posedge clk) begin
    if (!de) begin
      cnt <= 0;
      case (c)
        2'b00: q <= 10'b1101010100;
        2'b01: q <= 10'b0101010100;
        2'b10: q <= 10'b0010101011;
        2'b11: q <= 10'b1010101011;
      endcase
    end else if (cnt_zero || ones_qm == 4) begin
      if (qm[8]) begin
        q   <= {2'b01, qm[7:0]};
        cnt <= cnt + diff;
      end else begin
        q   <= {2'b10, ~qm[7:0]};
        cnt <= cnt - diff;
      end
    end else if ((!cnt_neg && ones_qm > 4) || (cnt_neg && ones_qm < 4)) begin
      // too many of the same, invert
      q   <= {1'b1, qm[8], ~qm[7:0]};
      cnt <= cnt + two_qm8 - diff;
    end else begin
      q   <= {1'b0, qm[8], qm[7:0]};
      cnt <= cnt - two_nqm8 + diff;
    end
  end

endmodule
