// Internal module for help text rendering utilities
// This module is not part of the public API
const std = @import("std");

/// Render flag help text with proper formatting
pub fn flagHelp(
    writer: anytype,
    comptime flags: anytype,
    section_name: []const u8,
) !void {
    if (flags.len == 0) return;
    
    try writer.print("\n{s}:\n", .{section_name});
    inline for (flags) |FlagType| {
        if (FlagType.flag_alias.len > 0) {
            try writer.print("    -{s}, --{s:<14} {s}\n", .{ 
                FlagType.flag_alias, 
                FlagType.flag_name, 
                FlagType.description 
            });
        } else {
            try writer.print("        --{s:<14} {s}\n", .{ 
                FlagType.flag_name, 
                FlagType.description 
            });
        }
    }
}

/// Render usage line with flags
pub fn usageLine(
    writer: anytype,
    name: []const u8,
    comptime global_flags: anytype,
    comptime shared_flags: anytype,
    comptime command_flags: anytype,
    comptime args: anytype,
) !void {
    try writer.print("\nUSAGE:\n    {s}", .{name});
    
    if (global_flags.len > 0) {
        try writer.print(" [GLOBAL_FLAGS]", .{});
    }
    if (shared_flags.len > 0) {
        try writer.print(" [SHARED_FLAGS]", .{});
    }
    if (command_flags.len > 0) {
        try writer.print(" [FLAGS]", .{});
    }
    
    // Add arguments to usage
    inline for (args) |ArgumentType| {
        try writer.print(" <{s}>", .{ArgumentType.arg_name});
    }
    
    try writer.print("\n", .{});
}

/// Render arguments section
pub fn arguments(
    writer: anytype,
    comptime args: anytype,
) !void {
    if (args.len == 0) return;
    
    try writer.print("\nARGUMENTS:\n", .{});
    inline for (args) |ArgumentType| {
        try writer.print("    {s:<20} {s}\n", .{ 
            ArgumentType.arg_name, 
            ArgumentType.description 
        });
    }
}

/// Render commands section
pub fn commands(
    writer: anytype,
    comptime cmds: anytype,
) !void {
    try writer.print("\nCOMMANDS:\n", .{});
    inline for (cmds) |CommandType| {
        try writer.print("    {s:<16} {s}\n", .{ 
            CommandType.name, 
            CommandType.description 
        });
    }
}

/// Render custom help text if available
pub fn customHelp(
    writer: anytype,
    help_text: []const u8,
) !void {
    if (help_text.len > 0) {
        try writer.print("\n{s}\n", .{help_text});
    }
}
