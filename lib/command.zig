const std = @import("std");

// Function to validate that a manually defined struct matches the command definition
// Now supports hierarchical flag validation
pub fn validateArgsStruct(
    comptime ArgsStruct: type,
    comptime arguments: anytype,
    comptime command_flags: anytype,
    comptime shared_flags: anytype,
    comptime global_flags: anytype,
) void {
    @setEvalBranchQuota(10000);
    const struct_info = @typeInfo(ArgsStruct);
    if (struct_info != .@"struct") {
        @compileError("Action's first argument must be a struct type");
    }

    const fields = struct_info.@"struct".fields;

    // First, check for flag name conflicts across hierarchy levels
    checkFlagNameConflicts(command_flags, shared_flags, global_flags);

    // Check that all arguments are present with correct types
    inline for (arguments) |ArgumentType| {
        const field_name = &ArgumentType.field_name;
        const expected_type = ArgumentType.ValueType;

        var found = false;
        inline for (fields) |field| {
            if (std.mem.eql(u8, field.name, field_name)) {
                found = true;
                if (field.type != expected_type) {
                    @compileError("Field '" ++ field_name ++ "' has type " ++ @typeName(field.type) ++
                        " but expected " ++ @typeName(expected_type));
                }
                break;
            }
        }

        if (!found) {
            @compileError("Missing required field '" ++ field_name ++ "' of type " ++ @typeName(expected_type));
        }
    }

    // Check that all flags from all levels are present with correct types
    validateFlagLevel(fields, command_flags, "command");
    validateFlagLevel(fields, shared_flags, "shared");
    validateFlagLevel(fields, global_flags, "global");

    // Check that there are no extra fields
    inline for (fields) |field| {
        var found = false;

        // Check if it's an argument
        inline for (arguments) |ArgumentType| {
            if (std.mem.eql(u8, field.name, &ArgumentType.field_name)) {
                found = true;
                break;
            }
        }

        // Check if it's a command flag
        if (!found) {
            inline for (command_flags) |FlagType| {
                if (std.mem.eql(u8, field.name, &FlagType.field_name)) {
                    found = true;
                    break;
                }
            }
        }

        // Check if it's a shared flag
        if (!found) {
            inline for (shared_flags) |FlagType| {
                if (std.mem.eql(u8, field.name, &FlagType.field_name)) {
                    found = true;
                    break;
                }
            }
        }

        // Check if it's a global flag
        if (!found) {
            inline for (global_flags) |FlagType| {
                if (std.mem.eql(u8, field.name, &FlagType.field_name)) {
                    found = true;
                    break;
                }
            }
        }

        if (!found) {
            @compileError("Unexpected field '" ++ field.name ++ "' in ArgsStruct. " ++
                "All fields must correspond to defined arguments or flags.");
        }
    }
}

// Helper function to validate flags at a specific level
fn validateFlagLevel(comptime fields: anytype, comptime flags: anytype, comptime level_name: []const u8) void {
    @setEvalBranchQuota(5000);
    inline for (flags) |FlagType| {
        const field_name = &FlagType.field_name;
        const expected_type = FlagType.ValueType;

        var found = false;
        inline for (fields) |field| {
            if (std.mem.eql(u8, field.name, field_name)) {
                found = true;
                if (field.type != expected_type) {
                    @compileError("Field '" ++ field_name ++ "' has type " ++ @typeName(field.type) ++
                        " but expected " ++ @typeName(expected_type) ++ " (from " ++ level_name ++ " flags)");
                }
                break;
            }
        }

        if (!found) {
            @compileError("Missing required field '" ++ field_name ++ "' of type " ++ @typeName(expected_type) ++
                " (from " ++ level_name ++ " flags)");
        }
    }
}

