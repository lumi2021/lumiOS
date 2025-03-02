pub const input = .{
    .usb = .{ .enable = false },
    .ps2 = .{ .enable = true, .keyboard = true, .mouse = true },
};

pub const max_ioapics = 5;

pub const debug_ignore: []const KeyValuePair = &[_]KeyValuePair{
    .{ .key = "Main", .value = default },
    
    // memory
    .{ .key = "PMM", .value = default },
    .{ .key = "VMM", .value = default },
    .{ .key = "Paging", .value = default },

    // threading
    .{ .key = "schedue", .value = ignore_all },
    .{ .key = "taskman", .value = default },
    .{ .key = "task", .value = default },

    // interruptions
    .{ .key = "IDTM", .value = ignore_all },
    .{ .key = "syscall", .value = default },

    // file system
    .{ .key = "fs", .value = default },
    .{ .key = "vfs", .value = default },

    // Drivers related
    .{ .key = "Drivers", .value = ignore_all },
    .{ .key = "PCI", .value = ignore_all },
    .{ .key = "ps2", .value = ignore_all },
    .{ .key = "Keyboard", .value = ignore_all },

    // Allocations
    .{ .key = "Alloc", .value = ignore_all },

    .{ .key = "ProcessA", .value = default },

    // Debug
    .{ .key = "Stack Tracer", .value = ignore_all },
};

const KeyValuePair = struct { key: []const u8, value: u8 };
const default: u8 = 0b00000000;
const ignore_log: u8 = 0b00000001;
const ignore_err: u8 = 0b00000010;
const ignore_dbg: u8 = 0b00000100;
const ignore_warn: u8 = 0b00001000;
const ignore_all: u8 = 0b00001101;
