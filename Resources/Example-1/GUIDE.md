
# Example 1 - Sample Flow

The sample flow contains the steps to generate a blueprint from a single Verilog file. An example design file is found in [design.v](design.v). It is the same as the first quick-look in the [README](/README) file. You can write your own module in Verilog.

## Setup

Begin by creating a common folder to contain the design and temporary files. This folder should contain at least the Verilog sources. You can use an empty folder and add your Verilog sources later. Make sure you keep this folder tidy, as you will be navigating inside it using commands, not GUI.

Then, open a terminal window and navigate to the project path using the `cd` command. On some systems, higher privilege is required to run `docker`. Then start up the docker container and mount the project folder using the following command:

```bash
docker run -rm -it --name example --mount type=bind,source="./",target=/working ghcr.io/yliu-hashed/sm-eda-bundle:latest bash
```

This will boot a container and enter bash in interactive mode. It will also mount the current directory as `/working` into the container. The name for this new container is set to `example`. You can choose any name.

You should now see that you've entered into a Linux command line. This is the shell of the container you just created. You should now be able to see the contents of the container using `ls` and the contents of the mounted directory using `ls /working`.

## Run Yosys

You should now add your Verilog sources to this working folder. For this guide, we assume your design is `src/design.v`. You should verify that this file has synced to the docker container by running `ls` again.

```bash
ls /working/src
# you should see `design.v`
```

Here, we will use the default synthesis script. This script has limited functionality. The next guide, [Example 2](/Resources/Example-2/GUIDE.md), describes creating a more complex multi-step project, automating the build commands using `make`, and specifying custom scripts. For now, run Yosys using the default script using the following command:

```bash
yosys -s /flow/script.ys /working/src/design.v
```

If everything works well, you should see that `/tmp/synth.json` is generated inside the container. This is the Yosys output JSON.

```bash
ls /tmp
# you should see `synth.json`
```

Note that the directory `/tmp` is only inside the container. It is not mounted to the host. This file will be lost after you stop the container.

## Run `sm-eda flow`

Then, use `sm-eda flow` to generate a blueprint using the following command:

```bash
# Terminal 1
sm-eda flow -v --depth 2 --width 8 --portFrontOnly /tmp/synth.json /working/blueprint.json
```

Note: Use `sm-eda flow -h` to find out the meaning of each argument.

Now, you should see that `blueprint.json` is generated in the working folder, both in the docker container, and on your host machine.

## Exit the Container

You can now safely stop the container using the following commands:

```bash
exit
```

You should now return to the shell of your host machine. Note that this container is launched with the `--rm` flag, and will be deleted automatically once it stops.
