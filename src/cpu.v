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

  localparam FETCH = 4'd0;
  localparam RS1   = 4'd1;
  localparam RS2   = 4'd2;
  localparam EXEC  = 4'd3;
  localparam MEM   = 4'd4;
  localparam MUL   = 4'd5;
  localparam FIX0  = 4'd6;
  localparam FIX1  = 4'd7;
  localparam FIX2  = 4'd8;

  reg [3:0]  state;
  reg [25:0] pc;
  reg [31:0] ir;
  reg [31:0] a;        // rs1
  reg [31:0] hi;       // rs2, then the high half of a multiply
  reg [31:0] lo;       // low half of a multiply
  reg [4:0]  count;

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
  wire [31:0] imm_b = {{20{ir[31]}}, ir[7], ir[30:25], ir[11:8], 1'b0};
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
  // one read port: rs1 in RS1, rs2 everywhere else
  wire [3:0]  rsel = (state == RS1) ? rs1 : rs2;
  wire [31:0] rval = (rsel == 0) ? 32'd0 : regs[rsel];

  // ALU
  wire [31:0] b = hi;   // rs2
  wire [31:0] b_in = (opcode == OP_REG || opcode == OP_BRANCH) ? b :
                     (opcode == OP_STORE ? imm_s : imm_i);

  // one adder for everything: add, sub, compares, addresses
  // subtract = add the inverted number + 1
  wire        is_cmp = (opcode == OP_REG || opcode == OP_IMM) && (f3 == 3'b010 || f3 == 3'b011);
  wire        do_sub = (opcode == OP_BRANCH) || is_cmp || ((opcode == OP_REG) && (f3 == 3'b000) && ir[30]);
  wire [31:0] yv     = do_sub ? ~b_in : b_in;
  wire [31:0] sum;
  wire        carry;
  adder alu_add (.x(a), .y(yv), .cin(do_sub), .s(sum), .cout(carry));

  // compares are a subtract, so the real operand is ~yv
  wire eq  = ((a ^ yv) == 32'hffffffff);
  wire ltu = ~carry;                                      // no carry out = it borrowed
  wire lt  = (a[31] == yv[31]) ? a[31] : ltu; // signs differ -> less if rs1 is negative

  // one shifter does all three: for a left shift, flip the bits around,
  // shift right, and flip them back
  wire [4:0]  shamt   = b_in[4:0];
  wire        left    = (f3 == 3'b001);
  wire [31:0] a_rev, sh_rev, sh_out;
  genvar k;
  generate
    for (k = 0; k < 32; k = k + 1) begin : rev
      assign a_rev[k]  = a[31 - k];
      assign sh_rev[k] = sh_out[31 - k];
    end
  endgenerate
  wire [31:0] sh_in   = left ? a_rev : a;
  wire        sh_fill = ir[30] & a[31] & ~left;      // sign bit for SRA
  wire [63:0] sh_wide = {{32{sh_fill}}, sh_in} >> shamt;
  assign      sh_out  = sh_wide[31:0];
  wire [31:0] shifted = left ? sh_rev : sh_out;

  reg [31:0] alu;
  always @(*) begin
    case (f3)
      3'b000:  alu = sum;
      3'b001:  alu = shifted;
      3'b010:  alu = {31'd0, lt};
      3'b011:  alu = {31'd0, ltu};
      3'b100:  alu = a ^ b_in;
      3'b101:  alu = shifted;
      3'b110:  alu = a | b_in;
      default: alu = a & b_in;
    endcase
  end

  // branches
  reg take;
  always @(*) begin
    case (f3)
      3'b000:  take = eq;
      3'b001:  take = !eq;
      3'b100:  take = lt;
      3'b101:  take = !lt;
      3'b110:  take = ltu;
      3'b111:  take = !ltu;
      default: take = 0;
    endcase
  end

  // multiply (just the mul half of the M extension)
  // the * was massive, so now it's shift-add, one bit per clock:
  // hi += rs1 if the low bit of lo is set, then shift {hi,lo} right
  // that's an unsigned multiply. for MULH/MULHSU the top half gets fixed after:
  // FIX0: hi -= rs2 if rs1 was negative    (MULH, MULHSU)
  // FIX1: hi -= rs1 if rs2 was negative    (MULH)
  wire        is_mul = (opcode == OP_REG) && (f7 == 7'b0000001);
  wire [32:0] hi_add = hi + (lo[0] ? a : 32'd0);

  // memory bus
  assign mem_req   = (state == FETCH) || (state == MEM);
  assign mem_addr  = (state == FETCH) ? pc : sum[25:0];
  assign mem_size  = (state == FETCH || f3[1]) ? 3'd4 : (f3[0] ? 3'd2 : 3'd1);
  assign mem_we    = (state == MEM) && (opcode == OP_STORE);
  assign mem_wdata = b;

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
          ir    <= mem_rdata;
          state <= RS1;
        end

        RS1: begin
          a     <= rval;
          state <= RS2;
        end

        RS2: begin
          hi    <= rval;
          state <= EXEC;
        end

        EXEC: begin
          if (opcode == OP_LOAD || opcode == OP_STORE) begin
            state <= MEM;
          end else if (is_mul) begin
            hi    <= 0;
            lo    <= b;
            count <= 0;
            state <= MUL;
          end else begin
              if (rd != 0) begin
                case (opcode)
                  OP_LUI:         regs[rd] <= imm_u;
                  OP_AUIPC:       regs[rd] <= {6'd0, pc} + imm_u;
                  OP_JAL, OP_JALR: regs[rd] <= {6'd0, pc + 26'd4};
                  OP_IMM:         regs[rd] <= alu;
                  OP_REG:         regs[rd] <= alu;
                  default: ;
                endcase
              end
              if (opcode == OP_JAL)
                pc <= pc + imm_j[25:0];
              else if (opcode == OP_BRANCH && take)
                pc <= pc + imm_b[25:0];
              else if (opcode == OP_JALR)
                pc <= (a[25:0] + imm_i[25:0]) & ~26'd1;
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

        MUL: begin
          hi    <= hi_add[32:1];
          lo    <= {hi_add[0], lo[31:1]};
          count <= count + 1;
          if (count == 31) begin
            if (f3[1:0] == 2'b00) begin   // MUL wants lo, it's done
              if (rd != 0)
                regs[rd] <= {hi_add[0], lo[31:1]};
              pc    <= pc + 4;
              state <= FETCH;
            end else begin
              state <= FIX0;
            end
          end
        end

        FIX0: begin
          if (a[31] && (f3[1:0] == 2'b01 || f3[1:0] == 2'b10))
            hi <= hi - rval;              // rs2 again, hi doesn't have it any more
          state <= FIX1;
        end

        FIX1: begin
          if (rval[31] && f3[1:0] == 2'b01)
            hi <= hi - a;
          state <= FIX2;
        end

        FIX2: begin
          if (rd != 0)
            regs[rd] <= hi;
          pc    <= pc + 4;
          state <= FETCH;
        end

        default: state <= FETCH;
      endcase
    end
  end

endmodule
