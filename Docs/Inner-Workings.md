
# Inner Workings

This document illustrates how Yosys and SM-EDA work together.

I will be using a modified version of [Resources/Example-1](Resources/Example-1). The width of the register is reduced from 8 to 4 to reduce the size of the images. It's a non-trivial example containing some combinational and sequential logic.

You can follow along using the dedicated tutorial in Example-1 [GUIDE.md](Resources/Example-1/GUIDE.md). Keep in mind that images in this guide require additional tools to create.

```verilog
// Resources/Example-1/design.v
module counter(
  (* device = "button" *)
  (* color = "purple" *)
  input        CLK, // clock port
  (* color = "yellow" *)
  input        RES, // reset
  output [3:0] C
  );

  // Setup a register that holds 8 bits
  reg [3:0] register;
  assign C = register;

  always @(posedge CLK) begin
    if (RES) begin
      // Reset counter to zero if RES is high
      register <= 4'b0;
    end else begin
      register <= register + 1;
    end
  end
endmodule
```

Also, note that the path names below can be abbreviated, and may differ with your setup.

## Entering Yosys

The first step is the invocation of the following command. This command tells Yosys to run the `script.ys` on `design.v`. In a broad sense, this runs synthesis.

```bash
yosys -s /flow/script.ys /working/src/design.v
```

Typically, you won't see Verilog passed via the command line, but instead see Yosys scripts that begin with `read_verilog design.v`. Keep in mind that Yosys scripts generally start with these read commands. But since this script needs to be generic, the loading is done during the invocation above instead.

### Design Hierarchy

These are the first two lines of the command.

```yosys
hierarchy -auto-top
flatten
...
```

Although benign looking, these two commands do important jobs. The `hierarchy` command identifies a top-level module, resolves module references, and generally cleans up the design. For this example, there are no module references, and the only module named "counter" is the top-level module. If the verilog of Example 2 is loaded, the top-level module will be resolved to "soc". The relationship of "soc" using "cpu" and "cpu" using "alu" will be known at this point.

The `flatten` command collapses the hierarchy we just identified. In our case, it does nothing, but if we are using Example 2, it would instantiate "alu" into "cpu", and "cpu" into "soc". Now, there's no "alu" or "cpu", just one module that contains all there is to "soc".

### Basic Synthesis

These commands are mostly standard synthesis commands. They will be found in all synthesis steps.

```yosys
...
proc; opt -full; clean
memory -bram /flow/bram.rule; opt -full
techmap; opt
...
```

The `proc` pass turns `always` blocks in Verilog into logic. After this pass, the design is finally able to be called a proper Netlist. It is very rudimentary right now, but it is a start.

![](/Images/synth0.jpg)

The `memory` pass turns memory into registers and things. It is a techmap for memory. The supplied `bram.rule` is to support Timer memory mapping. If the `memory` pass sees a memory with timer annotation, it will be turned into special modules instead. These special modules will be kept by Yosys. SM-EDA will later recognize it and generate the RAM. But here, we don't have any timer annotated memory. Thus it will do nothing.

The `techmap` pass turns these generic AST-based operators into Yosys internal generic gate-level operators. It turns high-level operators like *mux* and *add* into low-level operators like *nand* and *xor* for example.

![](/Images/synth1.jpg)

### Technology Mapping

The real technology mapping happens here.

```yosys
...
dfflibmap -liberty /flow/sm_cells.lib
abc -liberty /flow/sm_cells.lib -script /flow/script.abc
...
```

First, generic DFFs are mapped to custom ones that SM-EDA recognizes. Yosys's DFF can have many variants, but SM-EDA can only generate DFFs with optional enable and asynchronous reset. Hence, a conversion is necessary. Additional features (like synchronous reset) are emulated by additional circuitry if possible. Features like asynchronous sets cannot be emulated and thus will fail if encountered.

![](/Images/synth2.jpg)

By this point, the circuit has its DFFs mapped, but all the combinational stuff is still untouched. The following command maps all the combinational stuff into SM gates.

```yosys
...
abc -liberty /flow/sm_cells.lib -script /flow/script.abc
...
```

