import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "omasys.task-manager"

  property real cpuPercent: 0
  property real memoryPercent: 0
  property real gpuPercent: -1
  property var previousCpu: null

  readonly property var installedManifest: bar && bar.shell && bar.shell.pluginRegistry
    ? bar.shell.pluginRegistry.installedPlugins[root.moduleName]
    : null
  readonly property string pluginDir: installedManifest && installedManifest.__sourceDir
    ? String(installedManifest.__sourceDir)
    : ""
  readonly property string displayText: vertical
    ? "C " + Math.round(cpuPercent) + "%\nR " + Math.round(memoryPercent) + "%\nG "
      + (gpuPercent >= 0 ? Math.round(gpuPercent) + "%" : "--")
    : "CPU " + Math.round(cpuPercent) + "%  ·  RAM " + Math.round(memoryPercent) + "%  ·  GPU "
      + (gpuPercent >= 0 ? Math.round(gpuPercent) + "%" : "N/A")

  function refresh() {
    if (root.pluginDir !== "" && !statsProc.running) statsProc.running = true
  }

  function applyStats(raw) {
    var parsed = Model.parseSystem(raw, root.previousCpu, null)
    if (!parsed.valid) return
    root.previousCpu = parsed.cpuSnapshot
    root.cpuPercent = parsed.cpuPercent
    root.memoryPercent = parsed.memoryPercent
    root.gpuPercent = parsed.gpuPercent
  }

  function toggleTaskManager() {
    if (root.bar && root.bar.shell)
      root.bar.shell.toggle(root.moduleName, "{}")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onPluginDirChanged: if (pluginDir !== "") refresh()
  Component.onCompleted: refresh()

  Timer {
    interval: 3000
    repeat: true
    running: root.visible
    onTriggered: root.refresh()
  }

  Process {
    id: statsProc
    command: root.pluginDir === "" ? [] : [root.pluginDir + "/scripts/collect-system.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStats(text)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    fixedHeight: root.vertical ? Style.bar.iconSlot * 3 : -1
    horizontalMargin: 8.75
    verticalPadding: 7
    tooltipText: "OmaSys task manager · right-click to refresh"
    active: root.cpuPercent >= 90 || root.memoryPercent >= 90 || root.gpuPercent >= 90
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.toggleTaskManager()
    }
  }
}
