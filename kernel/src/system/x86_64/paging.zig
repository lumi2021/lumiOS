const std = @import("std");
const os = @import("root").os;
const page_entries = os.system.memory_paging_entries;
const pmm = os.memory.pmm;

const cpuid = @import("cpuid.zig");
const ctrl_regs = @import("ctrl_registers.zig");

const PageTableEntry = page_entries.PageTableEntry;
const PageDirectoryEntry = page_entries.PageDirectoryEntry;
const PDPTE = page_entries.PageDirectoryPointerTableEntry;
const PageMapEntry = page_entries.PageMapEntry;

const write = os.console_write("Paging");
const st = os.stack_tracer;

pub var features: PagingFeatures = undefined;
pub const PagingFeatures = struct {
    maxphyaddr: u8,
    linear_address_width: u8,
    five_level_paging: bool,
    gigabyte_pages: bool,
    global_page_support: bool,
};
pub fn enumerate_paging_features() PagingFeatures {
    const addresses = cpuid.cpuid(.extended_address_info, {}).address_size_info;
    const feats_base = cpuid.cpuid(.type_fam_model_stepping_features, {});
    const feats_ext = cpuid.cpuid(.extended_fam_model_stepping_features, {});
    const flags = cpuid.cpuid(.feature_flags, {});
    features = PagingFeatures{
        .maxphyaddr = addresses.physical_address_bits,
        .linear_address_width = addresses.virtual_address_bits,
        .five_level_paging = flags.flags2.la57,
        .gigabyte_pages = feats_ext.features2.pg1g,
        .global_page_support = feats_base.features.pge,
    };
    return features;
}

pub const SplitPagingAddr = packed struct(isize) {
    byte: u12,
    page: u9,
    table: u9,
    directory: u9,
    dirptr: u9,
    pml4: i9,
    _: u7,

    pub fn format(self: *const @This(), comptime _: []const u8, _: std.fmt.FormatOptions, fmt: anytype) !void {
        try fmt.print("0x{X:0>16} {b:0>9}:{b:0>9}:{b:0>9}:{b:0>9}:{b:0>9}:{b:0>12}", .{ @as(usize, @bitCast(self.*)), @as(u9, @bitCast(self.pml4)), self.dirptr, self.directory, self.table, self.page, self.byte });
    }
};
