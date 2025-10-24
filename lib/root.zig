const std = @import("std");

const command = @import("./command.zig");
const arg = @import("./arg.zig");
const flag = @import("./flag.zig");
const app = @import("./app.zig");
const subcommand = @import("./subcommand.zig");

pub const Command = command.Command;
pub const Arg = arg.Arg;
pub const Flag = flag.Flag;
pub const App = app.App;
pub const SubCommand = subcommand.SubCommand;

test {
    std.testing.refAllDecls(@This());
}

test "help rendering functionality" {
    // Test that help rendering works correctly
    const TestArgs = struct {
        name: []const u8,
        verbose: bool,
        debug: bool,  // Global flag
    };

    const testAction = struct {
        fn execute(args: TestArgs) !u8 {
            _ = args;
            return 0;
        }
    }.execute;

    const test_command = Command(.{
        .name = "greet",
        .description = "Greet a person",
        .help =
            \\EXAMPLES:
            \\    test greet Alice
            \\
            \\NOTES:
            \\    This tests the help system.
        ,
        .action = testAction,
        .arguments = [_]type{
            Arg([]const u8, "name", "Name of the person to greet"),
        },
        .flags = [_]type{
            Flag(bool, "verbose", false, "Enable verbose output"),
        },
    });

    const test_app = App(.{
        .name = "test",
        .description = "A test application",
        .help =
            \\EXAMPLES:
            \\    test greet Alice
            \\
            \\NOTES:
            \\    This is a test application.
        ,
        .commands = .{test_command},
        .flags = [_]type{
            Flag(bool, "debug", false, "Enable debug mode"),
        },
    });

    // Test that help can be rendered
    var buffer: [2048]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    // Render app help
    try test_app.renderHelp(writer);

    // Verify some content was written
    const written = fbs.getWritten();
    try std.testing.expect(written.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, written, "test - A test application") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "USAGE:") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "EXAMPLES:") != null);

    // Test command help rendering
    fbs.reset();
    try test_command.renderHelp(writer, [_]type{}, test_app.GlobalFlags);
    const command_help = fbs.getWritten();
    try std.testing.expect(command_help.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, command_help, "greet - Greet a person") != null);
    try std.testing.expect(std.mem.indexOf(u8, command_help, "USAGE:") != null);
    try std.testing.expect(std.mem.indexOf(u8, command_help, "EXAMPLES:") != null);
}








