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

// Flag definition using native Zig types
pub fn Flag(comptime T: type, comptime name: []const u8, comptime default_value: T, comptime desc: []const u8) type {
    // Compile-time validation
    if (!isSupportedType(T)) {
        @compileError("Unsupported flag type: " ++ @typeName(T) ++
            ". Supported types: integers, floats, bool, []const u8, []u8");
    }

    return struct {
        pub const flag_name = name;
        pub const description = desc;
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

test "native types - booleans" {
    // Test boolean type
    const BoolFlag = Flag(bool, "verbose", false, "Enable verbose output");

    // Test flag parsing
    try std.testing.expect(BoolFlag.parse(null) == true); // No value = true for flags
    try std.testing.expect(BoolFlag.parse("false") == false);

    // Test description
    try std.testing.expect(std.mem.eql(u8, BoolFlag.description, "Enable verbose output"));
}

test "struct field naming" {
    const TimeAwareFlag = Flag(bool, "time-aware", false, "Enable time-aware processing");

    try std.testing.expect(std.mem.eql(u8, "time_aware", &TimeAwareFlag.field_name));
    try std.testing.expect(std.mem.eql(u8, TimeAwareFlag.description, "Enable time-aware processing"));
}

test "description accessibility" {
    const TestFlag = Flag(i32, "test-flag", 42, "This is a test flag");

    // Verify description is accessible
    try std.testing.expect(std.mem.eql(u8, TestFlag.description, "This is a test flag"));
    try std.testing.expect(std.mem.eql(u8, TestFlag.flag_name, "test-flag"));
    try std.testing.expect(TestFlag.default == 42);
}
