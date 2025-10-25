const std = @import("std");

// Function to validate if a type is supported for command line flags
fn isSupportedType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int => true,
        .float => true,
        .bool => true,
        .pointer => |ptr_info| switch (ptr_info.size) {
            .slice => ptr_info.child == u8 and T == []const u8, // Only []const u8 for simplicity
            else => false,
        },
        else => false,
    };
}

// Flag definition using native Zig types with optional alias support
pub fn Flag(comptime T: type, comptime name: []const u8, comptime default_value: T, comptime desc: []const u8, comptime alias: []const u8) type {
    // Compile-time validation
    if (!isSupportedType(T)) {
        @compileError("Unsupported flag type: " ++ @typeName(T) ++
            ". Supported types: integers, floats, bool, []const u8, []u8");
    }

    // Validate alias if provided
    if (alias.len > 1) {
        @compileError("Flag alias must be a single character or empty string");
    }

    return struct {
        pub const flag_name = name;
        pub const description = desc;
        pub const flag_alias = alias;
        pub const ValueType = T;
        pub const default = default_value;

        pub fn parse(input: ?[]const u8) T {
            if (input) |inp| {
                return switch (@typeInfo(T)) {
                    .int => std.fmt.parseInt(T, inp, 10) catch default_value,
                    .float => std.fmt.parseFloat(T, inp) catch default_value,
                    .bool => std.mem.eql(u8, inp, "true") or std.mem.eql(u8, inp, "1"),
                    .pointer => |ptr_info| switch (ptr_info.size) {
                        .slice => if (ptr_info.child == u8 and T == []const u8) inp else default_value,
                        else => default_value,
                    },
                    else => default_value,
                };
            }
            // For boolean flags, if no value is provided, it means the flag is present (true)
            return switch (@typeInfo(T)) {
                .bool => true,
                else => default_value,
            };
        }

        pub const field_name = blk: {
            var buff: [flag_name.len]u8 = undefined;
            _ = std.mem.replace(u8, flag_name, "-", "_", &buff);
            break :blk buff;
        };
    };
}

// Convenience function for backward compatibility (no alias)
pub fn FlagNoAlias(comptime T: type, comptime name: []const u8, comptime default_value: T, comptime desc: []const u8) type {
    return Flag(T, name, default_value, desc, "");
}

test "native types - booleans" {
    // Test boolean type
    const BoolFlag = Flag(bool, "verbose", false, "Enable verbose output", "v");

    // Test flag parsing
    try std.testing.expect(BoolFlag.parse(null) == true); // No value = true for flags
    try std.testing.expect(BoolFlag.parse("false") == false);

    // Test description and alias
    try std.testing.expect(std.mem.eql(u8, BoolFlag.description, "Enable verbose output"));
    try std.testing.expect(std.mem.eql(u8, BoolFlag.flag_alias, "v"));
}

test "struct field naming" {
    const TimeAwareFlag = Flag(bool, "time-aware", false, "Enable time-aware processing", "t");

    try std.testing.expect(std.mem.eql(u8, "time_aware", &TimeAwareFlag.field_name));
    try std.testing.expect(std.mem.eql(u8, TimeAwareFlag.description, "Enable time-aware processing"));
    try std.testing.expect(std.mem.eql(u8, TimeAwareFlag.flag_alias, "t"));
}

test "description accessibility" {
    const TestFlag = Flag(i32, "test-flag", 42, "This is a test flag", "");

    // Verify description is accessible
    try std.testing.expect(std.mem.eql(u8, TestFlag.description, "This is a test flag"));
    try std.testing.expect(std.mem.eql(u8, TestFlag.flag_name, "test-flag"));
    try std.testing.expect(TestFlag.default == 42);
    try std.testing.expect(std.mem.eql(u8, TestFlag.flag_alias, "")); // No alias
}

test "flag aliases" {
    const VerboseFlag = Flag(bool, "verbose", false, "Enable verbose output", "v");
    const QuietFlag = Flag(bool, "quiet", false, "Suppress output", "q");
    const NoAliasFlag = Flag(bool, "debug", false, "Enable debug mode", "");

    // Test aliases
    try std.testing.expect(std.mem.eql(u8, VerboseFlag.flag_alias, "v"));
    try std.testing.expect(std.mem.eql(u8, QuietFlag.flag_alias, "q"));
    try std.testing.expect(std.mem.eql(u8, NoAliasFlag.flag_alias, ""));
}

test "concatenated flag values" {
    const CountFlag = Flag(i32, "count", 1, "Number of items", "c");
    const VerboseFlag = Flag(bool, "verbose", false, "Enable verbose output", "v");

    // Test parsing concatenated values
    try std.testing.expect(CountFlag.parse("42") == 42);
    try std.testing.expect(CountFlag.parse("0") == 0);
    try std.testing.expect(CountFlag.parse("invalid") == 1); // Falls back to default

    // Test boolean flag parsing with explicit values
    try std.testing.expect(VerboseFlag.parse("true") == true);
    try std.testing.expect(VerboseFlag.parse("false") == false);
    try std.testing.expect(VerboseFlag.parse("1") == true);
    try std.testing.expect(VerboseFlag.parse("0") == false);
    try std.testing.expect(VerboseFlag.parse(null) == true); // No value = true for flags
}