// Function to check for flag name conflicts across hierarchy levels
fn checkFlagNameConflicts(comptime command_flags: anytype, comptime shared_flags: anytype, comptime global_flags: anytype) void {
    // Check command vs shared conflicts
    inline for (command_flags) |CommandFlag| {
        inline for (shared_flags) |SharedFlag| {
            if (std.mem.eql(u8, CommandFlag.flag_name, SharedFlag.flag_name)) {
                @compileError("Flag name conflict: '--" ++ CommandFlag.flag_name ++
                    "' is defined in both command flags and shared flags");
            }
        }
    }

    // Check command vs global conflicts
    inline for (command_flags) |CommandFlag| {
        inline for (global_flags) |GlobalFlag| {
            if (std.mem.eql(u8, CommandFlag.flag_name, GlobalFlag.flag_name)) {
                @compileError("Flag name conflict: '--" ++ CommandFlag.flag_name ++
                    "' is defined in both command flags and global flags");
            }
        }
    }

    // Check shared vs global conflicts
    inline for (shared_flags) |SharedFlag| {
        inline for (global_flags) |GlobalFlag| {
            if (std.mem.eql(u8, SharedFlag.flag_name, GlobalFlag.flag_name)) {
                @compileError("Flag name conflict: '--" ++ SharedFlag.flag_name ++
                    "' is defined in both shared flags and global flags");
            }
        }
    }
}

