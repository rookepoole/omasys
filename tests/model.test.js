"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8");
const context = { Date, isFinite, Math, Number, String, Array, Object };
vm.createContext(context);
vm.runInContext(source, context, { filename: "Model.js" });

const systemSample = [
  "SYSV1",
  "CPU\t2000\t500",
  "MEM\t8000000\t2000000\t1000000\t250000",
  "LOAD\t1.25\t1.00\t0.75",
  "UPTIME\t90061",
  "DISK\t1000000\t400000\t600000\t40%",
  "NET\t100000\t50000",
  "GPU\t67",
  "TEMP\t55000",
  "META\tomasys-host\t6.0-test\tOmarchy\tTest CPU\t8\t1000",
  ""
].join("\n");

const stats = context.parseSystem(systemSample, { total: 1000, idle: 300 }, { rx: 90000, tx: 40000, time: Date.now() - 1000 });
assert.equal(stats.valid, true);
assert.equal(Math.round(stats.cpuPercent), 80);
assert.equal(Math.round(stats.memoryPercent), 75);
assert.equal(Math.round(stats.swapPercent), 75);
assert.equal(stats.diskPercent, 40);
assert.equal(stats.gpuPercent, 67);
assert.equal(stats.temperatureC, 55);
assert.equal(stats.hostname, "omasys-host");
assert.equal(stats.currentUid, 1000);
assert.ok(stats.networkRxPerSecond > 0);

const processSample = [
  "  42       1  1000 rook     R      0 80.5 10.0 204800     120      50 render          render --scene demo",
  "   7       1  1000 rook     S      5  1.5  2.0  40960    3600     100 worker          worker --queue default"
].join("\n");
const processes = context.parseProcesses(processSample);
assert.equal(processes.length, 2);
assert.equal(processes[0].pid, 42);
assert.equal(processes[0].command, "render");
assert.equal(processes[0].arguments, "render --scene demo");

const live = context.withLiveProcessCpu(processes, {
  time: Date.now() - 2000,
  processes: {
    "42": { totalCpuSeconds: 49, elapsedSeconds: 118 },
    "7": { totalCpuSeconds: 100, elapsedSeconds: 3598 }
  }
});
assert.ok(live.rows[0].cpu >= 45 && live.rows[0].cpu <= 55);

const byMemory = context.filteredAndSorted(processes, "rook", "memory", true);
assert.equal(byMemory[0].pid, 42);
const filtered = context.filteredAndSorted(processes, "queue default", "cpu", true);
assert.equal(filtered.length, 1);
assert.equal(filtered[0].pid, 7);

assert.equal(context.formatBytes(1024), "1.00 KiB");
assert.equal(context.formatDuration(90061), "1d 1h");
assert.equal(context.stateLabel("T+"), "Stopped");

process.stdout.write("Model tests passed\n");
