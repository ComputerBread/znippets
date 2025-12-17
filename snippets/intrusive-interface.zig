const std = @import("std");

const IntrusiveInterface = struct {
    behavior1Fn: *const fn (ptr: *IntrusiveInterface) u32,
    behavior2Fn: *const fn (ptr: *IntrusiveInterface, arg: u32) u32,

    pub fn behavior1(self: *IntrusiveInterface) u32 {
        return self.behavior1Fn(self);
    }

    pub fn behavior2(self: *IntrusiveInterface, arg: u32) u32 {
        return self.behavior2Fn(self, arg);
    }
};

const ConcreteType = struct {
    interface: IntrusiveInterface,
    data: u32,

    fn behavior1Fn(ptr: *IntrusiveInterface) u32 {
        const self: *ConcreteType = @fieldParentPtr("interface", ptr);
        return self.data;
    }

    fn behavior2Fn(ptr: *IntrusiveInterface, arg: u32) u32 {
        const self: *ConcreteType = @fieldParentPtr("interface", ptr);
        self.data += arg;
        return self.data;
    }
};

test {
    var crew_mate = ConcreteType{
        .interface = .{
            .behavior1Fn = ConcreteType.behavior1Fn,
            .behavior2Fn = ConcreteType.behavior2Fn,
        },
        .data = 10,
    };
    var among_us: *IntrusiveInterface = &crew_mate.interface;
    try std.testing.expectEqual(10, among_us.behavior1());
    try std.testing.expectEqual(15, among_us.behavior2(5));
    try std.testing.expectEqual(15, crew_mate.data);
}
