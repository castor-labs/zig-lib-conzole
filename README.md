# Conzole

A type-safe command-line argument parsing library for Zig that provides compile-time validation and automatic struct generation.

## Features

- **Type Safety**: Compile-time validation ensures your argument structs match your command definitions
- **Automatic Parsing**: Converts command-line arguments to strongly-typed Zig structs
- **Rich Descriptions**: All components (commands, arguments, flags) support descriptions for better UX
- **Comprehensive Help**: Commands, subcommands, and apps support detailed multi-line help text
- **Automatic Help Rendering**: Built-in help rendering with proper formatting and alignment
- **Multi-Command Support**: Build applications with multiple subcommands using the `App` struct
- **Hierarchical Commands**: Create nested command structures with `SubCommand` (e.g., `git remote add`)
- **Global Flags**: Support for application-wide flags that work across all commands
- **Shared Flags**: SubCommands can have shared flags that apply to all their nested commands
- **Flag Support**: Boolean and value flags with default values
- **Error Handling**: Clear error messages for invalid arguments and flags
- **Zero Runtime Overhead**: All validation happens at compile time

## Quick Start

```zig
const std = @import("std");
const conzole = @import("conzole");

const GreetArgs = struct {
    name: []const u8,
    verbose: bool,
    count: i32,
};

fn greetAction(args: GreetArgs) !u8 {
    var i: i32 = 0;
    while (i < args.count) : (i += 1) {
        if (args.verbose) {
            std.debug.print("Greeting #{}: Hello, {s}!\n", .{ i + 1, args.name });
        } else {
            std.debug.print("Hello, {s}!\n", .{args.name});
        }
    }
    return 0;
}

pub fn main() !void {
    // ... allocator setup ...
    
    const greet_command = conzole.Command(.{
        .name = "greet",
        .description = "Greet a person with optional customization",
        .help =
            \\EXAMPLES:
            \\    greet Alice                    # Simple greeting
            \\    greet --verbose --count 3 Bob  # Verbose greeting 3 times
            \\
            \\NOTES:
            \\    - Use --verbose to see greeting numbers
            \\    - Count must be a positive integer
        ,
        .action = greetAction,
        .flags = [_]type{
            conzole.Flag(bool, "verbose", false, "Enable verbose output", "v"),
            conzole.Flag(i32, "count", 1, "Number of times to greet", "c"),
        },
        .arguments = [_]type{
            conzole.Arg([]const u8, "name", "Name of the person to greet"),
        },
    });

    const exit_code = try greet_command.execute(cmd_args);
    std.process.exit(exit_code);
}
```

## Usage Examples

```bash
# Basic usage
./greet Alice
# Output: Hello, Alice!

# With flags
./greet --verbose --count 3 Bob
# Output: 
# Greeting #1: Hello, Bob!
# Greeting #2: Hello, Bob!
# Greeting #3: Hello, Bob!

# Boolean flags don't need values
./greet --verbose Charlie
# Output: Greeting #1: Hello, Charlie!
```

## Multi-Command Applications

For applications with multiple subcommands, use the `App` struct:

```zig
const std = @import("std");
const conzole = @import("conzole");

// Define commands
const greet_command = conzole.Command(.{
    .name = "greet",
    .description = "Greet a person",
    .action = greetAction,
    .flags = [_]type{
        conzole.Flag(bool, "loud", false, "Use loud greeting", "l"),
    },
    .arguments = [_]type{
        conzole.Arg([]const u8, "name", "Name of the person to greet"),
    },
});

const file_command = conzole.Command(.{
    .name = "file",
    .description = "Process files",
    .action = fileAction,
    .flags = [_]type{
        conzole.Flag(bool, "compress", false, "Compress the output file", "c"),
    },
    .arguments = [_]type{
        conzole.Arg([]const u8, "input", "Input file path"),
        conzole.Arg([]const u8, "output", "Output file path"),
    },
});

// Create the application
const app = conzole.App(.{
    .name = "my-tool",
    .description = "A multi-purpose command-line tool",
    .commands = .{ greet_command, file_command },
    .flags = [_]type{
        conzole.Flag(bool, "verbose", false, "Enable verbose output", "v"),
        conzole.Flag(bool, "debug", false, "Enable debug mode", "d"),
    },
});

pub fn main() !void {
    // ... get args ...
    const exit_code = try app.run(cmd_args);
    std.process.exit(exit_code);
}
```

### Multi-Command Usage

```bash
# Show help
./my-tool

# Use global flags
./my-tool --verbose greet Alice

# Use command-specific flags
./my-tool greet --loud Bob

# Different commands
./my-tool file --compress input.txt output.txt
```

## Hierarchical Commands

