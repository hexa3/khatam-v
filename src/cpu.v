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

  wire [31:0] imm_i = {{20{ir[31]}}, ir[31:20]};
  wire [31:0] imm_s = {{20{ir[31]}}, ir[31:25], ir[11:7]};
  wire [31:0] imm_b = {{20{ir[31]}}, ir[11:8], ir[30:25], ir[7], 1'b0};
  wire [31:0] imm_u = {ir[31:12], 12'd0};
  wire [31:0] imm_j = {{12{ir[31]}}, ir[19:12], ir[20], ir[30:21], 1'b0};

  localparam OP_LUI    = 7'b0110111;
  localparam OP_AUIPC  = 7'b0010111;
  localparam OP_JAL    = 7'b1101111;
  localparam OP_JALR   = 7'b1100111;
  localparam OP_BRANCH = 7'b1100011;
  localparam OP_LOAD   = 7'b0000011;
  localparam OP_STORE  = 7'b0100011;
  localparam OP_IMM    = 7'b0010011;
  localparam OP_REG    = 7'b0110011;

  // register file, x0 is always 0
  wire [31:0] rs1_val = (rs1 == 0) ? 32'd0 : regs[rs1];
  wire [31:0] rs2_val = (rs2 == 0) ? 32'd0 : regs[rs2];

  // ALU
  wire [31:0] b_in = (opcode == OP_REG) ? rs2_val : imm_i;

  reg [31:0] alu;
  always @(*) begin
    case (f3)
      3'b000:  alu = (opcode == OP_REG && ir[30]) ? rs1_val - b_in : rs1_val + b_in;
      3'b001:  alu = rs1_val << b_in[4:0];
      3'b010:  alu = ($signed(rs1_val) < $signed(b_in)) ? 32'd1 : 32'd0;
      3'b011:  alu = (rs1_val < b_in) ? 32'd1 : 32'd0;
      3'b100:  alu = rs1_val ^ b_in;
      3'b101:  alu = ir[30] ? $signed(rs1_val) >>> b_in[4:0] : rs1_val >> b_in[4:0];
      3'b110:  alu = rs1_val | b_in;
      default: alu = rs1_val & b_in;
    endcase
  end

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
          if (rd != 0) begin
            case (opcode)
              OP_LUI:         regs[rd] <= imm_u;
              OP_AUIPC:       regs[rd] <= {6'd0, pc} + imm_u;
              OP_IMM, OP_REG: regs[rd] <= alu;
              default: ;
            endcase
          end
          pc    <= pc + 4;
          state <= FETCH;
        end

        default: state <= FETCH;
      endcase
    end
  end

endmodule
