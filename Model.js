function clamp(value, minimum, maximum) {
  var number = Number(value)
  if (!isFinite(number)) return minimum
  return Math.max(minimum, Math.min(maximum, number))
}

function percent(part, whole) {
  var numerator = Number(part)
  var denominator = Number(whole)
  if (!isFinite(numerator) || !isFinite(denominator) || denominator <= 0) return 0
  return clamp(numerator * 100 / denominator, 0, 100)
}

function parseSystem(raw, previousCpu, previousNetwork) {
  var result = {
    valid: false,
    cpuPercent: 0,
    memoryPercent: 0,
    swapPercent: 0,
    diskPercent: 0,
    gpuPercent: -1,
    temperatureC: -1,
    load1: 0,
    load5: 0,
    load15: 0,
    uptimeSeconds: 0,
    memoryTotalKiB: 0,
    memoryUsedKiB: 0,
    swapTotalKiB: 0,
    swapUsedKiB: 0,
    diskTotalKiB: 0,
    diskUsedKiB: 0,
    networkRxBytes: 0,
    networkTxBytes: 0,
    networkRxPerSecond: 0,
    networkTxPerSecond: 0,
    hostname: "",
    kernel: "",
    distribution: "",
    cpuModel: "",
    cpuThreads: 0,
    currentUid: -1,
    cpuSnapshot: null,
    networkSnapshot: null
  }

  var lines = String(raw || "").split(/\r?\n/)
  if (lines.length === 0 || lines[0].trim() !== "SYSV1") return result

  for (var i = 1; i < lines.length; i++) {
    if (!lines[i]) continue
    var fields = lines[i].split("\t")
    var kind = fields[0]
    if (kind === "CPU" && fields.length >= 3) {
      result.cpuSnapshot = { total: Number(fields[1]), idle: Number(fields[2]) }
    } else if (kind === "MEM" && fields.length >= 5) {
      result.memoryTotalKiB = Number(fields[1]) || 0
      var available = Number(fields[2]) || 0
      result.memoryUsedKiB = Math.max(0, result.memoryTotalKiB - available)
      result.memoryPercent = percent(result.memoryUsedKiB, result.memoryTotalKiB)
      result.swapTotalKiB = Number(fields[3]) || 0
      var swapFree = Number(fields[4]) || 0
      result.swapUsedKiB = Math.max(0, result.swapTotalKiB - swapFree)
      result.swapPercent = percent(result.swapUsedKiB, result.swapTotalKiB)
    } else if (kind === "LOAD" && fields.length >= 4) {
      result.load1 = Number(fields[1]) || 0
      result.load5 = Number(fields[2]) || 0
      result.load15 = Number(fields[3]) || 0
    } else if (kind === "UPTIME" && fields.length >= 2) {
      result.uptimeSeconds = Math.max(0, Number(fields[1]) || 0)
    } else if (kind === "DISK" && fields.length >= 5) {
      result.diskTotalKiB = Number(fields[1]) || 0
      result.diskUsedKiB = Number(fields[2]) || 0
      result.diskPercent = clamp(String(fields[4]).replace("%", ""), 0, 100)
    } else if (kind === "NET" && fields.length >= 3) {
      result.networkRxBytes = Number(fields[1]) || 0
      result.networkTxBytes = Number(fields[2]) || 0
    } else if (kind === "GPU" && fields.length >= 2) {
      var gpuValue = Number(fields[1])
      result.gpuPercent = isFinite(gpuValue) && gpuValue >= 0 ? clamp(gpuValue, 0, 100) : -1
    } else if (kind === "TEMP" && fields.length >= 2) {
      var milliC = Number(fields[1])
      result.temperatureC = isFinite(milliC) && milliC >= 0 ? milliC / 1000 : -1
    } else if (kind === "META" && fields.length >= 6) {
      result.hostname = fields[1]
      result.kernel = fields[2]
      result.distribution = fields[3]
      result.cpuModel = fields[4]
      result.cpuThreads = Number(fields[5]) || 0
      result.currentUid = fields.length >= 7 ? Number(fields[6]) : -1
    }
  }

  if (result.cpuSnapshot && previousCpu) {
    var totalDelta = result.cpuSnapshot.total - Number(previousCpu.total || 0)
    var idleDelta = result.cpuSnapshot.idle - Number(previousCpu.idle || 0)
    if (totalDelta > 0) result.cpuPercent = clamp((totalDelta - idleDelta) * 100 / totalDelta, 0, 100)
  }

  var now = Date.now()
  result.networkSnapshot = {
    rx: result.networkRxBytes,
    tx: result.networkTxBytes,
    time: now
  }
  if (previousNetwork && Number(previousNetwork.time) > 0) {
    var elapsed = Math.max(0.001, (now - Number(previousNetwork.time)) / 1000)
    result.networkRxPerSecond = Math.max(0, (result.networkRxBytes - Number(previousNetwork.rx || 0)) / elapsed)
    result.networkTxPerSecond = Math.max(0, (result.networkTxBytes - Number(previousNetwork.tx || 0)) / elapsed)
  }

  result.valid = result.cpuSnapshot !== null
  return result
}