For complex applications with nested command structures (like `git remote add` or `docker container run`), use `SubCommand`:

```zig
// Define sub-commands for "container" operations
const container_run_command = conzole.Command(.{
    .name = "run",
    .description = "Run a new container",
    .action = containerRunAction,
    .flags = [_]type{
        conzole.Flag(bool, "detach", false, "Run in background"),
        conzole.Flag([]const u8, "name", "", "Container name"),
    },
    .arguments = [_]type{
        conzole.Arg([]const u8, "image", "Container image"),
    },
});

const container_stop_command = conzole.Command(.{
    .name = "stop",
    .description = "Stop a running container",
    .action = containerStopAction,
    .flags = [_]type{
        conzole.Flag(bool, "force", false, "Force stop"),
    },
    .arguments = [_]type{
        conzole.Arg([]const u8, "container", "Container to stop"),
    },
});

// Create the "container" subcommand
const container_subcommand = conzole.SubCommand(.{
    .name = "container",
    .description = "Manage containers",
    .commands = .{ container_run_command, container_stop_command },
    .flags = [_]type{
        conzole.Flag(bool, "debug", false, "Enable debug mode", "d"), // Shared across all container commands
    },
});

// Use in main app
const app = conzole.App(.{
    .name = "docker-like",
    .description = "A Docker-like container management tool",
    .commands = .{ container_subcommand, /* other top-level commands */ },
    .flags = [_]type{
        conzole.Flag(bool, "verbose", false, "Enable verbose output", "v"),
    },
});
```

### Hierarchical Usage

```bash
# Show main help
./docker-like

# Show container subcommand help
./docker-like container

# Use nested commands with various flag combinations
./docker-like container run --detach --name web nginx
./docker-like container stop --force web
./docker-like --verbose container --debug run ubuntu
```

## API Reference

### App

Creates a multi-command application with global flags.

```zig
const app = conzole.App(.{
    .name = "app-name",
    .description = "Description of the application",
    .help = "Optional detailed multi-line help text",  // Optional
    .commands = .{ command1, command2, subcommand1, ... },
    .flags = [_]type{ /* global flag types */ },
});

// Render help text
try app.renderHelp(writer);
```

### SubCommand

Creates a hierarchical command structure with shared flags.

```zig
const subcommand = conzole.SubCommand(.{
    .name = "subcommand-name",
    .description = "Description of the subcommand group",
    .help = "Optional detailed multi-line help text",  // Optional
    .commands = .{ nested_command1, nested_command2, ... },
    .flags = [_]type{ /* shared flag types */ },
});

// Render help text
try subcommand.renderHelp(writer, global_flags);
```

### Command

Creates a command with arguments and flags.

```zig
const command = conzole.Command(.{
    .name = "command-name",
    .description = "Description of what this command does",
    .help = "Optional detailed multi-line help text",  // Optional
    .action = actionFunction,
    .arguments = [_]type{ /* argument types */ },
    .flags = [_]type{ /* flag types */ },
});

// Render help text
try command.renderHelp(writer, shared_flags, global_flags);
```

### Arg

Defines a positional argument with a description.

```zig
conzole.Arg(Type, "argument-name", "Description of the argument")
```

Supported types: `i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`, `f32`, `f64`, `bool`, `[]const u8`

### Description vs Help

**Description**: Short, single-line summary of what a component does
- Used in command listings and brief help
- Should be concise and descriptive
- Required for all commands, subcommands, and apps

**Help**: Additional content appended after standard help sections
- Appears after auto-generated USAGE, FLAGS, COMMANDS, ARGUMENTS sections
- Perfect for examples, notes, workflow descriptions, and additional context
- Optional for all components
- Supports multi-line strings using Zig's `\\` syntax

## Help Rendering

Conzole automatically generates formatted help text from your command definitions. Each component provides a `renderHelp()` method:

### App Help Rendering

```zig
const app = conzole.App(.{ /* ... */ });

// Render help to any writer
const stdout = std.io.getStdOut().writer();
try app.renderHelp(stdout);
```

**Example Output:**
```
container - A Docker-like container management tool

USAGE:
    container [GLOBAL_FLAGS] <COMMAND> [COMMAND_ARGS]

GLOBAL FLAGS:
    --verbose          Enable verbose output
    --quiet            Suppress output

COMMANDS:
    container          Manage containers
    image              Manage container images
    network            Manage container networks

EXAMPLES:
    container container run --detach nginx
    container --verbose image build --tag myapp .
    container network create --driver bridge mynet
    container --quiet container list --all

WORKFLOW:
    1. Pull or build images: container image pull nginx
    2. Create networks: container network create mynet
    3. Run containers: container container run nginx
    4. Manage lifecycle: container container stop/remove

NOTES:
    - Each subcommand supports --dry-run to preview operations
    - Use --verbose for detailed output, --quiet for minimal output
    - Global flags affect all subcommands and their operations
```

