const std = @import("std");
const os = @import("root").os;
const paging = os.memory.paging;
const pmm = os.memory.pmm;

const MemMapEntry = os.boot_info.MemoryMapEntry;

const write = os.console_write("VMM");
const st = os.stack_tracer;

var phys_mapping_range_bits: u6 = undefined;

pub fn init(memmap: []*MemMapEntry) !void {
    st.push(@src());
    errdefer |err| write.err("error during VMM init: {s}", .{@errorName(err)});

    paging.using_5_level_paging = paging.features.five_level_paging; //and ctrl_registers.read(.cr4).la57;

    const boot_info = @import("root").boot_info;

    const base_phys = boot_info.kernel_physical_base;
    const base_linear = boot_info.kernel_virtual_base;

    const idmap_base: usize = boot_info.hhdm_address_offset;
    write.dbg("mapping all phys mem at 0x{X}", .{@as(usize, @bitCast(idmap_base))});

    phys_mapping_range_bits = if (paging.using_5_level_paging) @min(paging.features.maxphyaddr, 48) else @min(paging.features.maxphyaddr, 39);

    st.enabled = false;

    write.dbg("phys mapping range of {d} bits (0x{X} bytes)", .{ phys_mapping_range_bits, @as(usize, 1) << phys_mapping_range_bits });
    try paging.map_range(0, idmap_base, @as(usize, 1) << phys_mapping_range_bits);

    write.dbg("mapping bottom {X} at 0x{X} (0x{X} bytes)", .{ base_phys, base_linear, pmm.kernel_size });
    try paging.map_range(base_phys, base_linear, pmm.kernel_size);

    write.dbg("finished page tables, applying...", .{});
    paging.load_pgtbl();

    write.dbg("pages mapped, relocating and enlarging pmm", .{});
    pmm.enlarge_mapped_physical(memmap, idmap_base);

    write.dbg("high physical memory given to pmm", .{});
    paging.finalize();

    os.memory.allocator = allocator.get();
    write.dbg("Memory Allocator is ready to use", .{});

    st.enabled = true;
    st.pop();
}

const write_allocator = os.console_write("alloc");
pub const allocator = struct {
    vtab: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free },

    pub fn get(self: *const @This()) std.mem.Allocator {
        return .{ .ptr = undefined, .vtable = &self.vtab };
    }

    fn alloc(_: *anyopaque, len: usize, ptr_align: std.mem.Alignment, _: usize) ?[*]u8 {
        st.push(@src()); defer st.pop();

        const alloc_len = pmm.get_allocation_size(@max(@as(usize, 1) << @truncate(ptr_align.toByteUnits()), len));
        write_allocator.dbg("Trying to allocate {} bytes...", .{alloc_len});

        const ptr = pmm.ptr_from_paddr([*]u8, pmm.alloc(alloc_len) catch |err| {
            write.err("{}", .{err});
            return null;
        });

        write_allocator.dbg("Allocating {} bytes in address ${X:0>16}...", .{ len, @intFromPtr(ptr) });
        return ptr;
    }

    fn resize(_: *anyopaque, old_mem: []u8, old_align: std.mem.Alignment, new_size: usize, ret_addr: usize) bool {
        st.push(@src()); defer st.pop();

        const old_alloc = pmm.get_allocation_size(@max(old_mem.len,  old_align.toByteUnits()));

        const paddr = pmm.paddr_from_ptr(old_mem.ptr);

        if (new_size == 0) {
            free(undefined, old_mem, old_align, ret_addr);

            return true;
        } else {
            const new_alloc = pmm.get_allocation_size(@max(new_size, old_align.toByteUnits()));

            if (new_alloc > old_alloc) return false;

            var curr_alloc = old_alloc;
            while (new_alloc < old_alloc) {
                pmm.free(paddr + curr_alloc / 2, curr_alloc / 2);
                curr_alloc /= 2;
            }

            return true;
        }
    }

    fn remap(_ignored: *anyopaque, old_mem: []u8, old_align: std.mem.Alignment, new_size: usize, ret_addr: usize) ?[*]u8 {
        if (resize(_ignored, old_mem, old_align, new_size, ret_addr)) return old_mem.ptr;
        const buf = alloc(_ignored, new_size, old_align, 0).?;
        @memcpy(buf, old_mem);
        free(_ignored, old_mem, old_align, ret_addr);
        return buf;
    }

    fn free(_: *anyopaque, old_mem: []u8, old_align: std.mem.Alignment, _: usize) void {
        st.push(@src());

        const old_alloc = pmm.get_allocation_size(@max(old_mem.len, old_align.toByteUnits()));
        const paddr = pmm.paddr_from_ptr(old_mem.ptr);

        write_allocator.dbg("Trying to free {} bytes in address ${X:0>16}...", .{ old_alloc, paddr });

        pmm.free(paddr, old_alloc);

        st.pop();
    }
}{};
