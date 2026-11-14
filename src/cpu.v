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
  localparam WB    = 4'd5;
  localparam MUL   = 4'd6;
  localparam FIX0  = 4'd7;
  localparam FIX1  = 4'd8;
  localparam FIX2  = 4'd9;

  reg [3:0]  state;
  reg [25:0] pc;
  reg [31:0] ir;
  reg [31:0] a;        // rs1
  reg [31:0] hi;       // rs2, then the high half of a multiply
  reg [31:0] lo;       // result / low half of a multiply
  reg [31:0] yv;       // second ALU operand, already flipped if we're subtracting
  reg        sub;      // ...and whether we are
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

  wire is_reg    = (opcode == OP_REG);
  wire is_branch = (opcode == OP_BRANCH);
  wire is_store  = (opcode == OP_STORE);
  wire is_mul    = is_reg && (f7 == 7'b0000001);

  // register file, x0 is always 0
  // one read port: rs1 in RS1, rs2 everywhere else
  wire [3:0]  rsel = (state == RS1) ? rs1 : rs2;
  wire [31:0] rval = (rsel == 0) ? 32'd0 : regs[rsel];

  // one write port, always from lo
  always @(posedge clk) begin
    if (state == WB && rd != 0) regs[rd] <= lo;
  end

  // ALU
  wire [31:0] b = hi;   // rs2

  // second operand: rs2 for register ops and branches, otherwise an immediate.
  // this all gets worked out in RS2 and latched into yv, already inverted if
  // it's a subtract, so EXEC can start adding straight away (GF180 is slow!)
  wire is_alu  = is_reg || (opcode == OP_IMM);
  wire is_cmp  = is_alu && (f3 == 3'b010 || f3 == 3'b011);   // SLT, SLTU
  wire do_sub  = is_branch || is_cmp || (is_reg && f3 == 3'b000 && ir[30]);
  wire [31:0] y_next = (is_reg || is_branch) ? rval : (is_store ? imm_s : imm_i);

  // one adder for everything: add, sub, compares, addresses
  // subtract = add the inverted number + 1
  wire [31:0] sum;
  wire        carry;
  adder alu_add (.x(a), .y(yv), .cin(sub), .s(sum), .cout(carry));

  // compares only happen when sub = 1, so the real operand is ~yv
  wire eq  = ((a ^ yv) == 32'hffffffff);
  wire ltu = ~carry;                                      // no carry out = it borrowed
  wire lt  = (a[31] == yv[31]) ? a[31] : ltu;             // signs differ -> a is less if a is negative

  wire [31:0] y = yv;   // for and/or/xor/shifts (never a subtract, so not inverted)

  // one shifter does all three: for a left shift, flip the bits around,
  // shift right, and flip them back
  wire [4:0]  shamt   = y[4:0];
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
  wire        sh_fill = ir[30] & a[31] & ~left;            // sign bit for SRA
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
      3'b100:  alu = a ^ y;
      3'b101:  alu = shifted;
      3'b110:  alu = a | y;
      default: alu = a & y;
    endcase
  end

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

  // jumps, branches and auipc all share one pc adder
  wire [31:0] pc_off = (opcode == OP_JAL) ? imm_j : (is_branch ? imm_b : imm_u);
  wire [25:0] pc_imm = pc + pc_off[25:0];
  wire [25:0] pc4    = pc + 26'd4;

  // what EXEC puts in lo
  reg [31:0] result;
  always @(*) begin
    case (opcode)
      OP_LUI:          result = imm_u;
      OP_AUIPC:        result = {6'd0, pc_imm};
      OP_JAL, OP_JALR: result = {6'd0, pc4};
      default:         result = alu;    // OP, OP-IMM
    endcase
  end

  wire writes_rd = (opcode == OP_LUI) || (opcode == OP_AUIPC) || (opcode == OP_JAL) ||
                   (opcode == OP_JALR) || (opcode == OP_IMM) || is_reg;

  // multiply
  // MUL:  hi += a if the low bit of lo is set, then shift {hi,lo} right
  // FIX0: lo = rs2 (lo isn't needed any more for MULH*)
  // FIX1: hi -= rs2 if rs1 was negative    (MULH, MULHSU)
  // FIX2: lo = hi - rs1 if rs2 was negative (MULH)
  wire        fix1_on = a[31] && (f3[1:0] == 2'b01 || f3[1:0] == 2'b10);
  wire        fix2_on = lo[31] && (f3[1:0] == 2'b01);
  reg  [31:0] addend;
  always @(*) begin
    case (state)
      MUL:     addend = lo[0] ? a : 32'd0;
      FIX1:    addend = fix1_on ? ~lo : 32'hffffffff;   // -rs2, or -0 (the +1 below fixes it)
      default: addend = fix2_on ? ~a  : 32'hffffffff;   // -rs1
    endcase
  end
  wire [32:0] hi_add;
  adder mul_add (.x(hi), .y(addend), .cin(state != MUL), .s(hi_add[31:0]), .cout(hi_add[32]));

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
          yv    <= do_sub ? ~y_next : y_next;
          sub   <= do_sub;
          state <= EXEC;
        end

        EXEC: begin
          lo <= result;

          if (opcode == OP_LOAD || opcode == OP_STORE) begin
            state <= MEM;
          end else if (is_mul) begin
            hi    <= 0;
            lo    <= b;
            count <= 0;
            state <= MUL;
          end else begin
            if (opcode == OP_JAL || (is_branch && take))
              pc <= pc_imm;
            else if (opcode == OP_JALR)
              pc <= (a[25:0] + imm_i[25:0]) & ~26'd1;
            else
              pc <= pc4;
            state <= writes_rd ? WB : FETCH;   // fence, ecall, csr etc. just skip
          end
        end

        MEM: if (mem_done) begin
          if (is_store) begin
            pc    <= pc4;
            state <= FETCH;
          end else begin
            lo    <= load_val;
            state <= WB;
          end
        end

        WB: begin
          // register write happens in the always block up top
          if (opcode == OP_LOAD || is_mul) pc <= pc4;   // the others moved pc in EXEC
          state <= FETCH;
        end

        MUL: begin
          // classic shift-add, one bit per clock
          hi    <= hi_add[32:1];
          lo    <= {hi_add[0], lo[31:1]};
          count <= count + 1;
          if (count == 31)
            state <= (f3[1:0] == 2'b00) ? WB : FIX0;   // MUL wants lo, it's done
        end

        FIX0: begin
          lo    <= rval;                  // rs2 again
          state <= FIX1;
        end

        FIX1: begin
          hi    <= hi_add[31:0];
          state <= FIX2;
        end

        FIX2: begin
          lo    <= hi_add[31:0];
          state <= WB;
        end

        default: state <= FETCH;
      endcase
    end
  end

endmodule
