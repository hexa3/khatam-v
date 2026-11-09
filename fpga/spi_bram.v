// Pretend SPI memory chip made out of FPGA block RAM so the Icepi Zero can
// stand in for the QSPI Pmod. Understands 0x03 read and 0x02 write.
// 32 KB, the address just wraps after that.
//
// Runs on the same 25 MHz clock as the chip. The chip only changes SCK on a
// clock edge, so we can just watch for it going up.
`default_nettype none

module spi_bram #(
    parameter INIT     = "",
    parameter WRITABLE = 1
) (
    input  wire clk,
    input  wire cs_n,
    input  wire sck,
    input  wire mosi,
    output wire miso
);

  reg [7:0] mem [0:32767];
  initial if (INIT != "") $readmemh(INIT, mem);

  reg        sck_prev = 0;
  reg [5:0]  cnt = 0;           // bits seen in command + address (stops at 32)
  reg [7:0]  cmd = 0;
  reg [23:0] addr = 0;
  reg [17:0] dbits = 0;         // bits seen in the data part
  reg [7:0]  wbyte = 0;
  reg [7:0]  rbyte = 0;

  wire rise = sck && !sck_prev;

  // the byte we're on right now
  wire [14:0] byte_addr = addr[14:0] + dbits[17:3];

  always @(posedge clk) begin
    sck_prev <= sck;
    rbyte    <= mem[byte_addr];

    if (cs_n) begin
      cnt   <= 0;
      dbits <= 0;
    end else if (rise) begin
      if (cnt < 8) begin
        cmd <= {cmd[6:0], mosi};
        cnt <= cnt + 1;
      end else if (cnt < 32) begin
        addr <= {addr[22:0], mosi};
        cnt  <= cnt + 1;
      end else begin
        dbits <= dbits + 1;
        if (cmd == 8'h02) begin
          wbyte <= {wbyte[6:0], mosi};
          if (WRITABLE && dbits[2:0] == 3'd7)
            mem[byte_addr] <= {wbyte[6:0], mosi};
        end
      end
    end
  end

  assign miso = rbyte[7 - dbits[2:0]];

endmodule
