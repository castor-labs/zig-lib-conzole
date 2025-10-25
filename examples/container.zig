const std = @import("std");
const conzole = @import("conzole");

// Container management argument structs
const RunArgs = struct {
    image: []const u8,
    // Container flags
    detach: bool,
    interactive: bool,
    name: []const u8,
    port: []const u8,
    // Global flags
    verbose: bool,
    quiet: bool,
    // Shared flags
    dry_run: bool,
};

const StopArgs = struct {
    container: []const u8,
    // Container flags
    force: bool,
    timeout: i32,
    // Global flags
    verbose: bool,
    quiet: bool,
    // Shared flags
    dry_run: bool,
};

const ListArgs = struct {
    // Container flags
    all: bool,
    // Global flags
    verbose: bool,
    quiet: bool,
    // Shared flags
    dry_run: bool,
};

const RemoveArgs = struct {
    container: []const u8,
    // Container flags
    force: bool,
    volumes: bool,
    // Global flags
    verbose: bool,
    quiet: bool,
    // Shared flags
    dry_run: bool,
};

// Image management argument structs
const PullArgs = struct {
    image: []const u8,
    // Image flags
    all_tags: bool,
    // Global flags
    verbose: bool,
    quiet: bool,
    // Shared flags
    dry_run: bool,
};

const BuildArgs = struct {
    path: []const u8,
    // Image flags
    tag: []const u8,
    file: []const u8,
    no_cache: bool,
    // Global flags
    verbose: bool,
    quiet: bool,
    // Shared flags
    dry_run: bool,
};

const ImageListArgs = struct {
    // Image flags
    all: bool,
    // Global flags
    verbose: bool,
    quiet: bool,
    // Shared flags
    dry_run: bool,
};

// Network management argument structs
const NetworkCreateArgs = struct {
    name: []const u8,
    // Network flags
    driver: []const u8,
    subnet: []const u8,
    // Global flags
    verbose: bool,
    quiet: bool,
    // Shared flags
    dry_run: bool,
};

const NetworkListArgs = struct {
    // Global flags
    verbose: bool,
    quiet: bool,
    // Shared flags
    dry_run: bool,
};

// Action functions
fn containerRunAction(args: RunArgs) !u8 {
    if (!args.quiet) {
        if (args.dry_run) {
            std.debug.print("[DRY RUN] ", .{});
        }
        if (args.verbose) {
            std.debug.print("Running container from image: {s}\n", .{args.image});
            if (args.name.len > 0) {
                std.debug.print("Container name: {s}\n", .{args.name});
            }
            if (args.port.len > 0) {
                std.debug.print("Port mapping: {s}\n", .{args.port});
            }
        } else {
            std.debug.print("Running {s}", .{args.image});
            if (args.name.len > 0) {
                std.debug.print(" (name: {s})", .{args.name});
            }
            std.debug.print("\n", .{});
        }

        if (args.detach) {
            std.debug.print("Running in detached mode\n", .{});
        }
        if (args.interactive) {
            std.debug.print("Running in interactive mode\n", .{});
        }
    }
    return 0;
}

fn containerStopAction(args: StopArgs) !u8 {
    if (!args.quiet) {
        if (args.dry_run) {
            std.debug.print("[DRY RUN] ", .{});
        }
        if (args.force) {
            std.debug.print("Force stopping container: {s}", .{args.container});
        } else {
            std.debug.print("Stopping container: {s}", .{args.container});
        }
        if (args.verbose and args.timeout != 10) {
            std.debug.print(" (timeout: {}s)", .{args.timeout});
        }
        std.debug.print("\n", .{});
    }
    return 0;
}

fn containerListAction(args: ListArgs) !u8 {
    if (args.dry_run) {
        std.debug.print("[DRY RUN] ", .{});
    }
    if (!args.quiet) {
        if (args.verbose) {
            std.debug.print("Listing containers", .{});
            if (args.all) {
                std.debug.print(" (including stopped)", .{});
            }
            std.debug.print(":\n", .{});
            std.debug.print("CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS\n", .{});
        }
        std.debug.print("abc123         nginx     nginx     1h ago    Running\n", .{});
        if (args.all) {
            std.debug.print("def456         ubuntu    bash      2h ago    Exited\n", .{});
        }
    }
    return 0;
}

fn containerRemoveAction(args: RemoveArgs) !u8 {
    if (args.dry_run) {
        std.debug.print("[DRY RUN] ", .{});
    }
    if (!args.quiet) {
        if (args.force) {
            std.debug.print("Force removing container: {s}", .{args.container});
        } else {
            std.debug.print("Removing container: {s}", .{args.container});
        }
        if (args.volumes) {
            std.debug.print(" (including volumes)", .{});
        }
        std.debug.print("\n", .{});
    }
    return 0;
}

