const std = @import("std");
const os = @import("root").os;

const TaskContext = os.theading.TaskContext;
const taskResources = os.theading.taskResources;

const write = os.console_write("Task");
const st = os.stack_tracer;

const guard_size = os.theading.stack_guard_size;
const map_size = os.theading.task_stack_size;
const total_size = guard_size + map_size;

pub const Task = struct {
    task_name: [:0]u8,

    entry_pointer: usize,
    args_pointer: usize,

    stack: []u8,
    stack_pointer: usize,

    stack_trace: [1024][128]u8,
    stack_trace_count: u16,

    context: TaskContext,

    taskAllocator: std.heap.ArenaAllocator,

    // task resources
    input_context: ?*taskResources.inputContext.InputContextPool = null,

    pub fn allocate_new() *Task {
        st.push(@src());
        defer st.pop();

        const ptr = os.memory.allocator.create(Task) catch @panic("undefined error");

        ptr.stack_trace = undefined;
        ptr.stack_trace_count = 3;

        // Dummy task entries
        ptr.stack_trace[0] = @constCast("*Interrupt 20 (32)" ++ [1]u8{0} ** 110).*;
        ptr.stack_trace[1] = @constCast("kernel/src/interruptions.zig:handle_timer_interrupt l.xxx" ++ [1]u8{0} ** 71).*;
        ptr.stack_trace[2] = @constCast("kernel/src/theading/schedue.zig:do_schedue l.xxx" ++ [1]u8{0} ** 80).*;

        ptr.context = std.mem.zeroes(TaskContext);
        ptr.taskAllocator = std.heap.ArenaAllocator.init(os.memory.allocator);

        return ptr;
    }

    pub fn destry(self: *@This()) void {
        if (self.input_context) |ctx|
            @import("../drivers/ps2/keyboard/state.zig").clean_input_context(ctx);
    }

    pub fn alloc_stack(self: *@This()) !void {
        st.push(@src());
        defer st.pop();

        const allocator = self.taskAllocator.allocator();

        self.stack = try allocator.alloc(u8, total_size);
        errdefer allocator.free(self.stack);

        self.stack_pointer = @intFromPtr(&self.stack) + total_size;
    }

    pub fn format(self: *const @This(), comptime _: []const u8, _: std.fmt.FormatOptions, fmt: anytype) !void {
        try fmt.print("Task \"{s}\"\n", .{self.task_name});
        try fmt.print("Context:\n{0}", .{self.context});
    }
};
