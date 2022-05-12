const std = @import("std");
const io = std.io;
const debug = std.debug;
const os = std.os;
const ArrayList = std.ArrayList;

// Represent the difference between value and state
// value is result, state is in transition
const Tag = enum { value, state };

// apply the Tag enum to a proper union
const Result = union(Tag) { value: ANSI, state: StateM };

// Our way of representing ANSI escape sequences and actions
// or variables for substitution purposes
// before_seq and after_seq match each other,
// and end will terminate any action sequences before it
const ANSI = enum {
    none,
    action,
    end,
    before_seq,
    after_seq,

    // time/date
    date_dmy,
    time12h,
    time12a,
    time24h,

    // current path
    path_short,
    path_full,

    // username
    username,

    // hostname
    short_hostname,
    full_hostname,

    // newlines/carriage return
    new_line,
    carriage_ret,

    // jobs suspended with ^Z
    jobs,

    // shells terminal device (tty<x>)
    termdevice,

    // shell name/info
    shell_name,
    shell_version,
    shell_version_plvl,

    // username
    command_pos,
    command_number,

    // root info
    is_root,
};

// state machine type representing multiple parser states
const StateM = enum {
    none, // indicate no progress or invalidity
    begin, //\
    byte1, //0
    byte2, //3
    byte3, //3
    byte4, //[
    byte5, //x
    byte6, //y
    byte7, //;
    byte8, //z
    byte9, //w
    byte10, //v
    byte11, //m end of sequence
};

// number ascii range is from 48 to 57
// can re-write using switch statement to incorporate 48..57
pub fn is_num(x: u8) bool {
    if ((x > 47) and (x < 58)) {
        return true;
    }
    return false;
}

// A very long state machine dispatch function
// Very code heavy, but easy to add new features each step
// of the way.
// Basically a much longer Haskell function
pub fn next_state(S: StateM, x: u8) Result {
    switch (S) {
        StateM.none => {
            if (x == '\\')
                return .{ .state = StateM.begin };
        },
        StateM.begin => {
            // if it's \e, interpret as an escape code
            // and move up to the command sequence stage
            if (x == 'e')
                return .{ .state = StateM.byte3 };

            // check for single-char ansi codes
            // these are word wrap markers
            if (x == '[')
                return .{ .value = ANSI.before_seq };
            if (x == ']')
                return .{ .value = ANSI.after_seq };

            // these are PSX fill-in variables
            if (x == 'd')
                return .{ .value = ANSI.date_dmy };
            if (x == 'T')
                return .{ .value = ANSI.time12h };
            if (x == '@')
                return .{ .value = ANSI.time12a };
            if (x == 'w')
                return .{ .value = ANSI.path_short };
            if (x == 'W')
                return .{ .value = ANSI.path_full };
            if (x == 'n')
                return .{ .value = ANSI.new_line };
            if (x == 'r')
                return .{ .value = ANSI.carriage_ret };
            if (x == 'u')
                return .{ .value = ANSI.username };
            if (x == 'h')
                return .{ .value = ANSI.short_hostname };
            if (x == 'H')
                return .{ .value = ANSI.full_hostname };
            if (x == 'j')
                return .{ .value = ANSI.jobs };
            if (x == 'l')
                return .{ .value = ANSI.termdevice };
            if (x == 's')
                return .{ .value = ANSI.shell_name };
            if (x == 'v')
                return .{ .value = ANSI.shell_version };
            if (x == 'V')
                return .{ .value = ANSI.shell_version_plvl };
            if (x == '!')
                return .{ .value = ANSI.command_pos };
            if (x == '#')
                return .{ .value = ANSI.command_number };
            if (x == '$')
                return .{ .value = ANSI.is_root };

            // absorb next 3 numbers for ascii escape
            if (is_num(x))
                return .{ .state = StateM.byte1 };
        },
        StateM.byte1 => {
            if (is_num(x))
                return .{ .state = StateM.byte2 };
        },
        StateM.byte2 => {
            if (is_num(x))
                return .{ .state = StateM.byte3 };
        },
        StateM.byte3 => {
            if (x == '[')
                return .{ .state = StateM.byte4 };
        },
        StateM.byte4 => {
            if (is_num(x))
                return .{ .state = StateM.byte5 };
        },
        StateM.byte5 => {
            // the first opcode can be one or two digits
            // so if it's a number, move on, else jump further
            if (is_num(x))
                return .{ .state = StateM.byte6 };
            if (x == ';')
                return .{ .state = StateM.byte7 };
        },
        StateM.byte6 => {
            // is either ; or m
            if (x == 'm')
                return .{ .value = ANSI.end };
            if (x == ';')
                return .{ .state = StateM.byte7 };
        },
        StateM.byte7 => {
            if (is_num(x))
                return .{ .state = StateM.byte8 };
        },
        StateM.byte8 => {
            if (is_num(x))
                return .{ .state = StateM.byte9 };
        },
        StateM.byte9 => {
            if (x == 'm')
                return .{ .value = ANSI.action };
        },
        else => {
            return .{ .state = StateM.none };
        },
    }
    return .{ .state = StateM.none };
}

// Main function stub, glues logic together
// Commented for your viewing pleasure
pub fn main() !void {
    // Create an allocator arena for which we can alloc mem on heap
    // We use this to initialize an allocator for which we can use
    // for dynamic memory allocation (see the `alist`)
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // our results ArrayList, similar to std::vector
    // grows in size and uses ArenaAllocator
    // (note: we probably don't need an arraylist, but I'm learning zig)
    var alist = ArrayList(ANSI).init(alloc);

    // attempt to retrieve a $PS1 var from the host environment
    // getenv() returns ?const u8[], meaning it's either null or bytes
    var ps1 = os.getenv("PS1");
    if (ps1 == null) {
        debug.print("You have no $PS1 set in this shell\n", .{});
        return;
    }

    // iter over each char in PS1 str
    // note: `ps1.?` forces the optional `orelse` syntax
    // updated: now uses a tagged union dispatch
    // so we're not duplicating enum types everywhere!
    var result = StateM.none;
    for (ps1.?) |char| {
        switch (next_state(result, char)) {
            .state => |s| result = s,
            .value => |v| {
                try alist.append(v);
                result = StateM.none;
            },
        }
    }

    // print out your PS1 variable and all the signals used in it
    debug.print("PS1 is: {s}\n", .{ps1});
    debug.print("\n", .{});
    debug.print("Your signals are:\n", .{});
    for (alist.items) |element| {
        debug.print("{s}\n", .{element});
    }

    // do some kind of iteration w/ warnings

    debug.print("\nGoodbye\n", .{});
}

// end ps1fmt.zig
