const std = @import("std");

// SubCommand struct that holds multiple commands and shared flags
pub fn SubCommand(comptime config: anytype) type {
    const ConfigType = @TypeOf(config);
    const config_info = @typeInfo(ConfigType);

    if (config_info != .@"struct") {
        @compileError("SubCommand config must be a struct");
    }

    if (!@hasField(ConfigType, "name")) {
        @compileError("SubCommand config must have a 'name' field");
    }

    if (!@hasField(ConfigType, "commands")) {
        @compileError("SubCommand config must have a 'commands' field");
    }

    if (!@hasField(ConfigType, "description")) {
        @compileError("SubCommand config must have a 'description' field");
    }

    const subcommand_name = config.name;
    const subcommand_description = config.description;
    const subcommand_help = if (@hasField(ConfigType, "help")) config.help else "";
    const commands = config.commands;
    const shared_flags = if (@hasField(ConfigType, "flags")) config.flags else [_]type{};

    // Validate that commands is an array of command types
    const commands_info = @typeInfo(@TypeOf(commands));
    if (commands_info != .@"struct" or commands_info.@"struct".is_tuple == false) {
        @compileError("Commands must be a tuple of command types");
    }

    return struct {
        const Self = @This();

        pub const name = subcommand_name;
        pub const description = subcommand_description;
        pub const help = subcommand_help;
        pub const Commands = commands;
        pub const SharedFlags = shared_flags;

        // Validate commands against shared flags (will be called by App for full validation)
        pub fn validateWithGlobalFlags(comptime global_flags: anytype) void {
            inline for (commands) |CommandType| {
                const param_type = CommandType.getActionParamType();
                @import("./command.zig").validateArgsStruct(
                    param_type,
                    CommandType.Arguments,
                    CommandType.Flags,
                    shared_flags,
                    global_flags,
                );
            }
        }

        // Render help text for this subcommand
        pub fn renderHelp(writer: anytype, comptime global_flags: anytype) !void {
            return renderHelpInternal(writer, global_flags);
        }

        // Execute with hierarchical flag support
        pub fn executeWithGlobalFlags(args: [][:0]u8, comptime global_flags: anytype) !u8 {
            return executeInternal(args, global_flags);
        }

        // Execute the subcommand with the given arguments
        pub fn execute(args: [][:0]u8) !u8 {
            return executeInternal(args, [_]type{});
        }

        // Internal execute function
        fn executeInternal(args: [][:0]u8, comptime global_flags: anytype) !u8 {
            if (args.len == 0) {
                printHelp();
                return 1;
            }

            var i: usize = 0;

            // Parse shared flags (simplified - just skip them for now)
            while (i < args.len) {
                const arg = args[i];

                if (std.mem.startsWith(u8, arg, "--")) {
                    // Long flag (--flag-name or --flag-name=value)
                    const flag_part = arg[2..];
                    var flag_name: []const u8 = undefined;
                    var flag_value: ?[]const u8 = null;

                    // Check for concatenated value with =
                    if (std.mem.indexOf(u8, flag_part, "=")) |eq_pos| {
                        flag_name = flag_part[0..eq_pos];
                        flag_value = flag_part[eq_pos + 1..];
                    } else {
                        flag_name = flag_part;
                    }

                    var flag_found = false;
                    inline for (shared_flags) |FlagType| {
                        if (std.mem.eql(u8, flag_name, FlagType.flag_name)) {
                            flag_found = true;

                            if (@typeInfo(FlagType.ValueType) == .bool) {
                                // Boolean flag, just consume it
                            } else {
                                // Non-boolean flag, consume the value too if not concatenated
                                if (flag_value == null) {
                                    if (i + 1 >= args.len) {
                                        std.debug.print("Error: Shared flag --{s} requires a value\n", .{flag_name});
                                        return 1;
                                    }
                                    i += 1;
                                }
                            }
                            break;
                        }
                    }
                    
                    if (flag_found) {
                        i += 1;
                        continue;
                    } else {
                        // Not a shared flag, might be a command flag
                        break;
                    }
                } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
                    // Short flag (-f or -f=value)
                    const flag_part = arg[1..];
                    var flag_alias: []const u8 = undefined;
                    var flag_value: ?[]const u8 = null;

                    // Check for concatenated value with =
                    if (std.mem.indexOf(u8, flag_part, "=")) |eq_pos| {
                        flag_alias = flag_part[0..eq_pos];
                        flag_value = flag_part[eq_pos + 1..];
                    } else {
                        flag_alias = flag_part;
                    }

                    // Only support single character aliases
                    if (flag_alias.len != 1) {
                        std.debug.print("Error: Short flags must be single characters: {s}\n", .{arg});
                        return 1;
                    }

                    // Find matching flag by alias in shared flags
                    var flag_found = false;
                    inline for (shared_flags) |FlagType| {
                        if (FlagType.flag_alias.len > 0 and std.mem.eql(u8, flag_alias, FlagType.flag_alias)) {
                            flag_found = true;
                            // Note: SubCommand doesn't parse flag values, just skips them
                            // The actual parsing happens in the Command
                            break;
                        }
                    }

                    if (!flag_found) {
                        std.debug.print("Error: Unknown flag -{s}\n", .{flag_alias});
                        return 1;
                    }

                    // Skip flag value if it's not concatenated
                    if (flag_value == null) {
                        // Check if next arg is a value (doesn't start with -)
                        if (i + 1 < args.len and !std.mem.startsWith(u8, args[i + 1], "-")) {
                            i += 1; // Skip the value
                        }
                    }
                } else {
                    // This is the sub-command name
                    break;
                }
                
                i += 1;
            }

            // Check if we have a sub-command
            if (i >= args.len) {
                std.debug.print("Error: No sub-command specified for '{s}'\n", .{subcommand_name});
                printHelp();
                return 1;
            }

            const command_name = args[i];
            const command_args = args[i + 1..];

            // Find and execute the matching command
            inline for (commands) |CommandType| {
                if (std.mem.eql(u8, command_name, CommandType.name)) {
                    return CommandType.executeWithHierarchy(command_args, shared_flags, global_flags);
                }
            }

            std.debug.print("Error: Unknown sub-command '{s}' for '{s}'\n", .{ command_name, subcommand_name });
            printHelp();
            return 1;
        }

        // Print help information for this subcommand
        pub fn printHelp() void {
            // Use a buffer to render help and then print it
            var buffer: [4096]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&buffer);
            const writer = fbs.writer();

            // Render help using the new system (with empty global flags since we don't have context here)
            renderHelpInternal(writer, [_]type{}) catch {
                // Fallback to simple help if rendering fails
                std.debug.print("Usage: {s} [shared-flags] <sub-command> [command-args]\n", .{subcommand_name});
                return;
            };

            const help_text = fbs.getWritten();
            std.debug.print("{s}", .{help_text});
        }

        // Internal help rendering function
        fn renderHelpInternal(writer: anytype, comptime global_flags: anytype) !void {
            // SubCommand name and description
            try writer.print("{s} - {s}\n", .{ subcommand_name, subcommand_description });

            // Usage line
            try writer.print("\nUSAGE:\n    {s}", .{subcommand_name});

            const has_global_flags = global_flags.len > 0;
            const has_shared_flags = shared_flags.len > 0;

            if (has_global_flags) {
                try writer.print(" [GLOBAL_FLAGS]", .{});
            }
            if (has_shared_flags) {
                try writer.print(" [SHARED_FLAGS]", .{});
            }

            try writer.print(" <COMMAND> [COMMAND_ARGS]\n", .{});

            // Global flags section
            if (has_global_flags) {
                try writer.print("\nGLOBAL FLAGS:\n", .{});
                inline for (global_flags) |FlagType| {
                    if (FlagType.flag_alias.len > 0) {
                        try writer.print("    -{s}, --{s:<14} {s}\n", .{ FlagType.flag_alias, FlagType.flag_name, FlagType.description });
                    } else {
                        try writer.print("        --{s:<14} {s}\n", .{ FlagType.flag_name, FlagType.description });
                    }
                }
            }

            // Shared flags section
            if (has_shared_flags) {
                try writer.print("\nSHARED FLAGS:\n", .{});
                inline for (shared_flags) |FlagType| {
                    if (FlagType.flag_alias.len > 0) {
                        try writer.print("    -{s}, --{s:<14} {s}\n", .{ FlagType.flag_alias, FlagType.flag_name, FlagType.description });
                    } else {
                        try writer.print("        --{s:<14} {s}\n", .{ FlagType.flag_name, FlagType.description });
                    }
                }
            }

            // Commands section
            try writer.print("\nCOMMANDS:\n", .{});
            inline for (commands) |CommandType| {
                try writer.print("    {s:<16} {s}\n", .{ CommandType.name, CommandType.description });
            }

            // Add custom help text at the end if available
            if (subcommand_help.len > 0) {
                try writer.print("\n{s}\n", .{subcommand_help});
            }
        }
    };
}

