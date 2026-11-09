// risc-v cpu, first try. rv32e: only 16 registers, the chip is tiny
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
  reg [25:0] pc;                 // 64 MB of address space is plenty
  reg [31:0] ir;
  reg [31:0] regs [1:15];   // x0 is always 0 so it doesnt need a register

  wire [6:0] opcode = ir[6:0];
  wire [3:0] rd     = ir[10:7];
  wire [2:0] f3     = ir[14:12];
  wire [3:0] rs1    = ir[18:15];
  wire [3:0] rs2    = ir[23:20];

  wire [31:0] imm_i = {{20{ir[31]}}, ir[31:20]};
  wire [31:0] imm_b = {{20{ir[31]}}, ir[7], ir[30:25], ir[11:8], 1'b0};
  wire [31:0] imm_s = {{20{ir[31]}}, ir[31:25], ir[11:7]};
  wire [31:0] imm_u = {ir[31:12], 12'd0};
  wire [31:0] imm_j = {{12{ir[31]}}, ir[19:12], ir[20], ir[30:21], 1'b0};

  localparam OP_LUI   = 7'b0110111;
  localparam OP_AUIPC = 7'b0010111;
  localparam OP_JAL   = 7'b1101111;
  localparam OP_JALR  = 7'b1100111;
  localparam OP_BRANCH = 7'b1100011;
  localparam OP_LOAD  = 7'b0000011;
  localparam OP_STORE = 7'b0100011;
  localparam OP_IMM   = 7'b0010011;
  localparam OP_REG   = 7'b0110011;

  wire [31:0] a    = (rs1 == 0) ? 32'd0 : regs[rs1];
  wire [31:0] rv2  = (rs2 == 0) ? 32'd0 : regs[rs2];
  wire [31:0] b = (opcode == OP_REG || opcode == OP_BRANCH) ? rv2 : imm_i;

  // loads and stores
  wire [31:0] addr = a + ((opcode == OP_STORE) ? imm_s : imm_i);
  assign mem_addr  = (state == MEM) ? addr : pc;
  assign mem_req   = (state == FETCH) || (state == MEM);
  assign mem_size  = (state == FETCH || f3[1]) ? 3'd4 : (f3[0] ? 3'd2 : 3'd1);
  assign mem_we    = (state == MEM) && (opcode == OP_STORE);
  assign mem_wdata = rv2;

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

  // alu, one thing for each instruction
  wire [4:0] shamt = b[4:0];
  reg  [31:0] alu;
  always @(*) begin
    case (f3)
      3'b000:  alu = (opcode == OP_REG && ir[30]) ? a - b : a + b;
      3'b001:  alu = a << shamt;
      3'b010:  alu = ($signed(a) < $signed(b)) ? 1 : 0;
      3'b011:  alu = (a < b) ? 1 : 0;
      3'b100:  alu = a ^ b;
      3'b101:  alu = ir[30] ? ($signed(a) >>> shamt) : (a >> shamt);
      3'b110:  alu = a | b;
      default: alu = a & b;
    endcase
  end

  reg take;
  always @(*) begin
    case (f3)
      3'b000:  take = (a == b);
      3'b001:  take = (a != b);
      3'b100:  take = ($signed(a) < $signed(b));
      3'b101:  take = ($signed(a) >= $signed(b));
      3'b110:  take = (a >= b);
      3'b111:  take = (a < b);
      default: take = 0;
    endcase
  end

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
          $display("pc=%h ir=%h a=%h b=%h", pc, ir, a, b);
          pc    <= pc + 4;
          state <= FETCH;

          case (opcode)
            OP_LOAD, OP_STORE: begin
              pc    <= pc;
              state <= MEM;
            end
            OP_LUI:   regs[rd] <= imm_u;
            OP_AUIPC: regs[rd] <= pc + imm_u;
            OP_JAL: begin
              regs[rd] <= pc + 4;
              pc       <= pc + imm_j;
            end
            OP_JALR: begin
              regs[rd] <= pc + 4;
              pc       <= (a + imm_i) & 32'hfffffffe;   // jalr clears bit 0
            end
            OP_BRANCH: if (take) pc <= pc + imm_b;
            OP_IMM, OP_REG: regs[rd] <= alu;
          endcase
        end

        MEM: if (mem_done) begin
          if (opcode == OP_LOAD)
            regs[rd] <= load_val;
          pc    <= pc + 4;
          state <= FETCH;
        end
      endcase
    end
  end

endmodule
