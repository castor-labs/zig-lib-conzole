const std = @import("std");

// Function to validate if a type is supported for command line arguments
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

// Argument definition using native Zig types
pub fn Arg(comptime T: type, comptime name: []const u8, comptime desc: []const u8) type {
    // Compile-time validation
    if (!isSupportedType(T)) {
        @compileError("Unsupported argument type: " ++ @typeName(T) ++
            ". Supported types: integers, floats, bool, []const u8, []u8");
    }

    return struct {
        pub const arg_name = name;
        pub const description = desc;
        pub const ValueType = T;

        pub fn parse(input: []const u8) !T {
            return switch (@typeInfo(T)) {
                .int => try std.fmt.parseInt(T, input, 10),
                .float => try std.fmt.parseFloat(T, input),
                .bool => std.mem.eql(u8, input, "true") or std.mem.eql(u8, input, "1"),
                .pointer => |ptr_info| switch (ptr_info.size) {
                    .slice => if (ptr_info.child == u8 and T == []const u8) input else @compileError("Invalid slice type"),
                    else => @compileError("Unsupported pointer type"),
                },
                else => @compileError("Unsupported type in parse"),
            };
        }

        pub const field_name = blk: {
            var buff: [arg_name.len]u8 = undefined;
            _ = std.mem.replace(u8, arg_name, "-", "_", &buff);
            break :blk buff;
        };
    };
}

test "native types - integers" {
    // Test different integer types
    const I32Arg = Arg(i32, "count", "Number of items");
    const U64Arg = Arg(u64, "size", "Size in bytes");
    const I8Arg = Arg(i8, "level", "Level value");

    // Test parsing
    try std.testing.expect(try I32Arg.parse("42") == 42);
    try std.testing.expect(try U64Arg.parse("1000") == 1000);
    try std.testing.expect(try I8Arg.parse("-5") == -5);
}

test "native types - floats" {
    // Test different float types
    const F32Arg = Arg(f32, "ratio", "Ratio value");
    const F64Arg = Arg(f64, "precision", "Precision value");

    // Test parsing
    const ratio = try F32Arg.parse("3.14");
    const precision = try F64Arg.parse("2.718281828");

    try std.testing.expect(@abs(ratio - 3.14) < 0.001);
    try std.testing.expect(@abs(precision - 2.718281828) < 0.000001);
}

test "native types - strings" {
    // Test string types
    const StringArg = Arg([]const u8, "message", "Message text");

    // Test parsing
    const message = try StringArg.parse("hello world");

    try std.testing.expect(std.mem.eql(u8, message, "hello world"));
}

test "native types - booleans" {
    // Test boolean type
    const BoolArg = Arg(bool, "enabled", "Whether feature is enabled");

    // Test parsing
    try std.testing.expect(try BoolArg.parse("true") == true);
    try std.testing.expect(try BoolArg.parse("false") == false);
    try std.testing.expect(try BoolArg.parse("1") == true);
}

test "struct field naming" {
    const MonetaryAmountArg = Arg([]const u8, "monetary-amount", "Monetary amount in USD");

    try std.testing.expect(std.mem.eql(u8, "monetary_amount", &MonetaryAmountArg.field_name));
}

test "description accessibility" {
    const TestArg = Arg([]const u8, "test-arg", "This is a test argument");

    // Verify description is accessible
    try std.testing.expect(std.mem.eql(u8, TestArg.description, "This is a test argument"));
    try std.testing.expect(std.mem.eql(u8, TestArg.arg_name, "test-arg"));
}


