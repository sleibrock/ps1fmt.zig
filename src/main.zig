const std = @import("std");
const io = std.io;
const debug = std.debug;
const os = std.os;
const ArrayList = std.ArrayList;

// figure out a way to represent ansi signals/vars
const ANSI = enum {
    none,
    open,
    close,
    before_seq,
    after_seq,
    terminator,

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

// state machine type representing the current state
// of the parser
const StateM = enum {
    none,
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

    // openers, closers, or terminators
    terminator, // end, or \\[
    opener, // signal that starts a sequence
    closer, // signal that ends an opener
    before_seq, // \[
    after_seq, // \]

    // variables to match the ANSI enum
    var_date_dmy,
    var_time12h,
    var_time12a,
    var_time24h,
    var_pathshort,
    var_pathfull,
    var_newline,
    var_carriage_ret,
    var_jobs,
    var_username,
    var_short_hostname,
    var_full_hostname,
    var_termdevice,
    var_shell_name,
    var_shell_version,
    var_shell_version_plvl,
    var_command_pos,
    var_command_number,
    var_is_root,
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
pub fn next_state(S: StateM, x: u8) StateM {
    switch (S) {
        StateM.none => {
            if (x == '\\')
                return StateM.begin;
        },
        StateM.begin => {
            // if it's \e, interpret as an escape code
            // and move up to the command sequence stage
            if (x == 'e')
                return StateM.byte3;

            // check for single-char ansi codes
            // these are word wrap markers
            if (x == '[')
                return StateM.before_seq;
            if (x == ']')
                return StateM.after_seq;

            // these are PSX fill-in variables
            if (x == 'd')
                return StateM.var_date_dmy;
            if (x == 'T')
                return StateM.var_time12h;
            if (x == '@')
                return StateM.var_time12a;
            if (x == 'w')
                return StateM.var_pathshort;
            if (x == 'W')
                return StateM.var_pathfull;
            if (x == 'n')
                return StateM.var_newline;
            if (x == 'r')
                return StateM.var_carriage_ret;
            if (x == 'u')
                return StateM.var_username;
            if (x == 'h')
                return StateM.var_short_hostname;
            if (x == 'H')
                return StateM.var_full_hostname;
            if (x == 'j')
                return StateM.var_jobs;
            if (x == 'l')
                return StateM.var_termdevice;
            if (x == 's')
                return StateM.var_shell_name;
            if (x == 'v')
                return StateM.var_shell_version;
            if (x == 'V')
                return StateM.var_shell_version_plvl;
            if (x == '!')
                return StateM.var_command_pos;
            if (x == '#')
                return StateM.var_command_number;
            if (x == '$')
                return StateM.var_is_root;

            // absorb next 3 numbers for ascii escape
            if (is_num(x))
                return StateM.byte1;
        },
        StateM.byte1 => {
            if (is_num(x))
                return StateM.byte2;
        },
        StateM.byte2 => {
            if (is_num(x))
                return StateM.byte3;
        },
        StateM.byte3 => {
            if (x == '[')
                return StateM.byte4;
        },
        StateM.byte4 => {
            if (is_num(x))
                return StateM.byte5;
        },
        StateM.byte5 => {
            // the first opcode can be one or two digits
            // so if it's a number, move on, else jump further
            if (is_num(x))
                return StateM.byte6;
            if (x == ';')
                return StateM.byte7;
        },
        StateM.byte6 => {
            // is either ; or m
            if (x == 'm')
                return StateM.closer;
            if (x == ';')
                return StateM.byte7;
        },
        StateM.byte7 => {
            if (is_num(x))
                return StateM.byte8;
        },
        StateM.byte8 => {
            if (is_num(x))
                return StateM.byte9;
        },
        StateM.byte9 => {
            if (x == 'm')
                return StateM.opener;
        },
        else => {
            return StateM.none;
        },
    }
    return StateM.none;
}

// Convert a StateM enum to an ANSI enum
// Instead of bundling up the final steps
// in main, let's use this to convert
// base case: no signal match and it gives us ANSI.none
pub fn statem_to_ansi(S: StateM) ANSI {
    switch (S) {
        StateM.terminator => {
            return ANSI.terminator;
        },
        StateM.before_seq => {
            return ANSI.before_seq;
        },
        StateM.after_seq => {
            return ANSI.after_seq;
        },
        StateM.opener => {
            return ANSI.open;
        },
        StateM.closer => {
            return ANSI.close;
        },
        StateM.var_date_dmy => {
            return ANSI.date_dmy;
        },
        StateM.var_time12h => {
            return ANSI.time12h;
        },
        StateM.var_time12a => {
            return ANSI.time12a;
        },
        StateM.var_time24h => {
            return ANSI.time24h;
        },
        StateM.var_username => {
            return ANSI.username;
        },
        StateM.var_short_hostname => {
            return ANSI.short_hostname;
        },
        StateM.var_full_hostname => {
            return ANSI.full_hostname;
        },
        StateM.var_pathshort => {
            return ANSI.path_short;
        },
        StateM.var_pathfull => {
            return ANSI.path_full;
        },
        StateM.var_newline => {
            return ANSI.new_line;
        },
        StateM.var_carriage_ret => {
            return ANSI.carriage_ret;
        },
        StateM.var_jobs => {
            return ANSI.jobs;
        },
        StateM.var_termdevice => {
            return ANSI.termdevice;
        },
        StateM.var_shell_name => {
            return ANSI.shell_name;
        },
        StateM.var_shell_version => {
            return ANSI.shell_version;
        },
        StateM.var_shell_version_plvl => {
            return ANSI.shell_version_plvl;
        },
        StateM.var_command_pos => {
            return ANSI.command_pos;
        },
        StateM.var_command_number => {
            return ANSI.command_number;
        },
        StateM.var_is_root => {
            return ANSI.is_root;
        },
        else => {},
    }
    return ANSI.none;
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
    var state = StateM.none;
    var result: ANSI = ANSI.none;
    for (ps1.?) |char| {
        // update the state to the next one by feeding it the next char
        state = next_state(state, char);

        // if we found a final state, append it to our list
        result = statem_to_ansi(state);
        if (result != ANSI.none) {
            try alist.append(result);
            result = ANSI.none;
            state = StateM.none;
        }
    }

    // print out your PS1 variable and all the signals used in it
    debug.print("PS1 is: {s}\n", .{ps1});
    debug.print("\n", .{});
    debug.print("Your signals are:\n", .{});
    for (alist.items) |element| {
        debug.print("{s}\n", .{element});
    }
    debug.print("\nGoodbye\n", .{});
}

// end ps1fmt.zig
