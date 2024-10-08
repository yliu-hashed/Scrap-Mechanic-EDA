
// This module is the combinational ALU of the cpu.

module alu(
  input  [7:0] i_a,  // the first operand in 8 bits
  input  [7:0] i_b,  // the second operand in 8 bits
  input  [2:0] i_op, // the opcode in 3 bits
  output [7:0] o_v   // the output value in 8 bits
  );

  // A phantom register that ALU values are placed in. This reg is not clocked,
  // it turns into a combinational wire. In Verilog, `reg` doesn't always mean
  // register, but a place to put values where a `always` block can write to.
	// The behavior of a reg depends on the construction of the `always` block
	// that uses it.
  reg [7:0] v;

  // This assigns the value of the register to the output port. You can
	// alternately write `output reg [7:0] o_v` for output instead.
  assign o_v = v;

  // This is a `always` block that is sensitive to every wire that it's using.
  // It is a shorthand for `always @(i_a or i_b or i_op)`. Conceptually, the
	// block `runs` for every signal change of every wire. Hence, it is a
	// combinational logic using wires `i_a`, `i_b`, and `i_op`.
  always @(*) begin
    // A case statement is a switch statement in verilog. You don't have to
    // `break` in Verilog. It can be read as: assign `v` to `i_a + i_b` if
    // `i_op == 3'b000`, or if ...  Basically, it is a mux.
    case (i_op)
      3'b000: v = i_a + i_b;
      3'b001: v = i_a - i_b;
      3'b010: v = ~(i_a & i_b);
      3'b011: v = i_a ^ i_b;
      3'b100: v = i_a | i_b;
      3'b101: v = i_a << i_b;
      3'b110: v = i_a >> i_b;
      // this is a arithmatic shift of signed `i_a` by `i_b` bits.
      3'b111: v = $signed(i_a) >>> i_b;
    endcase
  end
endmodule
