const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    b.setPreferredReleaseMode(.ReleaseSmall);
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("ps1fmt", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.strip = true;
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run ps1fmt");
    run_step.dependOn(&run_cmd.step);
}
