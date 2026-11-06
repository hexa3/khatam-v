// spi flash reader. plain 1 bit spi, mode 0
`default_nettype none

module qspi (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        req,
    input  wire        ram,       // 0 = flash, 1 = psram
    input  wire [23:0] addr,
    output wire [31:0] rdata,
    output reg         done,

    output reg         sck,
    output reg         mosi,
    input  wire        miso,
    output reg         cs_flash,  // active low
    output reg         cs_ram     // active low
);

  localparam IDLE = 2'd0;
  localparam CMD  = 2'd1;
  localparam DATA = 2'd2;

  reg [1:0]  state;
  reg [31:0] tx;
  reg [31:0] rx;
  reg [5:0]  bits;
  reg        phase;     // 0 = about to raise sck, 1 = about to drop it

  assign rdata = rx;

  always @(posedge clk) begin
    if (!rst_n) begin
      state    <= IDLE;
      cs_flash <= 1;
      cs_ram   <= 1;
      done     <= 0;
    end else begin
      done <= 0;

      case (state)
        IDLE: begin
          if (req && !done) begin
            if (ram) cs_ram   <= 0;
            else     cs_flash <= 0;
            tx    <= {8'h03, addr};   // 0x03 = read
            mosi  <= 0;
            bits  <= 6'd32;
            phase <= 0;
            state <= CMD;
          end
        end

        CMD, DATA: begin
          if (phase == 0) begin
            sck   <= 1;
            phase <= 1;
            rx    <= {rx[30:0], miso};
          end else begin
            sck   <= 0;
            phase <= 0;
            tx    <= {tx[30:0], 1'b0};
            mosi  <= tx[30];
            bits  <= bits - 1;

            if (bits == 1) begin
              if (state == CMD) begin
                state <= DATA;
                bits  <= 6'd32;
              end else begin
                done     <= 1;
                state    <= IDLE;
                cs_flash <= 1;
                cs_ram   <= 1;
              end
            end
          end
        end
      endcase
    end
  end

endmodule
