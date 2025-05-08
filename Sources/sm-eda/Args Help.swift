//
//  Args Help.swift
//  Scrap Mechanic EDA
//

import ArgumentParser

let kPrettyPrintArgHelp = ArgumentHelp(
    "Write all json file with readable formatting",
    valueName: "pretty-json"
)

let kPrintLevelArgHelp = ArgumentHelp(
    "The amount of information to print to the console",
    valueName: "print-level"
)

let kInputDeviceArgHelp = ArgumentHelp(
    "The input device connected to the gate",
    discussion: "This sets the default input device for the blueprint. The input device type attribute overrides this property on a per-port level. Use Yosys design attribute '(* device = \"switch/button/none\" *)' or SM Module attribute 'i_port_device.PORT_NAME' with value 'switch/button/none' to specify per-port device.",
    valueName: "device"
)

let kBPWidthArgHelp = ArgumentHelp(
    "The width to wrap the ports of the blueprint",
    discussion: "This specifies the maximum width of the blueprint. If no value is given, the maximum width of any port clamped to 16 will be used as the width of the module.",
    valueName: "width"
)

let kBPDepthArgHelp = ArgumentHelp(
    "The depth of the blueprint",
    discussion: "This specifies the depth of the blueprint. If no value is given, a depth no larger than 32 that results in height that cover all ports is used.",
    valueName: "depth"
)

let kNoFacadeArgHelp = ArgumentHelp(
    "Do not generate a facade for the blueprint",
    discussion: "This option disables the generation of gates with random orientation. Facade is used to make the blueprint look better, but it may make the design bigger (in utilization).",
    valueName: "no-facade"
)

let kPortLocationArgHelp = ArgumentHelp(
    "The location of the ports of the blueprint",
    discussion: "Ports can be placed in the front only, or in both the front and back.",
    valueName: "port-side"
)

let kPackPortArgHelp = ArgumentHelp(
    "Pack port freely instead of alphabetically",
    discussion: "This option makes the port faces smaller.",
    valueName: "pack-port"
)

let kConfigArgHelp = ArgumentHelp(
    "The placement configuration for the module",
    discussion: "Use this option to influence the placement of the module. The placement configuration is a JSON file that defines the placement rules for the module. When this option is specified, the module placement is only determined by the rules defined in the JSON file, and command line options are ignored.",
    valueName: "config"
)

let kLZ4PathArgHelp = ArgumentHelp(
    "The path to the LZ4 executable",
    discussion: "Use this parameter to specify the path to LZ4 to accurately estimate blueprint size. If not specified, the path to the LZ4 executable is searched by asking the shell `which lz4`.",
    valueName: "lz4-path"
)

let kSrcNetFileArgHelp = ArgumentHelp(
    "The path of the netlist json file to read",
    valueName: "in-net-json"
)

let kOutNetFileArgHelp = ArgumentHelp(
    "The path of the netlist json file to write",
    valueName: "out-net-json"
)

let kSrcYSJsonFileArgHelp = ArgumentHelp(
    "The path of the yosys json file to read",
    discussion: "SM-EDA uses Yosys as its detached HDL frontend. Use `write_json` in Yosys to generate a json file.",
    valueName: "in-yosys-json"
)

let kOutBPFileArgHelp = ArgumentHelp(
    "The path of the blueprint json file to write",
    valueName: "out-blueprint"
)

let kOutReportFileArgHelp = ArgumentHelp(
    "The path of the json report to write",
    valueName: "out-report"
)

let kClockDomainArgHelp = ArgumentHelp(
    "The clock domain of the design",
    discussion: "Repeat the same argument to specify multiple clock domains.",
    valueName: "clock-domain"
)