fn imagePullAction(args: PullArgs) !u8 {
    if (args.dry_run) {
        std.debug.print("[DRY RUN] ", .{});
    }
    if (!args.quiet) {
        std.debug.print("Pulling image: {s}", .{args.image});
        if (args.all_tags) {
            std.debug.print(" (all tags)", .{});
        }
        std.debug.print("\n", .{});
        if (args.verbose) {
            std.debug.print("Download complete\n", .{});
        }
    }
    return 0;
}

fn imageBuildAction(args: BuildArgs) !u8 {
    if (args.dry_run) {
        std.debug.print("[DRY RUN] ", .{});
    }
    if (!args.quiet) {
        std.debug.print("Building image from: {s}", .{args.path});
        if (args.tag.len > 0) {
            std.debug.print(" (tag: {s})", .{args.tag});
        }
        if (args.file.len > 0 and !std.mem.eql(u8, args.file, "Dockerfile")) {
            std.debug.print(" (dockerfile: {s})", .{args.file});
        }
        std.debug.print("\n", .{});
        if (args.no_cache) {
            std.debug.print("Building without cache\n", .{});
        }
        if (args.verbose) {
            std.debug.print("Build complete\n", .{});
        }
    }
    return 0;
}

fn imageListAction(args: ImageListArgs) !u8 {
    if (args.dry_run) {
        std.debug.print("[DRY RUN] ", .{});
    }
    if (!args.quiet) {
        if (args.verbose) {
            std.debug.print("Listing images", .{});
            if (args.all) {
                std.debug.print(" (including intermediate)", .{});
            }
            std.debug.print(":\n", .{});
            std.debug.print("REPOSITORY   TAG       IMAGE ID     CREATED     SIZE\n", .{});
        }
        std.debug.print("nginx        latest    abc123def    2 days ago  142MB\n", .{});
        std.debug.print("ubuntu       20.04     def456ghi    1 week ago  72.8MB\n", .{});
        if (args.all) {
            std.debug.print("<none>       <none>    ghi789jkl    1 week ago  0B\n", .{});
        }
    }
    return 0;
}

fn networkCreateAction(args: NetworkCreateArgs) !u8 {
    if (args.dry_run) {
        std.debug.print("[DRY RUN] ", .{});
    }
    if (!args.quiet) {
        std.debug.print("Creating network: {s}", .{args.name});
        if (args.driver.len > 0 and !std.mem.eql(u8, args.driver, "bridge")) {
            std.debug.print(" (driver: {s})", .{args.driver});
        }
        if (args.subnet.len > 0) {
            std.debug.print(" (subnet: {s})", .{args.subnet});
        }
        std.debug.print("\n", .{});
        if (args.verbose) {
            std.debug.print("Network created successfully\n", .{});
        }
    }
    return 0;
}

