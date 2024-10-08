
# Scrap Mechanic Logic Limitation

Before you go out and design complex circuits, there is one fact you should know: **Scrap Mechanic can only load blueprints below roughly 20K gates.** The exact number is difficult to predict.

We've tried to determine the blueprint size limit many times. The following message appears in the log when a blueprint is too large. In the game, it will appear that loading a blueprint has no effect, or on very rare occasions, will crash the game directly.

```
[Network] ERROR: ...redacted...
  Sending packet is too large: 2177803, limit: 524288
```

After reverse engineering parts of the game, we've managed to track this down. The internal structure of Scrap Mechanic is broken into the frontend and backend. The frontend handles game appearance, while the backend handles game logic. Even in single-player mode, this structure exists. Both ends interact through an internal network. Loading a blueprint requires the frontend to send a packet to the backend, and such packets have a size limit.

Such packet contains the compressed blueprint JSON. This means that if two blueprints that differ in organizations (but otherwise identical) are loaded, the one with fields randomly ordered is significantly larger than that with fields sorted alphabetically. The compression is done via [LZ4](https://github.com/lz4/lz4), it's fast but it doesn't have the best compression ratio.

SM-EDA tries its best to reduce entropy by sorting JSON fields. However, a large design (small in the FPGA and ASIC domain) will still become too large for the game to handle. As a rule of thumb:

| Numb. of Gates | Chance |
| --- | --- |
| 0 to 10K | OK |
| 10K to 15K | Probably OK |
| 15K to 20K | Tricky |
| 20K+ | Impossible |

For a blueprint above 15K, it can become spontaneously oversized after you've fiddled with it in-game. Because the compression has to work very hard, it is very possible that by modifying it slightly (like integrating it into an existing small contraption), you've changed the internal JSON format in such a way that it no longer compresses below the limit.

It is also possible to oversize a world file, as individual creations in a world file may be subjected to the same limitation. You may, for example, weld two smaller blueprints, exit the game, and find out that you can never load the world again.

### Knowing the Size

Since [LZ4](https://github.com/lz4/lz4) is a popular algorithm, we can know the compressed size of the blueprint before loading it in-game by running it ourselves. The packet size equals the size of the output file (after running the following command) minus two bytes.

```bash
# replace 'blueprint.json' with your own blueprint
# 'blueprint.json.lz4' will be generated
lz4 --no-frame-crc -BD blueprint.json
# note: get file size in byte, not disk usage
```

To get accurate size information during blueprint generation, SM-EDA `place` and `flow` command will automatically discover LZ4 and run it. **LZ4 is preinstalled on our Docker container.** You can install the LZ4 command line tool on your machine from the official website [lz4.org](lz4.org) if you also run a local installation of SM-EDA. If SM-EDA still can't find the path to the LZ4 executable, use `--lz4-path <path>` to specify it manually.

You may see one of the following messages when you run `sm-eda place` or `sm-eda flow`:

```
1. Warning: Blueprint is below the limit (79.84%), but it may fail to import spontaneously later. Conservative utilization is 132.59%. Please proceed with caution.

2. Warning: Blueprint is very large 97.5%. It will likely fail to import. Please proceed with caution.

3. Warning: Blueprint is above the limit by 17.49%. It will likely fail to import.
```

These warnings are there to tell you that the blueprint

1. rely heavily on compression to meet the limit.
2. is close to the limit.
3. is above the limit.

**Conservative Size** is the estimated size of the blueprint if its fields are randomly ordered. Hence, this is the size if the compression algorithm cannot compress the blueprint as effectively as before (like if you changed it heavily, or integrated it into an existing large design). As the name suggests, this is very conservative.

### Recommendations

For the reasons listed, you should always be cautious when working with large blueprints, and you should not rely on compression to make your blueprint work. 10K gates is a good target. A blueprint with 10K gates is almost impossible to be oversized no matter how little the compression worked.

Meanwhile, a smaller design will result in a smaller blueprint (obviously), but knowing where to cut is difficult. D-Flip Flops are about 6 gates each, and thus reducing the number of redundant flip-flops may yield a smaller blueprint, although at the cost of more combinational hardware.
