const std = @import("std");

const StageMetric = struct {
    second: u64,
    target_ops: u64,
    completed_ops: u64,
    elapsed_ns: u64,
};

fn busyOp(state: *u64) void {
    // operação pequena e determinística para evitar ser eliminada pelo compilador
    state.* = (state.* *% 6364136223846793005) +% 1442695040888963407;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // exe
    const duration_arg = args.next() orelse "30s";
    const step_arg = args.next() orelse "2s/2x";
    const start_arg = args.next() orelse "1000000ops";
    const out_path = args.next() orelse "zig/stress/algo.json";

    const duration_s = try parseSeconds(duration_arg);
    const step = try parseStep(step_arg);
    var target_ops = try parseOps(start_arg);

    var list = std.ArrayList(StageMetric).init(allocator);
    defer list.deinit();

    var prng_state: u64 = 0x1234_5678_9abc_def0;
    const total_start = std.time.nanoTimestamp();

    var current_s: u64 = 0;
    while (current_s < duration_s) {
        const stage_start = std.time.nanoTimestamp();

        var i: u64 = 0;
        while (i < target_ops) : (i += 1) {
            busyOp(&prng_state);
        }

        const stage_elapsed: u64 = @intCast(std.time.nanoTimestamp() - stage_start);
        try list.append(.{
            .second = current_s,
            .target_ops = target_ops,
            .completed_ops = target_ops,
            .elapsed_ns = stage_elapsed,
        });

        current_s += step.every_s;
        target_ops *%= step.multiplier;
    }

    const total_elapsed_ns: u64 = @intCast(std.time.nanoTimestamp() - total_start);

    var file = try std.fs.cwd().createFile(out_path, .{ .truncate = true });
    defer file.close();

    var bw = std.io.bufferedWriter(file.writer());
    const w = bw.writer();

    try w.print("{{\n", .{});
    try w.print("  \"duration_seconds\": {d},\n", .{duration_s});
    try w.print("  \"step_seconds\": {d},\n", .{step.every_s});
    try w.print("  \"multiplier\": {d},\n", .{step.multiplier});
    try w.print("  \"initial_ops\": {d},\n", .{try parseOps(start_arg)});
    try w.print("  \"total_elapsed_ns\": {d},\n", .{total_elapsed_ns});
    try w.print("  \"stages\": [\n", .{});

    for (list.items, 0..) |m, idx| {
        try w.print(
            "    {{ \"t\": {d}, \"target_ops\": {d}, \"completed_ops\": {d}, \"elapsed_ns\": {d} }}{s}\n",
            .{ m.second, m.target_ops, m.completed_ops, m.elapsed_ns, if (idx + 1 == list.items.len) "" else "," },
        );
    }

    try w.print("  ]\n", .{});
    try w.print("}}\n", .{});
    try bw.flush();
}

const Step = struct { every_s: u64, multiplier: u64 };

fn parseSeconds(s: []const u8) !u64 {
    if (!std.mem.endsWith(u8, s, "s")) return error.InvalidDuration;
    return std.fmt.parseInt(u64, s[0 .. s.len - 1], 10);
}

fn parseOps(s: []const u8) !u64 {
    if (!std.mem.endsWith(u8, s, "ops")) return error.InvalidOps;
    return std.fmt.parseInt(u64, s[0 .. s.len - 3], 10);
}

fn parseStep(s: []const u8) !Step {
    const slash = std.mem.indexOfScalar(u8, s, '/') orelse return error.InvalidStep;
    const first = s[0..slash];
    const second = s[slash + 1 ..];

    if (!std.mem.endsWith(u8, first, "s")) return error.InvalidStep;
    if (!std.mem.startsWith(u8, second, "2x") and !std.mem.endsWith(u8, second, "x")) return error.InvalidStep;

    const every_s = try std.fmt.parseInt(u64, first[0 .. first.len - 1], 10);
    const multiplier = try std.fmt.parseInt(u64, second[0 .. second.len - 1], 10);
    return .{ .every_s = every_s, .multiplier = multiplier };
}

test "parse step" {
    const step = try parseStep("2s/2x");
    try std.testing.expectEqual(@as(u64, 2), step.every_s);
    try std.testing.expectEqual(@as(u64, 2), step.multiplier);
}