function parseProcesses(raw) {
  var rows = []
  var lines = String(raw || "").split(/\r?\n/)
  var pattern = /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(-?\d+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s*(.*)$/

  for (var i = 0; i < lines.length; i++) {
    var match = pattern.exec(lines[i])
    if (!match) continue
    rows.push({
      pid: Number(match[1]),
      ppid: Number(match[2]),
      uid: Number(match[3]),
      user: match[4],
      state: match[5],
      nice: Number(match[6]),
      cpu: Number(match[7]) || 0,
      memory: Number(match[8]) || 0,
      rssKiB: Number(match[9]) || 0,
      elapsedSeconds: Number(match[10]) || 0,
      totalCpuSeconds: Number(match[11]) || 0,
      command: match[12],
      arguments: match[13] || match[12]
    })
  }
  return rows
}

function withLiveProcessCpu(rows, previousSnapshot) {
  var now = Date.now()
  var nextSnapshot = { time: now, processes: {} }
  var previousTime = previousSnapshot ? Number(previousSnapshot.time || 0) : 0
  var elapsed = previousTime > 0 ? Math.max(0.001, (now - previousTime) / 1000) : 0
  var previousProcesses = previousSnapshot && previousSnapshot.processes ? previousSnapshot.processes : {}

  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    var key = String(row.pid)
    var previous = previousProcesses[key]
    if (elapsed > 0 && previous
        && row.elapsedSeconds >= Number(previous.elapsedSeconds || 0)
        && row.totalCpuSeconds >= Number(previous.totalCpuSeconds || 0)) {
      row.cpu = Math.max(0, (row.totalCpuSeconds - Number(previous.totalCpuSeconds || 0)) * 100 / elapsed)
    }
    nextSnapshot.processes[key] = {
      totalCpuSeconds: row.totalCpuSeconds,
      elapsedSeconds: row.elapsedSeconds
    }
  }
  return { rows: rows, snapshot: nextSnapshot }
}

function filteredAndSorted(rows, filterText, sortKey, descending) {
  var needle = String(filterText || "").trim().toLowerCase()
  var out = []
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    var haystack = (row.pid + " " + row.user + " " + row.command + " " + row.arguments).toLowerCase()
    if (needle === "" || haystack.indexOf(needle) !== -1) out.push(row)
  }

  var key = String(sortKey || "cpu")
  out.sort(function(a, b) {
    var av = a[key]
    var bv = b[key]
    var comparison
    if (typeof av === "string" || typeof bv === "string")
      comparison = String(av || "").localeCompare(String(bv || ""))
    else
      comparison = Number(av || 0) - Number(bv || 0)
    if (comparison === 0) comparison = a.pid - b.pid
    return descending ? -comparison : comparison
  })
  return out
}

function formatBytes(bytes) {
  var value = Math.max(0, Number(bytes) || 0)
  var units = ["B", "KiB", "MiB", "GiB", "TiB"]
  var unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit++
  }
  var digits = value >= 100 || unit === 0 ? 0 : (value >= 10 ? 1 : 2)
  return value.toFixed(digits) + " " + units[unit]
}

function formatRate(bytesPerSecond) {
  return formatBytes(bytesPerSecond) + "/s"
}

function formatDuration(seconds) {
  var value = Math.max(0, Math.floor(Number(seconds) || 0))
  var days = Math.floor(value / 86400)
  var hours = Math.floor((value % 86400) / 3600)
  var minutes = Math.floor((value % 3600) / 60)
  if (days > 0) return days + "d " + hours + "h"
  if (hours > 0) return hours + "h " + minutes + "m"
  if (minutes > 0) return minutes + "m"
  return value + "s"
}

function stateLabel(state) {
  var code = String(state || "").charAt(0)
  if (code === "R") return "Running"
  if (code === "S") return "Sleeping"
  if (code === "D") return "I/O wait"
  if (code === "T" || code === "t") return "Stopped"
  if (code === "Z") return "Zombie"
  if (code === "I") return "Idle"
  if (code === "X" || code === "x") return "Dead"
  return state || "Unknown"
}
