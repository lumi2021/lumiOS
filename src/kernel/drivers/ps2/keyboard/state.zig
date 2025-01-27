const os = @import("root").os;
const std = @import("std");

const log = os.console_write("keyboard state");

const kb = @import("keyboard.zig");

const PressedState = [@typeInfo(kb.keys.Location).@"enum".fields.len]bool;

fn pressedStateInit() PressedState {
    @setEvalBranchQuota(99999999);
    return std.mem.zeroes(PressedState);
}

pub const KeyboardState = struct {
    is_pressed: PressedState = pressedStateInit(),
    layout: kb.layouts.KeyboardLayout,

    pub fn pressed(self: *const @This(), location: kb.keys.Location) bool {
        return self.is_pressed[@intFromEnum(location)];
    }

    pub fn isShiftPressed(self: *const @This()) bool {
        return self.pressed(.left_shift) or self.pressed(.right_shift);
    }

    pub fn isAltPressed(self: *const @This()) bool {
        return self.pressed(.left_alt) or self.pressed(.right_alt);
    }

    pub fn isSuperPressed(self: *const @This()) bool {
        return self.pressed(.left_super) or self.pressed(.right_super);
    }

    pub fn isCtrlPressed(self: *const @This()) bool {
        return self.pressed(.left_ctrl) or self.pressed(.right_ctrl);
    }

    pub fn event(self: *@This(), t: kb.event.EventType, location: kb.keys.Location) !void {
        const input = try kb.layouts.getInput(self, location, self.layout);
        switch (t) {
            .press => {
                self.is_pressed[@intFromEnum(location)] = true;
            },
            .release => {
                self.is_pressed[@intFromEnum(location)] = false;
            },
        }

        // TODO: Send `input` and `location` to listeners
        log.dbg("{s} {s}ed", .{ @tagName(input), @tagName(t) });
    }
};
