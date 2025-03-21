const std = @import("std");
const os = @import("root").os;

const MemMapEntry = os.boot_info.MemoryMapEntry;

const write = os.console_write("PMM");
const st = os.stack_tracer;

pub var max_phys_mem: usize = 0;
var phys_mapping_base_unsigned: usize = undefined;
pub var kernel_size: usize = undefined;
pub var kernel_phys_size: usize = undefined;
var phys_addr_width: u8 = undefined;
var phys_mapping_limit: usize = 1 << 31;


pub fn init(paddrwidth: u8, memmap: []*MemMapEntry) void {
    st.push(@src()); defer st.pop();

    const boot_info = @import("root").boot_info;

    phys_mapping_base_unsigned = boot_info.hhdm_address_offset;
    write.dbg("initial physical mapping base 0x{X:0>16}", .{phys_mapping_base_unsigned});

    const virt_base = boot_info.kernel_virtual_base;
    const virt_end = @intFromPtr(@extern(*u64, .{ .name = "__kernel_end__" }));
    kernel_size = std.mem.alignForwardLog2(virt_end - virt_base, 24);
    
    const phys_base = boot_info.kernel_physical_base;
    const phys_end = phys_base + kernel_size;

    write.dbg("kernel physical: 0x{X:0>16} .. 0x{X:0>16}", .{phys_base, phys_end});
    write.dbg("kernel virtual:  0x{X:0>16} .. 0x{X:0>16}", .{virt_base, virt_end});
    write.dbg("kernel size: 0x{X}", .{kernel_size});

    phys_addr_width = paddrwidth;

    var zeroed_page = std.mem.zeroes(MemMapEntry);
    var free_page: *MemMapEntry = &zeroed_page;

    for (memmap) |entry| {
        if (entry.type == .usable) {
            var base = entry.base;
            var size = entry.size;
            const end = base + size;

            if (end > max_phys_mem) max_phys_mem = end;

            // Being entirelly used by the kernel
            if (base > phys_base and end < phys_end) {
                write.dbg("skipping 0x{X}..0x{X} as it is space already reserved by the kernel.", .{ base, end });
                continue;
            }

            // Exeeds physical limit
            if (end > phys_mapping_limit) {
                write.dbg("skipping 0x{X}..0x{X} as it exceeds physical mapping limit.", .{ base, end });
                continue;
            }

            // Page includes but not entirelly kernel
            if (base < phys_base and end > phys_base) {
                const diff = end - phys_base;
                write.dbg("adjusting 0x{X}..0x{X} backward 0x{X} bytes to avoid kernel block.", .{ base, end, diff });
                size -= diff;
            }
            if (base < phys_end and end > phys_end) {
                const diff = phys_end - base;
                write.dbg("adjusting 0x{X}..0x{X} forward 0x{X} bytes to avoid kernel block.", .{ base, end, diff });
                base = phys_end;
                size -= diff;
            }

            if (size > free_page.size) {
                write.dbg("getting 0x{X}..0x{X} (0X{X} bytes)", .{ base, end, size });
                free_page = entry;
            }
            
        }
    }
    if (free_page.size == 0) @panic("No usable page found!");

    write.dbg(\\Free entry found:
    \\ base: 0x{X:0<16}
    \\ size: {} bytes
    , .{ free_page.base, free_page.size});

    var buf_slice: []u8 = undefined;
    buf_slice.ptr = @ptrFromInt(free_page.base);
    buf_slice.len = free_page.size;
    var buf_allocator_type = std.heap.FixedBufferAllocator.init(buf_slice);
    const buf_allocator = buf_allocator_type.allocator();

    _ = buf_allocator;
}

pub inline fn paddr_from_ptr(ptr: anytype) usize {
    return @intFromPtr(ptr) -% phys_mapping_base_unsigned;
}
pub inline fn paddr_from_vaddr(ptr: usize) usize {
    return ptr -% phys_mapping_base_unsigned;
}
pub inline fn vaddr_from_paddr(paddr: usize) usize {
    return paddr +% phys_mapping_base_unsigned;
}
pub inline fn ptr_from_paddr(T: type, paddr: usize) *T {
    return @ptrFromInt(vaddr_from_paddr(paddr));
}
