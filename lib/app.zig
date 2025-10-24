const std = @import("std");

// App struct that holds multiple commands and global flags
pub fn App(comptime config: anytype) type {
    const ConfigType = @TypeOf(config);
    const config_info = @typeInfo(ConfigType);

    if (config_info != .@"struct") {
        @compileError("App config must be a struct");
    }

    if (!@hasField(ConfigType, "name")) {
        @compileError("App config must have a 'name' field");
    }

    if (!@hasField(ConfigType, "commands")) {
        @compileError("App config must have a 'commands' field");
    }

    if (!@hasField(ConfigType, "description")) {
        @compileError("App config must have a 'description' field");
    }

    const app_name = config.name;
    const app_description = config.description;
    const app_help = if (@hasField(ConfigType, "help")) config.help else "";
    const commands = config.commands;
    const global_flags = if (@hasField(ConfigType, "flags")) config.flags else [_]type{};

    // Validate that commands is an array of command types
    const commands_info = @typeInfo(@TypeOf(commands));
    if (commands_info != .@"struct" or commands_info.@"struct".is_tuple == false) {
        @compileError("Commands must be a tuple of command types");
    }

    return struct {
        const Self = @This();

        pub const name = app_name;
        pub const description = app_description;
        pub const help = app_help;
        pub const Commands = commands;
        pub const GlobalFlags = global_flags;

        // Perform full hierarchical validation at compile time
        comptime {
            validateHierarchy();
        }

        // Validate the entire command hierarchy
        fn validateHierarchy() void {
            inline for (commands) |CommandType| {
                if (@hasDecl(CommandType, "Commands")) {
                    // This is a SubCommand - validate its nested commands
                    CommandType.validateWithGlobalFlags(global_flags);
                } else {
                    // This is a direct Command - validate against global flags only
                    const param_type = CommandType.getActionParamType();
                    @import("./command.zig").validateArgsStruct(
                        param_type,
                        CommandType.Arguments,
                        CommandType.Flags,
                        [_]type{}, // No shared flags for direct commands
                        global_flags,
                    );
                }
            }
        }

        // Render help text for this app
        pub fn renderHelp(writer: anytype) !void {
            return renderHelpInternal(writer);
        }

        // Run the application with the given arguments
        pub fn run(args: [][]const u8) !u8 {
            if (args.len == 0) {
                printHelp();
                return 1;
            }

            var i: usize = 0;

            // Parse global flags (simplified - just skip them for now)
            while (i < args.len) {
                const arg = args[i];

                if (std.mem.startsWith(u8, arg, "--")) {
                    const flag_name = arg[2..];

                    var flag_found = false;
                    inline for (global_flags) |FlagType| {
                        if (std.mem.eql(u8, flag_name, FlagType.flag_name)) {
                            flag_found = true;

                            if (@typeInfo(FlagType.ValueType) == .bool) {
                                // Boolean flag, just consume it
                            } else {
                                // Non-boolean flag, consume the value too
                                if (i + 1 >= args.len) {
                                    std.debug.print("Error: Global flag --{s} requires a value\n", .{flag_name});
                                    return 1;
                                }
                                i += 1;
                            }
                            break;
                        }
                    }

                    if (flag_found) {
                        i += 1;
                        continue;
                    } else {
                        // Not a global flag, might be a command flag
                        break;
                    }
                } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
                    std.debug.print("Error: Short flags not supported yet: {s}\n", .{arg});
                    return 1;
                } else {
                    // This is the command name
                    break;
                }

                i += 1;
            }

            // Check if we have a command
            if (i >= args.len) {
                std.debug.print("Error: No command specified\n", .{});
                printHelp();
                return 1;
            }

            const command_name = args[i];
            const command_args = args[i + 1..];

            // Find and execute the matching command
            inline for (commands) |CommandType| {
                if (std.mem.eql(u8, command_name, CommandType.name)) {
                    if (@hasDecl(CommandType, "Commands")) {
                        // This is a SubCommand
                        return CommandType.executeWithGlobalFlags(command_args, global_flags);
                    } else {
                        // This is a direct Command
                        return CommandType.executeWithHierarchy(command_args, [_]type{}, global_flags);
                    }
                }
            }

            std.debug.print("Error: Unknown command '{s}'\n", .{command_name});
            printHelp();
            return 1;
        }

        // Print help information
        pub fn printHelp() void {
            // Use a buffer to render help and then print it
            var buffer: [4096]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&buffer);
            const writer = fbs.writer();

            // Render help using the new system
            renderHelpInternal(writer) catch {
                // Fallback to simple help if rendering fails
                std.debug.print("Usage: {s} [global-flags] <command> [command-args]\n", .{app_name});
                return;
            };

            const help_text = fbs.getWritten();
            std.debug.print("{s}", .{help_text});
        }

        // Internal help rendering function
        fn renderHelpInternal(writer: anytype) !void {
            // App name and description
            try writer.print("{s} - {s}\n", .{ app_name, app_description });

            // Usage line
            try writer.print("\nUSAGE:\n    {s}", .{app_name});

            const has_global_flags = global_flags.len > 0;

            if (has_global_flags) {
                try writer.print(" [GLOBAL_FLAGS]", .{});
            }

            try writer.print(" <COMMAND> [COMMAND_ARGS]\n", .{});

            // Global flags section
            if (has_global_flags) {
                try writer.print("\nGLOBAL FLAGS:\n", .{});
                inline for (global_flags) |FlagType| {
                    try writer.print("    --{s:<16} {s}\n", .{ FlagType.flag_name, FlagType.description });
                }
            }

            // Commands section
            try writer.print("\nCOMMANDS:\n", .{});
            inline for (commands) |CommandType| {
                try writer.print("    {s:<16} {s}\n", .{ CommandType.name, CommandType.description });
            }

            // Add custom help text at the end if available
            if (app_help.len > 0) {
                try writer.print("\n{s}\n", .{app_help});
            }
        }

    };
}

