all: blueprints/soc.json

# Get current directory
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILE_DIR := $(dir $(MKFILE_PATH))

# Create a function to run command in the docker directory
DOCKER_IMAGE = ghcr.io/yliu-hashed/sm-eda-bundle:latest
DOCKER_ARGS = run --rm --mount type=bind,source="$(MKFILE_DIR)",target=/working $(DOCKER_IMAGE)
DOCKER_RUN = docker $(DOCKER_ARGS) bash -l -c "cd working && $(1)"

# Argument for blueprint generation

# Synthesis for soc ------------------------------------------------------------
## verilog --yosys-> synth
tmp/soc_synth.json: src/soc.v src/cpu.v src/alu.v resources/script.ys
	$(call DOCKER_RUN,yosys -q resources/script.ys)

## synth --ys2sm-> model
tmp/soc_model.json: tmp/soc_synth.json
	$(call DOCKER_RUN,sm-eda ys2sm --clk clk tmp/soc_synth.json tmp/soc_model.json)

## model --place-> blueprint
blueprints/soc.json: tmp/soc_model.json resources/config.json
	$(call DOCKER_RUN,sm-eda place -v --config resources/config.json tmp/soc_model.json blueprints/soc.json > logs/soc.log)

# Subcommands
.PHONY: clean cleantmp

setup:
	mkdir -p tmp
	mkdir -p blueprints
	mkdir -p logs

clean:
	rm -rf tmp
	rm -rf blueprints
	rm -rf logs
	mkdir tmp
	mkdir blueprints
	mkdir logs

cleantmp:
	rm -rf tmp
	mkdir tmp
