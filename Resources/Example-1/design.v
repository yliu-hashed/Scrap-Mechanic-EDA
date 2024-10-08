module counter(
  (* device = "button" *)
  (* color = "purple" *)
  input        CLK, // clock port
  (* color = "yellow" *)
  input        RES, // reset
  output [7:0] C
  );

  // Setup a register that holds 8 bits
  reg [7:0] register;
  assign C = register;

  always @(posedge CLK) begin
    if (RES) begin
      // Reset counter to zero if RES is high
      register <= 8'b0;
    end else begin
      register <= register + 1;
    end
  end
endmodule
