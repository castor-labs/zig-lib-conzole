// Internal module for argument parsing utilities
// This module is not part of the public API
const std = @import("std");

/// Result of parsing a flag argument
pub const FlagParseResult = struct {
    flag_name: []const u8,
    flag_alias: []const u8,
    flag_value: ?[]const u8,
    is_short: bool,
};

/// Parse a flag argument (--flag-name=value or -f=value)
pub fn flagArg(arg: []const u8) ?FlagParseResult {
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
        
        return FlagParseResult{
            .flag_name = flag_name,
            .flag_alias = "",
            .flag_value = flag_value,
            .is_short = false,
        };
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
        
        return FlagParseResult{
            .flag_name = "",
            .flag_alias = flag_alias,
            .flag_value = flag_value,
            .is_short = true,
        };
    }
    
    return null;
}

/// Parse and consume a flag value, updating the args index
pub fn consumeFlagValue(
    comptime FlagType: type,
    args: [][:0]u8,
    i: *usize,
    flag_value: ?[]const u8,
    flag_display: []const u8,
) !?[]const u8 {
    if (@typeInfo(FlagType.ValueType) == .bool) {
        // Boolean flags: use provided value or default to true
        return flag_value;
    } else {
        // Non-boolean flags need a value
        if (flag_value == null) {
            // No concatenated value, check next argument
            if (i.* + 1 >= args.len) {
                std.debug.print("Error: Flag {s} requires a value\n", .{flag_display});
                return error.MissingFlagValue;
            }
            i.* += 1;
            return args[i.*];
        } else {
            // Use concatenated value
            return flag_value;
        }
    }
}

/// Skip a flag and its value for routing purposes (used in App and SubCommand)
pub fn skipFlag(
    comptime FlagType: type,
    args: [][:0]u8,
    i: *usize,
    flag_value: ?[]const u8,
    flag_display: []const u8,
) !void {
    if (@typeInfo(FlagType.ValueType) == .bool) {
        // Boolean flag, just consume it
        return;
    } else {
        // Non-boolean flag, consume the value too if not concatenated
        if (flag_value == null) {
            if (i.* + 1 >= args.len) {
                std.debug.print("Error: Flag {s} requires a value\n", .{flag_display});
                return error.MissingFlagValue;
            }
            i.* += 1;
        }
    }
}

/// Check if an argument is a flag (starts with - or --)
pub fn isFlag(arg: []const u8) bool {
    return std.mem.startsWith(u8, arg, "-") and arg.len > 1;
}

/// Validate that a short flag is a single character
pub fn validateShortFlag(flag_alias: []const u8, arg: []const u8) !void {
    if (flag_alias.len != 1) {
        std.debug.print("Error: Short flags must be single characters: {s}\n", .{arg});
        return error.InvalidShortFlag;
    }
}
