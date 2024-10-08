
// OPCODE TABLE
// | Opcode    | Function
// |-----------|------------------------------
// |           |   GENERAL INSTRUCTIONS
// | 0000 LD   | RA = MEM[RB]
// | 0001 ST   | MEM[RB] = RA
// | 0010 SGT  | RA = (RA > RB) ? 1 : 0
// | 0011 SEQ  | RA = (RA == RB) ? 1 : 0
// | 0100 JAL  | Jump to RB ; RA = PC+1
// | 0101 BGZ  | Jump to RB if RA > 0 (signed)
// | 0110 BNZ  | Jump to RB if RA != 0
// | 0111 BEZ  | Jump to RB if RA == 0
// |           |   ALU INSTRUCTIONS
// | 1000 ADD  | RA = RA + RB
// | 1001 SUB  | RA = RA - RB
// | 1010 NAND | RA = ~(RA & RB)
// | 1010 OR   | RA = RA | RB
// | 1011 XOR  | RA = RA ^ RB
// | 1100 SHL  | RA = RA << RB
// | 1101 SRL  | RA = RA >> RB (logical)
// | 1110 SRA  | RA = RA >> RB (arithmetic)

module cpu(
  input        clk,         // universal clock port
  input        rst,         // reset port
	input        hlt,         // halt (pause exec for one cycle)

  // fetch port
  input  [7:0] i_inst,      // the input instruction (on address `o_inst_addr`)
  output [7:0] o_inst_addr, // the output instruction address

  // data port
  input  [7:0] i_data,      // the input data (on address `o_inst_addr`) for read
  output [7:0] o_data_addr, // the output address (to read or write)
  output [7:0] o_data_data, // the output data (to write)
  output       o_data_we    // whether the access is write (or not read)
  );

  // PC register
  reg [7:0] r_pc = 8'b0;

  // The main register bank. It is a array of registers, a "memory" to be exact.
  // It is 4 of 8 bit registeds.
  reg [7:0] r_regs [0:3];

  // Split instructions into it's opcode, register A, and B.
	// Note that `i_inst` is the input port of fetch.
  wire [3:0] opcode = i_inst[7:4];
  wire [1:0] reg_a_num = i_inst[3:2];
  wire [1:0] reg_b_num = i_inst[1:0];

  // Grab the register content from register bank
  wire [7:0] reg_a = r_regs[reg_a_num];
  wire [7:0] reg_b = r_regs[reg_b_num];

  // Create a wire to bind to the alu output port
  wire [7:0] alu_output;

  // Instantiate an alu instance named `alu_inst`, and bind wires like register
  // read contents, alu-specific opcode, and alu output.
  alu alu_inst (
    .i_a(reg_a),
    .i_b(reg_b),
    .i_op(opcode[2:0]),
    .o_v(alu_output)
  );

  // Assign the output instruction fetch address port to be the PC register
  assign o_inst_addr = r_pc;
  // Assign the data port address to be `reg_b`. It may not always be a memory
  // instruction, but if there is one, address is reg_b.
  assign o_data_addr = reg_b;
  // Assign the data port write data to be `reg_a`. It may not always be a store
  // instruction, but if there is one, the data to store is reg_a.
  assign o_data_data = reg_a;
  // Assign the data port write signal to true if it is a write instruction, and
  // no reset is happening.
  assign o_data_we = !rst && (opcode == 4'b0001);

  // This is a clocked `always` block. The content inside this block only `runs`
  // if the `clk` signal is rising from low to high (hence `posedge clk`). This
  // makes the assignments in this block behaves like a register, which is what
  // we want. Note all assignment is edge assignment `<=`, not continuous `=`.
  // Note: go into `src/alu.v` to see the combinational counterpart of `always`.
  always @(posedge clk) begin
    if (rst) begin
      // If reset is happening, set pc to 0, and clear all registers.
      r_pc <= 8'b0;
      r_regs[0] <= 8'b0;
      r_regs[1] <= 8'b0;
      r_regs[2] <= 8'b0;
      r_regs[3] <= 8'b0;
    end else if (!hlt) begin
			// Only do work while not halted (not paused).

      // Increment the PC. In case a branch (jump) is taking place, the later
      // assignment will override this assignment.
      r_pc <= r_pc + 8'b1;
      // Switch behavior based on opcode
      casex (opcode)
        4'b0000: begin // LD
          // Set the register of the load to the loaded data.
          r_regs[reg_a_num] <= i_data;
        end
        4'b0001: begin // ST
          // There's nothing sequencial to do in store. All proper signals are
          // asserted in the ports.
        end
        4'b0010: begin // SGT
          // Compare two signed registers A and B, and store 1 into A if A > B
          r_regs[reg_a_num] <= ($signed(reg_a) > $signed(reg_b)) ? 8'b1 : 8'b0;
        end
        4'b0011: begin // SEQ
          // Compare two registers A and B, and store 1 into A if A == B
          r_regs[reg_a_num] <= (reg_a == reg_b) ? 8'b1 : 8'b0;
        end
        4'b0010: begin // JAL
          // Jump to B and store A the next PC of return address
          r_pc = reg_b;
          r_regs[reg_a_num] <= r_pc + 8'b1;
        end
        4'b0011: begin // BGZ
          // Branch to B if register A is larger than 0
          if ($signed(reg_a) > 0) begin
            r_pc <= reg_b;
          end
        end
        4'b0010: begin // BNZ
          // Branch to B if register A is not zero
          if (|reg_a) begin
            r_pc <= reg_b;
          end
        end
        4'b0011: begin // BEZ
          // Branch to B if register A is zero
          if (~|reg_a) begin
            r_pc <= reg_b;
          end
        end
        // This condition matches all values of opcode with highest bit being
        // high, which are all the ALU instructions.
        4'b1???: begin
          // Take the alu result (from the alu module) and put it in A
          r_regs[reg_a_num] <= alu_output;
        end
      endcase
    end
  end

endmodule