### Command Help Rendering

```zig
const command = conzole.Command(.{ /* ... */ });

// Render command help with flag context
try command.renderHelp(writer, shared_flags, global_flags);
```

**Example Output:**
```
run - Run a new container from an image

USAGE:
    run [GLOBAL_FLAGS] [SHARED_FLAGS] [FLAGS] <image>

ARGUMENTS:
    image                Container image to run

GLOBAL FLAGS:
    --verbose          Enable verbose output
    --quiet            Suppress output

SHARED FLAGS:
    --dry-run          Show what would be done without executing

FLAGS:
    --detach           Run container in background
    --interactive      Keep STDIN open and allocate a pseudo-TTY
    --name             Assign a name to the container
    --port             Publish container ports to host

EXAMPLES:
    container run nginx
    container run --detach --name web --port 8080:80 nginx
    container run --interactive ubuntu bash

NOTES:
    - Use --detach for long-running services
    - Use --interactive for shells and interactive programs
    - Port format is HOST_PORT:CONTAINER_PORT
```

### SubCommand Help Rendering

```zig
const subcommand = conzole.SubCommand(.{ /* ... */ });

// Render subcommand help
try subcommand.renderHelp(writer, global_flags);
```

The help system automatically:
- Generates standard sections: USAGE, ARGUMENTS, FLAGS, COMMANDS
- Formats usage lines with proper flag and argument placement
- Aligns descriptions in columns for readability
- Shows hierarchical flag inheritance (global → shared → command)
- Appends custom help text after standard sections
- Lists all available commands/subcommands

### Flag

Defines a flag with a default value, description, and optional alias.

```zig
conzole.Flag(Type, "flag-name", default_value, "Description of the flag", "alias")
```

**Parameters:**
- `Type`: The type of the flag value (bool, i32, []const u8, etc.)
- `"flag-name"`: The long flag name (used with `--flag-name`)
- `default_value`: Default value if flag is not provided
- `"Description"`: Help text for the flag
- `"alias"`: Single character alias (used with `-a`), or `""` for no alias

**Flag Usage:**
```bash
# Long form
./app --verbose --count 5

# Short form (aliases)
./app -v -c 5

# Concatenated values
./app --verbose=true --count=10
./app -v=true -c=10

# Mixed usage
./app -v --count=5 --debug
```

## Container Example

The `examples/container.zig` file provides a comprehensive Docker-like CLI that demonstrates all library features:

**Features Demonstrated:**
- **3-level hierarchy**: App → SubCommand → Command (`container run`, `image build`, `network create`)
- **Global flags**: `--verbose`, `--quiet` (available everywhere)
- **Shared flags**: `--dry-run` (available within each subcommand)
- **Command flags**: Specific to individual commands
- **Multiple argument types**: strings, integers, booleans
- **Rich descriptions**: Every component has descriptive text
- **Comprehensive help**: Custom help text with examples, notes, and workflows
- **Help rendering**: Demonstrates the automatic help generation system
- **Complex flag combinations**: Mix of global, shared, and command-specific flags

**Usage Examples:**
```bash
# Container management
./container container run --detach --name web --port 8080:80 nginx
./container container stop --force --timeout 30 web
./container container list --all
./container container remove --force --volumes web

# Image management
./container image pull --all-tags ubuntu
./container image build --tag myapp:latest --no-cache .
./container image list --all

# Network management
./container network create --driver bridge --subnet 172.20.0.0/16 mynet
./container network list

# Global and shared flags
./container --verbose image --dry-run build --tag test .
./container --quiet container --dry-run run nginx
```

## Building

```bash
# Build the library
zig build

# Run all tests (automatically discovers tests from all modules using refAllDecls)
zig build test

# Build and run the comprehensive container management example
zig build run-container -- --help
zig build run-container -- --verbose container run --detach --name web nginx
zig build run-container -- container --dry-run stop --force web
zig build run-container -- image pull --all-tags ubuntu
zig build run-container -- network create --driver bridge --subnet 172.20.0.0/16 mynet
```

## Project Structure

```
├── build.zig          # Build configuration
├── lib/
│   ├── root.zig       # Main library entry point with unified test discovery
│   ├── app.zig        # Multi-command app implementation
│   ├── subcommand.zig # Hierarchical subcommand implementation
│   ├── command.zig    # Command implementation
│   ├── arg.zig        # Argument implementation
│   └── flag.zig       # Flag implementation
└── examples/
    └── container.zig  # Comprehensive Docker-like CLI demonstrating all features
```

## License

This project is licensed under the MIT License.
