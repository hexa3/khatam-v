`default_nettype none

module cpu (
    input  wire        clk,
    input  wire        rst_n,

    output wire [25:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [2:0]  mem_size,   // 1, 2 or 4 bytes
    output wire        mem_we,
    output wire        mem_req,
    input  wire [31:0] mem_rdata,
    input  wire        mem_done
);

  localparam FETCH = 2'd0;
  localparam EXEC  = 2'd1;
  localparam MEM   = 2'd2;

  reg [1:0]  state;
  reg [25:0] pc;
  reg [31:0] ir;

  reg [31:0] regs [1:15];

  // decode
  wire [6:0] opcode = ir[6:0];
  wire [3:0] rd     = ir[10:7];
  wire [2:0] f3     = ir[14:12];
  wire [3:0] rs1    = ir[18:15];
  wire [3:0] rs2    = ir[23:20];
  wire [6:0] f7     = ir[31:25];

  // memory bus (only fetch for now)
  assign mem_req   = (state == FETCH);
  assign mem_addr  = pc;
  assign mem_size  = 3'd4;
  assign mem_we    = 0;
  assign mem_wdata = 0;

  always @(posedge clk) begin
    if (!rst_n) begin
      state <= FETCH;
      pc    <= 0;
    end else begin
      case (state)

        FETCH: if (mem_done) begin
          ir    <= mem_rdata;
          state <= EXEC;
        end

        EXEC: begin
          pc    <= pc + 4;
          state <= FETCH;
        end

        default: state <= FETCH;
      endcase
    end
  end

endmodule