test "subcommand with nested commands" {
    const Command = @import("./command.zig").Command;
    const Arg = @import("./arg.zig").Arg;
    const Flag = @import("./flag.zig").Flag;

    // Define command argument structs
    const AddArgs = struct {
        name: []const u8,
        url: []const u8,
        force: bool,
        dry_run: bool,  // Shared flag
    };

    const RemoveArgs = struct {
        name: []const u8,
        verbose: bool,
        dry_run: bool,  // Shared flag
    };

    const ListArgs = struct {
        verbose: bool,
        dry_run: bool,  // Shared flag
    };

    // Define command actions
    const addAction = struct {
        fn execute(args: AddArgs) !u8 {
            if (args.force) {
                std.debug.print("Force adding remote '{s}' -> {s}\n", .{ args.name, args.url });
            } else {
                std.debug.print("Adding remote '{s}' -> {s}\n", .{ args.name, args.url });
            }
            return 0;
        }
    }.execute;

    const removeAction = struct {
        fn execute(args: RemoveArgs) !u8 {
            if (args.verbose) {
                std.debug.print("Removing remote '{s}' (verbose mode)\n", .{args.name});
            } else {
                std.debug.print("Removing remote '{s}'\n", .{args.name});
            }
            return 0;
        }
    }.execute;

    const listAction = struct {
        fn execute(args: ListArgs) !u8 {
            if (args.verbose) {
                std.debug.print("Listing remotes (verbose):\n", .{});
                std.debug.print("  origin -> https://github.com/user/repo.git\n", .{});
            } else {
                std.debug.print("origin\n", .{});
            }
            return 0;
        }
    }.execute;

    // Define sub-commands
    const add_command = Command(.{
        .name = "add",
        .description = "Add a new remote",
        .action = addAction,
        .flags = [_]type{
            Flag(bool, "force", false, "Force add remote", "f"),
        },
        .arguments = [_]type{
            Arg([]const u8, "name", "Name of the remote"),
            Arg([]const u8, "url", "URL of the remote"),
        },
    });

    const remove_command = Command(.{
        .name = "remove",
        .description = "Remove a remote",
        .action = removeAction,
        .flags = [_]type{
            Flag(bool, "verbose", false, "Enable verbose output", "v"),
        },
        .arguments = [_]type{
            Arg([]const u8, "name", "Name of the remote to remove"),
        },
    });

    const list_command = Command(.{
        .name = "list",
        .description = "List all remotes",
        .action = listAction,
        .flags = [_]type{
            Flag(bool, "verbose", false, "Show detailed information", "v"),
        },
        .arguments = [_]type{},
    });

    // Create the subcommand (like "git remote")
    const remote_subcommand = SubCommand(.{
        .name = "remote",
        .description = "Manage remote repositories",
        .commands = .{ add_command, remove_command, list_command },
        .flags = [_]type{
            Flag(bool, "dry-run", false, "Show what would be done without executing", "n"),
        },
    });

    // Test add sub-command
    var add_args = [_][:0]u8{
        @constCast("add"),
        @constCast("--force"),
        @constCast("upstream"),
        @constCast("https://github.com/upstream/repo.git")
    };
    _ = try remote_subcommand.execute(add_args[0..]);

    // Test remove sub-command
    var remove_args = [_][:0]u8{
        @constCast("remove"),
        @constCast("--verbose"),
        @constCast("origin")
    };
    _ = try remote_subcommand.execute(remove_args[0..]);

    // Test list sub-command
    var list_args = [_][:0]u8{
        @constCast("list"),
        @constCast("--verbose")
    };
    _ = try remote_subcommand.execute(list_args[0..]);

    // Test with shared flag
    var shared_flag_args = [_][:0]u8{
        @constCast("--dry-run"),
        @constCast("add"),
        @constCast("test"),
        @constCast("https://example.com")
    };
    _ = try remote_subcommand.execute(shared_flag_args[0..]);
}

test "subcommand description accessibility" {
    const Command = @import("./command.zig").Command;
    const Flag = @import("./flag.zig").Flag;
    const Arg = @import("./arg.zig").Arg;

    const TestArgs = struct {
        name: []const u8,
        dry_run: bool,
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

    const test_subcommand = SubCommand(.{
        .name = "test-sub",
        .description = "This is a test subcommand",
        .help =
            \\This is a longer help text for the test subcommand.
            \\It explains in detail what this group of commands does
            \\and how to use them effectively.
        ,
        .commands = .{test_command},
        .flags = [_]type{
            Flag(bool, "dry-run", false, "Test dry run flag", "n"),
        },
    });

    // Verify description and help are accessible
    try std.testing.expect(std.mem.eql(u8, test_subcommand.description, "This is a test subcommand"));
    try std.testing.expect(std.mem.eql(u8, test_subcommand.name, "test-sub"));
    try std.testing.expect(test_subcommand.help.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, test_subcommand.help, "longer help text") != null);
}
