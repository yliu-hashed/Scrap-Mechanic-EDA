
# Example 2 - Sample Project

This section illustrates how to create a project that contains several Verilog modules, and generates several Verilog designs. A project allows you to iterate your design quickly.

## Overview

Here, we will create a simple 8-bit CPU. Do not use this CPU. It's very bad.

For the sake of conciseness, the Verilog code will not be explained here. The sources themselves are commented on very verbosely. You can use it as a guide to create basic modules of your own.

This CPU is split into 2 modules, the ALU and the CPU itself. A [Makefile](Makefile) is already written to create the CPU automatically.

## Building the Project

First, pull the docker image by running the following command.
```bash
docker pull ghcr.io/yliu-hashed/sm-eda-bundle:latest
```

Then, `cd` into the directory for `Example-2` and run GNU Make using the following command:
```bash
cd [path to Example-2]
make setup
make
```

A call to `make setup` is to create empty folders `tmp`, `blueprints`, and `logs` that need to be there (but ignored by Github implicitly).

If everything worked correctly, you should see `soc.json` magically appear under `Example-2/blueprints`. It's that simple because GNU Make runs the commands for us.

## The Makefile

The `make` command invokes the [Makefile](Makefile) in the `Example-2` directory. In the `Makefile`, there are command invocations of Yosys and SM-EDA using the docker image.

A Makefile is a build-step sequencer. People use it to save time typing tedious repetitive commands. A Makefile is made up of many rules. A rule includes a list of commands to produce a given file. Make allows you to specify prerequisites to produce a file so that the output is regenerated only when its prerequisites are changed. A rule looks like this:

```Makefile
[target files]: [prerequisite files]
	[commands to produce the target files]
	[commands ...]
# note: must indent with tab, not spaces
```

Our [Makefile](Makefile) contains three rules, each for one step of the design. When we run the `make` command, it looks for the `all` directive.

```Makefile
all: blueprints/soc.json
```

This tells Make that the final artifact for this project is `blueprints/soc.json`. It will then recursively run the command in each rule to produce the final artifact.

### 1. Synthesis

```Makefile
tmp/soc_synth.json: src/soc.v src/cpu.v src/alu.v
	$(call DOCKER_RUN,yosys -q resources/script.ys)
```

The first rule produces `tmp/soc_synth.json` from the Verilog sources using yosys. It runs `yosys -q resources/script.ys` inside the docker container.

A make `DOCKER_RUN` function is made to make the Makefile more readable. This function is defined above. The line `$(call DOCKER_RUN,yosys -q resources/script.ys)` expands to a full command in runtime:
```Bash
docker run --rm --mount type=bind,source="$(MKFILE_DIR)",target=/working ghcr.io/yliu-hashed/sm-eda-bundle:latest bash -l -c "cd working && yosys -q resources/script.ys"
```

It essentially spins up an instance of the image, binds the project directory as `/working`, cd into `/working`, and runs `yosys -q resources/script.ys`. It does this all in one go, and after it finishes, the instance is removed.

The `script.ys` is a custom synthesis script. It reads all three Verilog sources, flattens them, and produces a single netlist JSON file in the yosys JSON format under `tmp/soc_synth.json`.

```yosys
# script.ys
read_verilog src/alu.v
read_verilog src/cpu.v
read_verilog src/soc.v
hierarchy -top soc
...
write_json tmp/soc_synth.json
```

After this point, `tmp/soc_synth.json` is created.

### 2. Conversion

```Makefile
tmp/soc_model.json: tmp/soc_synth.json
	$(call DOCKER_RUN,sm-eda ys2sm --clk clk tmp/soc_synth.json tmp/soc_model.json)
```

The second rule converts the Yosys JSON to SM netlist format. The `--clk clk` argument ensures that `ys2sm` will balance the clock named `clk` to all DFFs. The `-N <out>` argument specifies that a netlist will be written out (not a blueprint).

After this point, `tmp/soc_model.json` is created.

This step can be fused with the next step by directly emitting a blueprint with the `-B <bp>` argument. However, it is kept separate to facilitate other potential operations you might need to do, like merging in other netlists or doing simulations with it.

### 3. Blueprint Generation

```Makefile
blueprints/soc.json: tmp/soc_model.json
	$(call DOCKER_RUN,sm-eda place $(BP_ARGS) -v tmp/soc_model.json blueprints/soc.json > logs/soc.log)
```

The third rule converts the SM netlist into a blueprint `blueprints/soc.json`. `BP_ARGS` is a variable containing arguments that describe how the blueprint will be placed. Here, it's equal to `--depth 8 --width 8`.

The extra `... > logs/soc.txt` suffix writes the output of the `place` command into a file in `logs/soc.txt`. This is so that the timing values and port locations of the blueprint are recorded for use later in-game.

### What chains all this?

No place in this Makefile has the sequence that these commands need to run at. The very line `all: blueprints/soc.json` is enouph to tell Make what to do.

It simply sees that:

* to make `blueprints/soc.json` needs `tmp/soc_model.json`.
* to make `tmp/soc_model.json` needs `tmp/soc_synth.json`
* to make `tmp/soc_synth.json` needs `src/soc.v`, `src/cpu.v`, and `src/alu.v`

It will then generate these in the reverse order of discovery, effectively running the commands in the order that we talked about.

### But, where is Docker?

As we talked about, the docker command is abstracted away inside the Make function `DOCKER_RUN`. You can find the following lines in the make file that sets this up:

``` Makefile
DOCKER_IMAGE = ghcr.io/yliu-hashed/sm-eda-bundle:latest
DOCKER_ARGS = run --rm --mount type=bind,source="$(MKFILE_DIR)",target=/working $(DOCKER_IMAGE)
DOCKER_RUN = docker $(DOCKER_ARGS) bash -l -c "cd working && $(1)"
```

When `$(call DOCKER_RUN,<cmd>)` is invoked. It is expanded into the full command:

```bash
docker run \
  --rm \
  --mount type=bind,source="$(MKFILE_DIR)",target=/working \
  ghcr.io/yliu-hashed/sm-eda-bundle:latest \
  bash -l -c "cd working && <cmd>"
```

* `--rm` tells docker to remove the container once it exits
* `--mount` tells docker to mount the current directory to the container's path `/working`.
* `ghcr.io/...` specifies the image
* `bash -l -c "..."` tells docker to invoke bash, effectively running `cd working` and `"stuff"` inside the container.

Since the current working directory is mounted into the image, the effect of the container is visible to the host, and thus `docker cp ...` is not needed.

## Additional Notes

Using make is recommended even though it is very intimidating. But the efforts pay off quickly as you no longer have to remember the lengthy commands required to get your design generated, let alone needing the spin up an interactive container every time you need to do something.

This simple project may seem trivial, but GNU Make is an incredibly powerful tool. You can create complex steps to generate a blueprint and run it as many times as you want. When chained with other powerful external tools like `iverilog` or in SM-EDA like `sm-net-edit`, you can create truly complex designs. You can, for example:

1. Unit test the design with `iverilog` every time you change your Verilog source
2. Design complex circuits that use timer-memory bank
3. Have `gcc` compile a C program, and generate a ROM attached to a processor blueprint in one go
4. Create a circuit in Scrap Mechanic and an FPGA at the same time with identical behavior
