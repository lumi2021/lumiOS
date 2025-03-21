const std = @import("std");
const os = @import("root").os;
const paging = os.memory.paging;
const pmm = os.memory.pmm;

const MemMapEntry = os.boot_info.MemoryMapEntry;

const write = os.console_write("VMM");
const st = os.stack_tracer;

var phys_mapping_range_bits: u6 = undefined;

pub fn init(memmap: []*MemMapEntry) !void {
    st.push(@src()); defer st.pop();

    _ = memmap;
}

const write_allocator = os.console_write("Alloc");
pub const allocator = struct {
    vtab: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free },

    pub fn get(self: *const @This()) std.mem.Allocator {
        return .{ .ptr = undefined, .vtable = &self.vtab };
    }

    fn alloc(_: *anyopaque, len: usize, ptr_align: std.mem.Alignment, _: usize) ?[*]u8 {
        st.push(@src()); defer st.pop();

        _ = len;
        _ = ptr_align;

        return null;
    }

    fn resize(_: *anyopaque, old_mem: []u8, old_align: std.mem.Alignment, new_size: usize, ret_addr: usize) bool {
        st.push(@src()); defer st.pop();

        _ = old_mem;
        _ = new_size;
        _ = ret_addr;
        _ = old_align;

        return false;
    }

    fn remap(_ignored: *anyopaque, old_mem: []u8, old_align: std.mem.Alignment, new_size: usize, ret_addr: usize) ?[*]u8 {
        st.push(@src()); defer st.pop();

        _ = _ignored;
        _ = old_mem;
        _ = old_align;
        _ = new_size;
        _ = ret_addr;

        return null;
    }

    fn free(_: *anyopaque, old_mem: []u8, old_align: std.mem.Alignment, _: usize) void {
        st.push(@src()); defer st.pop();

        _ = old_mem;
        _ = old_align;
    }
}{};