This command invokes `abc` to map the combinational circuits to the cells in `sm_cells.lib` using the `script.abc` script. [ABC](https://github.com/berkeley-abc/abc) is another tool that integrates into Yosys. The script `script.abc` can be cryptic. It tells ABC to run things like `strash` and `fraig` to optimize the design and then use `&nf` to map it to the technology library. There is no reason for you to modify it, except if you want to tweak the optimization to your own needs.

![](/Images/synth3.jpg)

After this step, we have a complete netlist that SM-EDA can understand. Some cells (like `SM_NOR_2`) represent a single SM logic gate. Some (like `SM_PSUDO_DFF_P`) represent a collection of gates that do specific functions.

### Export JSON

The final step is to write the netlist out into a format that SM-EDA can understand.

```yosys
...
write_json tmp/synth.json
```

This netlist JSON is not an SM-EDA netlist, but SM-EDA can understand it. As of right now, this is the only foreign netlist that SM-EDA supports. Don't mistake this for an SM-EDA netlist.

## Entering SM-EDA

We now enter the generation stage of the flow. A blueprint is typically directly built using the following command.

```bash
sm-eda flow /tmp/synth.json /working/blueprint.json
```

But under the hood, it is three commands chained together.

```bash
sm-eda ys2sm /tmp/synth.json /tmp/net.json
sm-eda autoplan /tmp/synth.json /tmp/config.json
sm-eda place /tmp/net.json --config /tmp/config.json /working/blueprint.json
```

When you invoke `sm-eda flow` like above, `/tmp/net.json` and `/tmp/config.json` are never made. These data are passed in memory internally.

### Netlist Transformation

```bash
sm-eda ys2sm /tmp/synth.json /tmp/net.json
```

When ys2sm runs, it does a few things internally. First, it reads and parses the `synth.json` file into the `YSModule` struct. Then, it converts it into an SM-EDA netlist. During this process, the gates that make up the DFFs and Timer Memory are created. This whole process is in [Sources/sm-eda/Transform](/Sources/sm-eda/Transform/) if you wish to read more.

This command also recognizes the `device` and `color` annotations of ports. This allows the `place` command later to generate the port with the requested device and color.

Basic Logic optimization is also done. ABC (in Yosys) limits techmap input size to 6 inputs to prevent SAT solvers from going wild, but SM logic gates can take up to 256 inputs. For example, ABC will generate 2 AND gates to create a 7 input AND. SM-EDA does some peephole optimization to clean up such redundant logic that may be left over by Yosys and the Transformation process.

This command also balances the clock chain such that all registers will be synchronized. This is not a problem in this scenario, but if there are more than 256 DFFs in the design, a proper clock tree is necessary.

![](/Images/synth4.jpg)

This finally looks like something that can be made from scrap mechanic logic. The blue gates are marked as sequential. You can even identify the XOR loops that make up each register.

The printout of the ys2sm command is also important. For example, it tells you the length of the critical path of your circuit, as well as the number of gates generated.

```txt
Design:
   critical depth: 7 (0.175s)
   gate count: 38, conn. count: 74
```

### Blueprint Generation

Now, it's simply a matter of generating blueprints from this netlist. But before SM-EDA can create a blueprint, it needs to know what the physical geometry of the blueprint is going to be. A user can provide a Placement Config in the form of another JSON file to control the exact placement behavior, but SM-EDA can also generate a barebone one for you. You can use the `autoplan` command.

```bash
sm-eda autoplan /tmp/net.json /tmp/config.json
```

Scrap Mechanic is an interesting game in that logic wiring doesn't take up space, and thus, a circuit can be built with any arbitrary placement of gates. Thus, SM-EDA doesn't need to do sophisticated PnR. What matters more here is usability and looks. The `autoplace` command simply places the gates in a rectangular fashion. You can customize how placement happens with command-like arguments.

For example, the `--facade` argument rotates the outside visible gates of the blueprint in random directions to make the blueprint look more organic. The `--pack` argument packs the ports more compactly, instead of ordering them in an otherwise strict alphabetical order.

The generated Placement Config is important. It contains vital information, like how ports are automatically laid out. Without this config, you wouldn't know which gate is what port in the generated blueprint. Below is a snippet of `/tmp/config.json`, look how the ports are arranged.

```txt
"ports" : [
  "C[3:0]",
  "CLK[0:0],RES[0:0]"
],
```

This tells you that the port is arranged in a 2x4 pattern like this:

```txt
  A[3]   A[2]   A[1]   A[0]
UNUSED UNUSED CLK[0] RES[0]
```

Then, you can invoke the place command to use the generated config to turn the netlist into blueprints.

```bash
sm-eda place /tmp/net.json --config /tmp/config.json /working/blueprint.json
```

You should now see the `blueprint.json` in the working folder. Now, you can take this blueprint and use it inside the game.

As a side note, the `autoplace` command performs `autoplan` and `place` in one go. The config is generated and passed in memory and never written to disk. Run `sm-eda autoplace -h` to learn more.
