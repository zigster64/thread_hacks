//--------------------------------------------------------------------------------
const std = @import("std");
const string = []const u8;
const print = std.debug.print;
const expect = @import("std").testing.expect;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = &gpa.allocator;

//--------------------------------------------------------------------------------
test "basic" {
    print("Basic test\n", .{});
}

//--------------------------------------------------------------------------------
// async transfers control to the function
// suspend returns control to the frame
var foo: i32 = 1;
test "suspend with no resume" {
    var frame = async func(); //1
    expect(foo == 2); //4
}

fn func() void {
    foo += 1; //2
    suspend; //3
    foo += 1; //never reached!
}

//--------------------------------------------------------------------------------
// async transfers control to the function
// suspend retruns control to the frame
// resume frame returns control to the func
// return returns control to the frame
var bar: i32 = 1;

test "suspend with resume" {
    var frame = async func2(); //1
    resume frame; //4
    expect(bar == 3); //6
}

fn func2() void {
    bar += 1; //2
    suspend; //3
    bar += 1; //5
}

//--------------------------------------------------------------------------------
// note that func3 has no async control / suspend / resume
// async transfers control to the function
// return returns control to the frame
// await waits for the function to return
test "async / await" {
    var frame = async func3();
    expect(await frame == 5);
}

fn func3() u32 {
    return 5;
}

//--------------------------------------------------------------------------------
// use nonsuspend to assert no async behaviour
// compiler will detect illegal usage
fn doTicksDuration(ticker: *u32) i64 {
    const start = std.time.milliTimestamp();

    while (ticker.* > 0) {
        suspend;
        ticker.* -= 1;
    }

    return std.time.milliTimestamp() - start;
}

pub fn test_breakout(start: u32) !void {
    var ticker: u32 = start;
    const duration = nosuspend doTicksDuration(&ticker);
    print("duration = {}\n", .{duration});
}

test "break out" {
    try test_breakout(0);
    // try test_breakout(1); // will throw comptime error because it can suspend
}

//--------------------------------------------------------------------------------
// @Frame gets a ptr to an async frame
fn add(a: i32, b: i32) i64 {
    return a + b;
}

test "@Frame" {
    var frame: @Frame(add) = async add(1, 2);
    expect(await frame == 3);
}

//--------------------------------------------------------------------------------
// @frame gets a ptr to self
fn double(value: u8) u9 {
    suspend {
        resume @frame();
    }
    return value * 2;
}

test "@frame 1" {
    var f = async double(1);
    expect(nosuspend await f == 2);
}

//--------------------------------------------------------------------------------
// passing the value from @frame to another function to resume us
fn callLater(comptime laterFn: fn () void, ms: u64) void {
    suspend {
        wakeupLater(@frame(), ms);
    }
    laterFn();
}

fn wakeupLater(frame: anyframe, ms: u64) void {
    std.time.sleep(ms * std.time.ns_per_ms);
    resume frame;
}

fn alarm() void {
    std.debug.print("Time's Up!\n", .{});
}

test "@frame 2" {
    nosuspend callLater(alarm, 1000);
}

//--------------------------------------------------------------------------------
// using ->T to restore the type info otherwise lost by the use of anytype
fn zero(comptime x: anytype) x {
    return 0;
}

fn awaiter(x: anyframe->f32) f32 {
    return nosuspend await x;
}

test "anyframe->T" {
    var frame = async zero(f32);
    expect(awaiter(&frame) == 0);
}
