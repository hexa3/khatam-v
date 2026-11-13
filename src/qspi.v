`default_nettype none

module qspi (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        req,
    input  wire        we,
    input  wire        ram,       // 0 = flash, 1 = psram
    input  wire [23:0] addr,
    input  wire [31:0] wdata,
    input  wire [2:0]  size,      // bytes
    output wire [31:0] rdata,
    output reg         done,

    output reg         sck,
    output reg         mosi,
    input  wire        miso,
    output reg         cs_flash,  // active low
    output reg         cs_ram     // active low
);

  localparam IDLE  = 3'd0;
  localparam CLOSE = 3'd1;
  localparam CMD   = 3'd2;
  localparam DATA  = 3'd3;

  reg [2:0]  state;
  reg [31:0] tx;          // shifts out MSB first
  reg [31:0] rx;          // shifts in
  reg [5:0]  bits;        // bits left in this phase
  reg        phase;       // 0 = about to raise sck, 1 = about to drop it
  reg        writing;
  reg [2:0]  nbytes;
  reg        cont;        // flash CS still low and we know the next address
  reg [23:0] cont_addr;

  // byte swap helpers. first byte on the wire = lowest byte
  wire [31:0] wswap = {wdata[7:0], wdata[15:8], wdata[23:16], wdata[31:24]};

  // read data comes straight out of the shift register (only looked at when done = 1)
  assign rdata = (nbytes == 3'd1) ? {24'd0, rx[7:0]} :
                 (nbytes == 3'd2) ? {16'd0, rx[7:0], rx[15:8]} :
                                    {rx[7:0], rx[15:8], rx[23:16], rx[31:24]};

  always @(posedge clk) begin
    if (!rst_n) begin
      state    <= IDLE;
      sck      <= 0;
      mosi     <= 0;
      cs_flash <= 1;
      cs_ram   <= 1;
      done     <= 0;
      cont     <= 0;
      phase    <= 0;
    end else begin
      done <= 0;

      case (state)

        IDLE: begin
          if (req && !done) begin
            writing <= we;
            nbytes  <= size;
            if (!ram && !we && cont && addr == cont_addr) begin
              // keep reading where we left off, no command needed
              bits  <= {size, 3'b000};
              tx    <= 0;
              phase <= 0;
              state <= DATA;
            end else if (cont) begin
              // flash is still selected from last time, let go of it first
              cs_flash <= 1;
              cont     <= 0;
              state    <= CLOSE;
            end else begin
              // start a new command
              if (ram) cs_ram   <= 0;
              else     cs_flash <= 0;
              tx    <= {(we ? 8'h02 : 8'h03), addr};
              mosi  <= 0;               // first bit of 0x02/0x03 is 0
              bits  <= 6'd32;
              phase <= 0;
              state <= CMD;
            end
          end
        end

        CLOSE: begin
          // one clock with CS high, then go back and start properly
          state <= IDLE;
        end

        CMD, DATA: begin
          if (phase == 0) begin
            sck   <= 1;
            phase <= 1;
          end else begin
            sck   <= 0;
            phase <= 0;
            rx    <= {rx[30:0], miso};
            tx    <= {tx[30:0], 1'b0};
            mosi  <= tx[30];
            bits  <= bits - 1;

            if (bits == 1) begin
              if (state == CMD) begin
                // address sent, now the data
                state <= DATA;
                bits  <= {nbytes, 3'b000};
                tx    <= wswap;
                mosi  <= wswap[31];
              end else begin
                // all done
                done  <= 1;
                state <= IDLE;

                if (!ram && !writing) begin
                  // leave flash selected for the next sequential read
                  cont      <= 1;
                  cont_addr <= addr + {21'd0, nbytes};
                end else begin
                  cs_flash <= 1;
                  cs_ram   <= 1;
                end
              end
            end
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
