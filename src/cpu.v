// risc-v cpu, first try. just rv32i for now
`default_nettype none

module cpu (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] mem_addr,
    output wire        mem_req,
    input  wire [31:0] mem_rdata,
    input  wire        mem_done
);

  localparam FETCH = 1'd0;
  localparam EXEC  = 1'd1;

  reg        state;
  reg [31:0] pc;
  reg [31:0] ir;
  reg [31:0] regs [0:31];

  wire [6:0] opcode = ir[6:0];
  wire [4:0] rd     = ir[11:7];
  wire [2:0] f3     = ir[14:12];
  wire [4:0] rs1    = ir[19:15];
  wire [4:0] rs2    = ir[24:20];

  wire [31:0] imm_i = {{20{ir[31]}}, ir[31:20]};

  assign mem_addr = pc;
  assign mem_req  = (state == FETCH);

  wire [31:0] a = regs[rs1];

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
          // only addi so far
          if (opcode == 7'b0010011)
            regs[rd] <= a + imm_i;
          pc    <= pc + 4;
          state <= FETCH;
        end
      endcase
    end
  end

endmodule