test "app with multiple commands" {
    const Command = @import("./command.zig").Command;
    const Arg = @import("./arg.zig").Arg;
    const Flag = @import("./flag.zig").Flag;

    // Define command argument structs
    const GreetArgs = struct {
        name: []const u8,
        loud: bool,
        debug: bool,  // Global flag
    };

    const CountArgs = struct {
        number: i32,
        verbose: bool,
        debug: bool,  // Global flag
    };

    // Define command actions
    const greetAction = struct {
        fn execute(args: GreetArgs) !u8 {
            if (args.loud) {
                std.debug.print("HELLO, {s}!\n", .{args.name});
            } else {
                std.debug.print("Hello, {s}!\n", .{args.name});
            }
            return 0;
        }
    }.execute;

    const countAction = struct {
        fn execute(args: CountArgs) !u8 {
            var i: i32 = 1;
            while (i <= args.number) : (i += 1) {
                if (args.verbose) {
                    std.debug.print("Count: {}\n", .{i});
                } else {
                    std.debug.print("{}\n", .{i});
                }
            }
            return 0;
        }
    }.execute;

    // Define commands
    const greet_command = Command(.{
        .name = "greet",
        .description = "Greet a person",
        .action = greetAction,
        .flags = [_]type{
            Flag(bool, "loud", false, "Use loud greeting"),
        },
        .arguments = [_]type{
            Arg([]const u8, "name", "Name of the person to greet"),
        },
    });

    const count_command = Command(.{
        .name = "count",
        .description = "Count to a number",
        .action = countAction,
        .flags = [_]type{
            Flag(bool, "verbose", false, "Enable verbose output"),
        },
        .arguments = [_]type{
            Arg(i32, "number", "Number to count to"),
        },
    });

    // Create the app
    const test_app = App(.{
        .name = "test-app",
        .description = "A test application with multiple commands",
        .commands = .{ greet_command, count_command },
        .flags = [_]type{
            Flag(bool, "debug", false, "Enable debug mode"),
        },
    });

    // Test greet command
    var greet_args = [_][]const u8{ "greet", "--loud", "World" };
    _ = try test_app.run(greet_args[0..]);

    // Test count command
    var count_args = [_][]const u8{ "count", "--verbose", "3" };
    _ = try test_app.run(count_args[0..]);

    // Test with global flag
    var global_flag_args = [_][]const u8{ "--debug", "greet", "Alice" };
    _ = try test_app.run(global_flag_args[0..]);
}

test "app description accessibility" {
    const Command = @import("./command.zig").Command;
    const Flag = @import("./flag.zig").Flag;
    const Arg = @import("./arg.zig").Arg;

    const TestArgs = struct {
        name: []const u8,
        debug: bool,
    };

    const testAction = struct {
        fn execute(args: TestArgs) !u8 {
            _ = args;
            return 0;
        }
    }.execute;

    const test_command = Command(.{
        .name = "test",
        .description = "Test command",
        .action = testAction,
        .arguments = [_]type{
            Arg([]const u8, "name", "Test name"),
        },
        .flags = [_]type{},
    });

    const test_app = App(.{
        .name = "test-app",
        .description = "This is a test application",
        .help =
            \\This is a comprehensive help text for the test application.
            \\It provides detailed information about the application's
            \\purpose, usage patterns, and available functionality.
            \\
            \\Examples:
            \\  test-app command --flag value
            \\  test-app --global-flag command
        ,
        .commands = .{test_command},
        .flags = [_]type{
            Flag(bool, "debug", false, "Test debug flag"),
        },
    });

    // Verify description and help are accessible
    try std.testing.expect(std.mem.eql(u8, test_app.description, "This is a test application"));
    try std.testing.expect(std.mem.eql(u8, test_app.name, "test-app"));
    try std.testing.expect(test_app.help.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, test_app.help, "comprehensive help text") != null);
}