fn networkListAction(args: NetworkListArgs) !u8 {
    if (args.dry_run) {
        std.debug.print("[DRY RUN] ", .{});
    }
    if (!args.quiet) {
        if (args.verbose) {
            std.debug.print("Listing networks:\n", .{});
            std.debug.print("NETWORK ID   NAME      DRIVER   SCOPE\n", .{});
        }
        std.debug.print("abc123def    bridge    bridge   local\n", .{});
        std.debug.print("def456ghi    host      host     local\n", .{});
        std.debug.print("ghi789jkl    none      null     local\n", .{});
    }
    return 0;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Container commands
    const container_run_command = conzole.Command(.{
        .name = "run",
        .description = "Run a new container from an image",
        .help =
            \\EXAMPLES:
            \\    container run nginx
            \\    container run --detach --name web --port 8080:80 nginx
            \\    container run --interactive ubuntu bash
            \\
            \\NOTES:
            \\    - Use --detach for long-running services
            \\    - Use --interactive for shells and interactive programs
            \\    - Port format is HOST_PORT:CONTAINER_PORT
        ,
        .action = containerRunAction,
        .flags = [_]type{
            conzole.Flag(bool, "detach", false, "Run container in background"),
            conzole.Flag(bool, "interactive", false, "Keep STDIN open and allocate a pseudo-TTY"),
            conzole.Flag([]const u8, "name", "", "Assign a name to the container"),
            conzole.Flag([]const u8, "port", "", "Publish container ports to host"),
        },
        .arguments = [_]type{
            conzole.Arg([]const u8, "image", "Container image to run"),
        },
    });

    const container_stop_command = conzole.Command(.{
        .name = "stop",
        .description = "Stop one or more running containers",
        .action = containerStopAction,
        .flags = [_]type{
            conzole.Flag(bool, "force", false, "Force stop the container"),
            conzole.Flag(i32, "timeout", 10, "Seconds to wait before killing the container"),
        },
        .arguments = [_]type{
            conzole.Arg([]const u8, "container", "Container name or ID to stop"),
        },
    });

    const container_list_command = conzole.Command(.{
        .name = "list",
        .description = "List containers",
        .action = containerListAction,
        .flags = [_]type{
            conzole.Flag(bool, "all", false, "Show all containers (default shows just running)"),
        },
        .arguments = [_]type{},
    });

    const container_remove_command = conzole.Command(.{
        .name = "remove",
        .description = "Remove one or more containers",
        .action = containerRemoveAction,
        .flags = [_]type{
            conzole.Flag(bool, "force", false, "Force removal of running container"),
            conzole.Flag(bool, "volumes", false, "Remove associated volumes"),
        },
        .arguments = [_]type{
            conzole.Arg([]const u8, "container", "Container name or ID to remove"),
        },
    });

    // Image commands
    const image_pull_command = conzole.Command(.{
        .name = "pull",
        .description = "Pull an image or repository from a registry",
        .action = imagePullAction,
        .flags = [_]type{
            conzole.Flag(bool, "all-tags", false, "Download all tagged images in the repository"),
        },
        .arguments = [_]type{
            conzole.Arg([]const u8, "image", "Image name to pull"),
        },
    });

    const image_build_command = conzole.Command(.{
        .name = "build",
        .description = "Build an image from a Dockerfile",
        .action = imageBuildAction,
        .flags = [_]type{
            conzole.Flag([]const u8, "tag", "", "Name and optionally tag in 'name:tag' format"),
            conzole.Flag([]const u8, "file", "Dockerfile", "Name of the Dockerfile"),
            conzole.Flag(bool, "no-cache", false, "Do not use cache when building the image"),
        },
        .arguments = [_]type{
            conzole.Arg([]const u8, "path", "Build context path"),
        },
    });

    const image_list_command = conzole.Command(.{
        .name = "list",
        .description = "List images",
        .action = imageListAction,
        .flags = [_]type{
            conzole.Flag(bool, "all", false, "Show all images (default hides intermediate images)"),
        },
        .arguments = [_]type{},
    });

    // Network commands
    const network_create_command = conzole.Command(.{
        .name = "create",
        .description = "Create a network",
        .action = networkCreateAction,
        .flags = [_]type{
            conzole.Flag([]const u8, "driver", "bridge", "Driver to manage the network"),
            conzole.Flag([]const u8, "subnet", "", "Subnet in CIDR format"),
        },
        .arguments = [_]type{
            conzole.Arg([]const u8, "name", "Network name"),
        },
    });

    const network_list_command = conzole.Command(.{
        .name = "list",
        .description = "List networks",
        .action = networkListAction,
        .flags = [_]type{},
        .arguments = [_]type{},
    });

    // SubCommands
    const container_subcommand = conzole.SubCommand(.{
        .name = "container",
        .description = "Manage containers",
        .help =
            \\EXAMPLES:
            \\    container run nginx                    # Run nginx container
            \\    container --dry-run stop mycontainer   # Preview stop operation
            \\    container list --all                   # List all containers
            \\    container remove --force mycontainer   # Force remove container
            \\
            \\NOTES:
            \\    - Use --dry-run to preview operations without executing
            \\    - Global flags like --verbose affect all container commands
            \\    - Container names must be unique within the system
        ,
        .commands = .{ container_run_command, container_stop_command, container_list_command, container_remove_command },
        .flags = [_]type{
            conzole.Flag(bool, "dry-run", false, "Show what would be done without executing"),
        },
    });

    const image_subcommand = conzole.SubCommand(.{
        .name = "image",
        .description = "Manage images",
        .commands = .{ image_pull_command, image_build_command, image_list_command },
        .flags = [_]type{
            conzole.Flag(bool, "dry-run", false, "Show what would be done without executing"),
        },
    });

    const network_subcommand = conzole.SubCommand(.{
        .name = "network",
        .description = "Manage networks",
        .commands = .{ network_create_command, network_list_command },
        .flags = [_]type{
            conzole.Flag(bool, "dry-run", false, "Show what would be done without executing"),
        },
    });

    // Main application
    const app = conzole.App(.{
        .name = "container",
        .description = "A Docker-like container management tool",
        .help =
            \\EXAMPLES:
            \\    container container run --detach nginx
            \\    container --verbose image build --tag myapp .
            \\    container network create --driver bridge mynet
            \\    container --quiet container list --all
            \\
            \\WORKFLOW:
            \\    1. Pull or build images: container image pull nginx
            \\    2. Create networks: container network create mynet
            \\    3. Run containers: container container run nginx
            \\    4. Manage lifecycle: container container stop/remove
            \\
            \\NOTES:
            \\    - Each subcommand supports --dry-run to preview operations
            \\    - Use --verbose for detailed output, --quiet for minimal output
            \\    - Global flags affect all subcommands and their operations
        ,
        .commands = .{ container_subcommand, image_subcommand, network_subcommand },
        .flags = [_]type{
            conzole.Flag(bool, "verbose", false, "Enable verbose output"),
            conzole.Flag(bool, "quiet", false, "Suppress output"),
        },
    });

    const exit_code = try app.run(args[1..]);
    std.process.exit(@intCast(exit_code));
}
