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

  // branches
  reg take;
  always @(*) begin
    case (f3)
      3'b000:  take = (rs1_val == rs2_val);
      3'b001:  take = (rs1_val != rs2_val);
      3'b100:  take = ($signed(rs1_val) < $signed(rs2_val));
      3'b101:  take = ($signed(rs1_val) >= $signed(rs2_val));
      3'b110:  take = (rs1_val < rs2_val);
      3'b111:  take = (rs1_val >= rs2_val);
      default: take = 0;
    endcase
  end

  // multiply (just the mul half of the M extension)
  wire        is_mul  = (opcode == OP_REG) && (f7 == 7'b0000001);
  wire [63:0] prod_uu = rs1_val * rs2_val;
  wire [63:0] prod_ss = $signed(rs1_val) * $signed(rs2_val);
  wire [63:0] prod_su = $signed(rs1_val) * $signed({1'b0, rs2_val});

  reg [31:0] mul_out;
  always @(*) begin
    case (f3[1:0])
      2'b00:   mul_out = prod_uu[31:0];    // MUL
      2'b01:   mul_out = prod_ss[63:32];   // MULH
      2'b10:   mul_out = prod_su[63:32];   // MULHSU
      default: mul_out = prod_uu[63:32];   // MULHU
    endcase
  end

  // memory bus
  wire [31:0] addr = rs1_val + ((opcode == OP_STORE) ? imm_s : imm_i);

  assign mem_req   = (state == FETCH) || (state == MEM);
  assign mem_addr  = (state == FETCH) ? pc : addr[25:0];
  assign mem_size  = (state == FETCH || f3[1]) ? 3'd4 : (f3[0] ? 3'd2 : 3'd1);
  assign mem_we    = (state == MEM) && (opcode == OP_STORE);
  assign mem_wdata = rs2_val;

  reg [31:0] load_val;
  always @(*) begin
    case (f3)
      3'b000:  load_val = {{24{mem_rdata[7]}}, mem_rdata[7:0]};    // LB
      3'b001:  load_val = {{16{mem_rdata[15]}}, mem_rdata[15:0]};  // LH
      3'b100:  load_val = {24'd0, mem_rdata[7:0]};                 // LBU
      3'b101:  load_val = {16'd0, mem_rdata[15:0]};                // LHU
      default: load_val = mem_rdata;                               // LW
    endcase
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      state <= FETCH;
      pc    <= 0;
    end else begin
      case (state)

        FETCH: if (mem_done) begin
          $display("pc=%h ir=%h", pc, mem_rdata);
          ir    <= mem_rdata;
          state <= EXEC;
        end

        EXEC: begin
          if (opcode == OP_LOAD || opcode == OP_STORE) begin
            state <= MEM;
          end else begin
              if (rd != 0) begin
                case (opcode)
                  OP_LUI:         regs[rd] <= imm_u;
                  OP_AUIPC:       regs[rd] <= {6'd0, pc} + imm_u;
                  OP_JAL, OP_JALR: regs[rd] <= {6'd0, pc + 26'd4};
                  OP_IMM:         regs[rd] <= alu;
                  OP_REG:         regs[rd] <= is_mul ? mul_out : alu;
                  default: ;
                endcase
              end
              if (opcode == OP_JAL)
                pc <= pc + imm_j[25:0];
              else if (opcode == OP_BRANCH && take)
                pc <= pc + imm_b[25:0];
              else if (opcode == OP_JALR)
                pc <= (rs1_val[25:0] + imm_i[25:0]) & ~26'd1;
              else
                pc <= pc + 4;
              state <= FETCH;
          end
        end

        MEM: if (mem_done) begin
          if (opcode == OP_LOAD && rd != 0)
            regs[rd] <= load_val;
          pc    <= pc + 4;
          state <= FETCH;
        end

        default: state <= FETCH;
      endcase
    end
  end

endmodule
