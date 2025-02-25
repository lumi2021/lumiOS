const std = @import("std");
const root = @import("root");
const os = root.os;

const FAT = @import("formats/FAT.zig");

const disk = os.drivers.disk;

const write = os.console_write("filesys");
const st = os.stack_tracer;

pub const FileAccessFlags = packed struct(u64) {
    read: bool,
    write: bool,
    execute: bool,

    create_new: bool,
    _: u60
};

pub fn init() !void {
    st.push(@src()); defer st.pop();

    write.log("Initializing file system...", .{});
}

pub fn open_file_descriptor(path: [:0]u8, flags: FileAccessFlags) i64 {
    st.push(@src()); defer st.pop();

    _ = flags;

    write.log("Trying to open file \"{s}\" (len {})", .{path, path.len});
    if (path.len >= 6 and std.mem.eql(u8, path[0..5], "sys:/")) {
        write.log("is system virtual directory", .{});
        return -1;
    }

    var sector: [512]u8 = undefined;
    disk.read_sector(0, &sector);

    const bpb: *align(1) FAT.BPB = @ptrCast(sector[0..256]);

    write.dbg("Disk info:\n jmp: {X} {X} {X}\n bps: {}\n nsc: {}\n nft: 0x{X}\n size: {} KiB",
        .{bpb.assembly_jump[0], bpb.assembly_jump[1], bpb.assembly_jump[2],
        bpb.bytes_per_sector, bpb.num_fats, bpb.media_descriptor,
        @as(usize, @intCast(bpb.bytes_per_sector)) * @as(usize, @intCast(bpb.total_sectors)) / 1024});

    return -1;   
}