// Command definition with manual struct validation
pub fn Command(comptime config: anytype) type {
    const ConfigType = @TypeOf(config);
    const config_info = @typeInfo(ConfigType);

    if (config_info != .@"struct") {
        @compileError("Command config must be a struct");
    }

    if (!@hasField(ConfigType, "name")) {
        @compileError("Command config must have a 'name' field");
    }

    if (!@hasField(ConfigType, "action")) {
        @compileError("Command config must have an 'action' field");
    }

    if (!@hasField(ConfigType, "description")) {
        @compileError("Command config must have a 'description' field");
    }

    const command_name = config.name;
    const action_fn = config.action;
    const command_description = config.description;
    const command_help = if (@hasField(ConfigType, "help")) config.help else "";
    const arguments = if (@hasField(ConfigType, "arguments")) config.arguments else [_]type{};
    const flags = if (@hasField(ConfigType, "flags")) config.flags else [_]type{};

    // Validate action function signature
    const ActionFnType = @TypeOf(action_fn);
    const action_info = @typeInfo(ActionFnType);

    if (action_info != .@"fn") {
        @compileError("Action must be a function");
    }

    const fn_info = action_info.@"fn";
    if (fn_info.params.len != 1) {
        @compileError("Action function must take exactly one parameter");
    }

    const param_type = fn_info.params[0].type.?;
    // Skip validation here - it will happen later in App/SubCommand where we have full hierarchy context

    return struct {
        const Self = @This();

        pub const name = command_name;
        pub const description = command_description;
        pub const help = command_help;
        pub const Arguments = arguments;
        pub const Flags = flags;

        // Helper function to get the action parameter type
        pub fn getActionParamType() type {
            const ActionType = @TypeOf(action_fn);
            const type_info = @typeInfo(ActionType);
            const function_info = type_info.@"fn";
            return function_info.params[0].type.?;
        }

        // Render help text for this command
        pub fn renderHelp(
            writer: anytype,
            comptime shared_flags_param: anytype,
            comptime global_flags_param: anytype,
        ) !void {
            return renderHelpInternal(writer, shared_flags_param, global_flags_param);
        }

        // Print help information for this command
        pub fn printHelp(comptime shared_flags_param: anytype, comptime global_flags_param: anytype) void {
            // Use a buffer to render help and then print it
            var buffer: [4096]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&buffer);
            const writer = fbs.writer();

            // Render help using the new system
            renderHelpInternal(writer, shared_flags_param, global_flags_param) catch {
                // Fallback to simple help if rendering fails
                std.debug.print("Usage: {s} [flags] <args>\n", .{command_name});
                return;
            };

            const help_text = fbs.getWritten();
            std.debug.print("{s}", .{help_text});
        }

        // Execute with hierarchical flag support
        pub fn executeWithHierarchy(
            args: [][]const u8,
            comptime shared_flags_param: anytype,
            comptime global_flags_param: anytype,
        ) !u8 {
            return executeInternal(args, shared_flags_param, global_flags_param);
        }

        // Receives a list of flags starting with either (--) or (-) into the
        // corresponding struct
        pub fn execute(args: [][]const u8) !u8 {
            return executeInternal(args, [_]type{}, [_]type{});
        }

        // Internal execute function that handles hierarchical flags
        fn executeInternal(
            args: [][]const u8,
            comptime shared_flags_param: anytype,
            comptime global_flags_param: anytype,
        ) !u8 {
            // Create the argument struct that will be passed to the action function
            var parsed_args: param_type = undefined;

            // Initialize flags with their default values from all hierarchy levels
            inline for (global_flags_param) |FlagType| {
                @field(parsed_args, &FlagType.field_name) = FlagType.default;
            }
            inline for (shared_flags_param) |FlagType| {
                @field(parsed_args, &FlagType.field_name) = FlagType.default;
            }
            inline for (flags) |FlagType| {
                @field(parsed_args, &FlagType.field_name) = FlagType.default;
            }
            
            // Track which arguments have been parsed
            var arg_index: usize = 0;
            var i: usize = 0;
            
            while (i < args.len) {
                const arg = args[i];
                
                if (std.mem.startsWith(u8, arg, "--")) {
                    // Long flag (--flag-name)
                    const flag_name = arg[2..];

                    // Find matching flag across all hierarchy levels
                    var flag_found = false;

                    // Check command flags first
                    inline for (flags) |FlagType| {
                        if (std.mem.eql(u8, flag_name, FlagType.flag_name)) {
                            flag_found = true;

                            // Check if this flag expects a value
                            if (@typeInfo(FlagType.ValueType) == .bool) {
                                // Boolean flags don't need a value
                                @field(parsed_args, &FlagType.field_name) = FlagType.parse(null);
                            } else {
                                // Non-boolean flags need a value
                                if (i + 1 >= args.len) {
                                    std.debug.print("Error: Flag --{s} requires a value\n\n", .{flag_name});
                                    printHelp(shared_flags_param, global_flags_param);
                                    return 1;
                                }
                                i += 1;
                                const flag_value = args[i];
                                @field(parsed_args, &FlagType.field_name) = FlagType.parse(flag_value);
                            }
                            break;
                        }
                    }

                    // Check shared flags if not found in command flags
                    if (!flag_found) {
                        inline for (shared_flags_param) |FlagType| {
                            if (std.mem.eql(u8, flag_name, FlagType.flag_name)) {
                                flag_found = true;

                                if (@typeInfo(FlagType.ValueType) == .bool) {
                                    @field(parsed_args, &FlagType.field_name) = FlagType.parse(null);
                                } else {
                                    if (i + 1 >= args.len) {
                                        std.debug.print("Error: Shared flag --{s} requires a value\n\n", .{flag_name});
                                        printHelp(shared_flags_param, global_flags_param);
                                        return 1;
                                    }
                                    i += 1;
                                    const flag_value = args[i];
                                    @field(parsed_args, &FlagType.field_name) = FlagType.parse(flag_value);
                                }
                                break;
                            }
                        }
                    }

                    // Check global flags if not found in shared flags
                    if (!flag_found) {
                        inline for (global_flags_param) |FlagType| {
                            if (std.mem.eql(u8, flag_name, FlagType.flag_name)) {
                                flag_found = true;

                                if (@typeInfo(FlagType.ValueType) == .bool) {
                                    @field(parsed_args, &FlagType.field_name) = FlagType.parse(null);
                                } else {
                                    if (i + 1 >= args.len) {
                                        std.debug.print("Error: Global flag --{s} requires a value\n\n", .{flag_name});
                                        printHelp(shared_flags_param, global_flags_param);
                                        return 1;
                                    }
                                    i += 1;
                                    const flag_value = args[i];
                                    @field(parsed_args, &FlagType.field_name) = FlagType.parse(flag_value);
                                }
                                break;
                            }
                        }
                    }

                    if (!flag_found) {
                        std.debug.print("Error: Unknown flag --{s}\n\n", .{flag_name});
                        printHelp(shared_flags_param, global_flags_param);
                        return 1;
                    }
                } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
                    // Short flag (-f)
                    // For simplicity, we'll treat short flags the same as long flags
                    // In a more complete implementation, you might want to support single-character flags
                    std.debug.print("Error: Short flags not supported yet: {s}\n\n", .{arg});
                    printHelp(shared_flags_param, global_flags_param);
                    return 1;
                } else {
                    // This is a positional argument
                    if (arg_index >= arguments.len) {
                        std.debug.print("Error: Too many arguments provided\n\n", .{});
                        printHelp(shared_flags_param, global_flags_param);
                        return 1;
                    }
                    
                    // Parse the argument
                    inline for (arguments, 0..) |ArgumentType, idx| {
                        if (idx == arg_index) {
                            @field(parsed_args, &ArgumentType.field_name) = ArgumentType.parse(arg) catch |err| {
                                std.debug.print("Error: Failed to parse argument '{s}': {}\n\n", .{ arg, err });
                                printHelp(shared_flags_param, global_flags_param);
                                return 1;
                            };
                            break;
                        }
                    }
                    arg_index += 1;
                }
                
                i += 1;
            }
            
            // Check that all required arguments were provided
            if (arg_index < arguments.len) {
                std.debug.print("Error: Missing required arguments\n\n", .{});
                printHelp(shared_flags_param, global_flags_param);
                return 1;
            }

            return @call(.auto, action_fn, .{parsed_args});
        }

        // Internal help rendering function
        fn renderHelpInternal(
            writer: anytype,
            comptime shared_flags_param: anytype,
            comptime global_flags_param: anytype,
        ) !void {
            // Command name and description
            try writer.print("{s} - {s}\n", .{ command_name, command_description });

            // Usage line
            try writer.print("\nUSAGE:\n    {s}", .{command_name});

            // Add flags to usage
            const has_global_flags = global_flags_param.len > 0;
            const has_shared_flags = shared_flags_param.len > 0;
            const has_command_flags = flags.len > 0;

            if (has_global_flags) {
                try writer.print(" [GLOBAL_FLAGS]", .{});
            }
            if (has_shared_flags) {
                try writer.print(" [SHARED_FLAGS]", .{});
            }
            if (has_command_flags) {
                try writer.print(" [FLAGS]", .{});
            }

            // Add arguments to usage
            inline for (arguments) |ArgumentType| {
                try writer.print(" <{s}>", .{ArgumentType.arg_name});
            }

            try writer.print("\n", .{});

            // Arguments section
            if (arguments.len > 0) {
                try writer.print("\nARGUMENTS:\n", .{});
                inline for (arguments) |ArgumentType| {
                    try writer.print("    {s:<20} {s}\n", .{ ArgumentType.arg_name, ArgumentType.description });
                }
            }

            // Global flags section
            if (has_global_flags) {
                try writer.print("\nGLOBAL FLAGS:\n", .{});
                inline for (global_flags_param) |FlagType| {
                    try writer.print("    --{s:<16} {s}\n", .{ FlagType.flag_name, FlagType.description });
                }
            }

            // Shared flags section
            if (has_shared_flags) {
                try writer.print("\nSHARED FLAGS:\n", .{});
                inline for (shared_flags_param) |FlagType| {
                    try writer.print("    --{s:<16} {s}\n", .{ FlagType.flag_name, FlagType.description });
                }
            }

            // Command flags section
            if (has_command_flags) {
                try writer.print("\nFLAGS:\n", .{});
                inline for (flags) |FlagType| {
                    try writer.print("    --{s:<16} {s}\n", .{ FlagType.flag_name, FlagType.description });
                }
            }

            // Add custom help text at the end if available
            if (command_help.len > 0) {
                try writer.print("\n{s}\n", .{command_help});
            }
        }
    };
}

test "command description accessibility" {
    const TestArgs = struct {
        name: []const u8,
        verbose: bool,
    };

    const testAction = struct {
        fn execute(args: TestArgs) !u8 {
            _ = args;
            return 0;
        }
    }.execute;

    const test_command = Command(.{
        .name = "test-cmd",
        .description = "This is a test command",
        .help =
            \\This is a longer help text for the test command.
            \\It can span multiple lines and provide detailed
            \\information about what the command does.
        ,
        .action = testAction,
        .arguments = [_]type{
            @import("./arg.zig").Arg([]const u8, "name", "Test name argument"),
        },
        .flags = [_]type{
            @import("./flag.zig").Flag(bool, "verbose", false, "Test verbose flag"),
        },
    });

    // Verify description and help are accessible
    try std.testing.expect(std.mem.eql(u8, test_command.description, "This is a test command"));
    try std.testing.expect(std.mem.eql(u8, test_command.name, "test-cmd"));
    try std.testing.expect(test_command.help.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, test_command.help, "longer help text") != null);
}


