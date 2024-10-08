
module soc(
	input        clk,    // universal clock port
	input        rst,    // reset port
  input        hlt,    // halt
  // user port
	input  [7:0] i_addr, // memory access address
	input  [7:0] i_data, // data to write
  input        i_we,   // write enable control
	output [7:0] o_data  // read data
	);

  // This is the main memory. It is a array of 256 registers of 8 bit width.
  // The memory is implemented with timer loops of 16 tick duration.
  (* timer = "16" *)
  reg [7:0] memory [0:255];

  // Assign output data to the memory index by the supplied address.
  assign o_data = memory[i_addr];

  // Wires to bind to CPU
  wire [7:0] cpu_iaddr;
  wire [7:0] cpu_daddr;
  wire       cpu_we;
  wire [7:0] cpu_wdata;

  // memory write port multiplex
  wire [7:0] write_we    = i_we || (cpu_we && !hlt);
  wire       write_stall = i_we && (cpu_we && !hlt);
  wire [7:0] write_data  = i_we ? i_data : cpu_wdata;
  wire [7:0] write_addr  = i_we ? i_addr : cpu_daddr;

  always @(posedge clk) begin
    if (write_we) begin
      memory[write_addr] <= write_data;
    end
  end

  // Instantiate a CPU instance
  cpu cpu_inst (
    .clk(clk),
    .rst(rst),
    .hlt(write_stall || hlt),
    .i_inst(memory[cpu_iaddr]),
    .i_data(memory[cpu_daddr]),
    .o_inst_addr(cpu_iaddr),
    .o_data_addr(cpu_daddr),
    .o_data_we(cpu_we),
    .o_data_data(cpu_wdata)
  );
endmodule
