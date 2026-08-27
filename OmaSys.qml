pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool paused: false
  property bool refreshInFlight: false
  property bool processRefreshInFlight: false

  property string filterText: ""
  property string sortKey: "cpu"
  property bool sortDescending: true
  property int selectedIndex: 0
  property int selectedPid: 0
  property var allProcesses: []

  property string pendingAction: ""
  property int pendingPid: 0
  property string pendingName: ""
  property bool confirmOpen: false
  property string actionMessage: ""
  property bool actionSucceeded: false
  property bool actionOutputReceived: false

  property real cpuPercent: 0
  property real memoryPercent: 0
  property real swapPercent: 0
  property real diskPercent: 0
  property real gpuPercent: -1
  property real temperatureC: -1
  property real load1: 0
  property real load5: 0
  property real load15: 0
  property int uptimeSeconds: 0
  property real memoryTotalKiB: 0
  property real memoryUsedKiB: 0
  property real swapTotalKiB: 0
  property real swapUsedKiB: 0
  property real diskTotalKiB: 0
  property real diskUsedKiB: 0
  property real networkRxPerSecond: 0
  property real networkTxPerSecond: 0
  property string hostname: ""
  property string kernel: ""
  property string distribution: "Linux"
  property string cpuModel: ""
  property int cpuThreads: 0
  property int currentUid: -1
  property var previousCpu: null
  property var previousNetwork: null
  property var previousProcessCpu: null

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "omasys.task-manager"
  readonly property string pluginDir: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color borderColor: Color.menu.border
  readonly property color scrim: Color.menu.scrim
  readonly property color selectedBackground: Color.menu.selectedBackground
  readonly property color selectedText: Color.menu.selectedText
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", borderColor, Math.max(1, Style.space(2)))
  readonly property string fontFamily: Style.font.menuFamily
  readonly property int contentMargin: Style.spacing.panelPadding
  readonly property int cardWidth: Math.min(Style.space(1220), overlayWindow.width - Style.gapsOut * 2)
  readonly property int cardHeight: Math.min(Style.space(780), overlayWindow.height - Style.gapsOut * 2)
  readonly property int rowHeight: Math.max(Style.space(42), Style.font.body + Style.spacing.rowPaddingX * 2)

  function open(payloadJson) {
    root.opened = true
    root.paused = false
    root.actionMessage = ""
    if (payloadJson) {
      try {
        var payload = JSON.parse(String(payloadJson))
        if (payload && typeof payload.filter === "string") root.filterText = payload.filter
        if (payload && ["cpu", "memory", "command", "pid", "user"].indexOf(payload.sort) !== -1)
          root.sortKey = payload.sort
      } catch (error) {
        // A malformed optional payload must never prevent the task manager opening.
      }
    }
    root.refreshAll()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.confirmOpen = false
    root.opened = false
    root.refreshInFlight = false
    root.processRefreshInFlight = false
    if (statsProc.running) statsProc.running = false
    if (processProc.running) processProc.running = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
    else root.close()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function refreshAll() {
    root.refreshStats()
    root.refreshProcesses()
  }

  function refreshStats() {
    if (!root.opened || root.pluginDir === "" || statsProc.running) return
    root.refreshInFlight = true
    statsProc.running = true
  }

  function refreshProcesses() {
    if (!root.opened || root.pluginDir === "" || processProc.running) return
    root.processRefreshInFlight = true
    processProc.running = true
  }

  function applyStats(raw) {
    var stats = Model.parseSystem(raw, root.previousCpu, root.previousNetwork)
    if (!stats.valid) {
      root.actionSucceeded = false
      root.actionMessage = "Could not parse system statistics"
      return
    }
    root.previousCpu = stats.cpuSnapshot
    root.previousNetwork = stats.networkSnapshot
    root.cpuPercent = stats.cpuPercent
    root.memoryPercent = stats.memoryPercent
    root.swapPercent = stats.swapPercent
    root.diskPercent = stats.diskPercent
    root.gpuPercent = stats.gpuPercent
    root.temperatureC = stats.temperatureC
    root.load1 = stats.load1
    root.load5 = stats.load5
    root.load15 = stats.load15
    root.uptimeSeconds = stats.uptimeSeconds
    root.memoryTotalKiB = stats.memoryTotalKiB
    root.memoryUsedKiB = stats.memoryUsedKiB
    root.swapTotalKiB = stats.swapTotalKiB
    root.swapUsedKiB = stats.swapUsedKiB
    root.diskTotalKiB = stats.diskTotalKiB
    root.diskUsedKiB = stats.diskUsedKiB
    root.networkRxPerSecond = stats.networkRxPerSecond
    root.networkTxPerSecond = stats.networkTxPerSecond
    root.hostname = stats.hostname
    root.kernel = stats.kernel
    root.distribution = stats.distribution
    root.cpuModel = stats.cpuModel
    root.cpuThreads = stats.cpuThreads
    root.currentUid = stats.currentUid
  }

  function applyProcesses(raw) {
    var sampled = Model.withLiveProcessCpu(Model.parseProcesses(raw), root.previousProcessCpu)
    root.previousProcessCpu = sampled.snapshot
    root.allProcesses = sampled.rows
    root.rebuildDisplay()
  }

  function rebuildDisplay() {
    var previousSelection = root.selectedPid
    var rows = Model.filteredAndSorted(root.allProcesses, root.filterText, root.sortKey, root.sortDescending)
    displayModel.clear()
    var nextIndex = -1
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]
      displayModel.append({
        pid: row.pid,
        ppid: row.ppid,
        uid: row.uid,
        user: row.user,
        processState: row.state,
        nice: row.nice,
        cpu: row.cpu,
        memory: row.memory,
        rssKiB: row.rssKiB,
        elapsedSeconds: row.elapsedSeconds,
        totalCpuSeconds: row.totalCpuSeconds,
        command: row.command,
        arguments: row.arguments
      })
      if (row.pid === previousSelection) nextIndex = i
    }

    if (displayModel.count === 0) {
      root.selectedIndex = 0
      root.selectedPid = 0
    } else {
      if (nextIndex < 0) nextIndex = Math.max(0, Math.min(root.selectedIndex, displayModel.count - 1))
      root.selectedIndex = nextIndex
      root.selectedPid = displayModel.get(nextIndex).pid
    }
    Qt.callLater(function() {
      if (displayModel.count > 0) processList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    })
  }

  function setFilter(value) {
    root.filterText = String(value || "")
    root.selectedIndex = 0
    root.selectedPid = 0
    root.rebuildDisplay()
  }

  function setSort(key) {
    if (root.sortKey === key) root.sortDescending = !root.sortDescending
    else {
      root.sortKey = key
      root.sortDescending = key !== "command" && key !== "user"
    }
    root.rebuildDisplay()
  }

  function sortMarker(key) {
    if (root.sortKey !== key) return ""
    return root.sortDescending ? " v" : " ^"
  }

  function selectIndex(index) {
    if (displayModel.count === 0) return
    root.selectedIndex = Math.max(0, Math.min(index, displayModel.count - 1))
    root.selectedPid = displayModel.get(root.selectedIndex).pid
    processList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function selectDelta(delta) {
    root.selectIndex(root.selectedIndex + delta)
  }

  function selectedProcess() {
    if (displayModel.count === 0 || root.selectedIndex < 0 || root.selectedIndex >= displayModel.count) return null
    return displayModel.get(root.selectedIndex)
  }

  function requestAction(action) {
    var process = root.selectedProcess()
    if (!process || actionProc.running) return
    if (process.pid <= 1) {
      root.actionSucceeded = false
      root.actionMessage = "PID 1 is protected and cannot be controlled by OmaSys"
      actionMessageTimer.restart()
      return
    }
    if (root.currentUid >= 0 && process.uid !== root.currentUid) {
      root.actionSucceeded = false
      root.actionMessage = "This process belongs to another user and cannot be controlled by OmaSys"
      actionMessageTimer.restart()
      return
    }
    root.pendingAction = action
    root.pendingPid = process.pid
    root.pendingName = process.command
    confirmDialog.selectedIndex = action === "kill" ? 0 : 1
    root.confirmOpen = true
  }

  function actionVerb(action) {
    if (action === "term") return "End"
    if (action === "kill") return "Force end"
    if (action === "stop") return "Suspend"
    if (action === "cont") return "Resume"
    return "Signal"
  }

  function confirmMessage() {
    var warning = root.pendingAction === "kill"
      ? " Unsaved data may be lost immediately."
      : (root.pendingAction === "term" ? " The process can shut down cleanly." : "")
    return root.actionVerb(root.pendingAction) + " “" + root.pendingName + "” (PID " + root.pendingPid + ")?" + warning
  }

  function cancelAction() {
    root.confirmOpen = false
    root.pendingAction = ""
    root.pendingPid = 0
    root.pendingName = ""
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmAction() {
    if (root.pendingPid <= 1 || root.pluginDir === "" || actionProc.running) {
      root.cancelAction()
      return
    }
    root.actionOutputReceived = false
    actionProc.command = [root.pluginDir + "/scripts/process-action.sh", root.pendingAction, String(root.pendingPid)]
    root.confirmOpen = false
    actionProc.running = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function applyActionOutput(raw) {
    var line = String(raw || "").trim()
    if (!line) return
    root.actionOutputReceived = true
    var fields = line.split("\t")
    root.actionSucceeded = fields[0] === "OK"
    root.actionMessage = fields.slice(1).join(" ") || line
    actionMessageTimer.restart()
  }

  function clearActionState() {
    root.pendingAction = ""
    root.pendingPid = 0
    root.pendingName = ""
    delayedProcessRefresh.restart()
  }

  ListModel { id: displayModel }

  Timer {
    interval: 2000
    repeat: true
    running: root.opened && !root.paused
    onTriggered: root.refreshAll()
  }

  Timer {
    id: delayedProcessRefresh
    interval: 350
    repeat: false
    onTriggered: root.refreshProcesses()
  }

  Timer {
    id: actionMessageTimer
    interval: 6000
    repeat: false
    onTriggered: root.actionMessage = ""
  }

  Process {
    id: statsProc
    command: root.pluginDir === "" ? [] : [root.pluginDir + "/scripts/collect-system.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStats(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message) {
          root.actionSucceeded = false
          root.actionMessage = message
        }
      }
    }
    onExited: root.refreshInFlight = false
  }

  Process {
    id: processProc
    command: root.pluginDir === "" ? [] : [root.pluginDir + "/scripts/list-processes.sh", "600"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyProcesses(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message) {
          root.actionSucceeded = false
          root.actionMessage = message
        }
      }
    }
    onExited: root.processRefreshInFlight = false
  }

  Process {
    id: actionProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyActionOutput(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message && !root.actionOutputReceived) {
          root.actionSucceeded = false
          root.actionMessage = message
        }
      }
    }
    onExited: function(exitCode) {
      if (!root.actionOutputReceived && exitCode !== 0) {
        root.actionSucceeded = false
        root.actionMessage = "The process action failed"
      }
      root.clearActionState()
    }
  }

  PanelWindow {
    id: overlayWindow
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omasys-task-manager"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      radius: Style.cornerRadius
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        z: root.confirmOpen ? 20 : 0
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.confirmOpen) {
            if (confirmDialog.handleKey(event)) event.accepted = true
            return
          }

          if (event.key === Qt.Key_Escape) {
            if (root.filterText !== "") root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_F5) {
            root.refreshAll()
            event.accepted = true
          } else if (event.key === Qt.Key_Space) {
            root.paused = !root.paused
            event.accepted = true
          } else if (event.key === Qt.Key_Delete) {
            root.requestAction((event.modifiers & Qt.ShiftModifier) ? "kill" : "term")
            event.accepted = true
          } else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_S) {
            root.requestAction("stop")
            event.accepted = true
          } else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_R) {
            root.requestAction("cont")
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.selectDelta(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.selectDelta(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.selectDelta(-10)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.selectDelta(10)
            event.accepted = true
          } else if (event.key === Qt.Key_Home) {
            root.selectIndex(0)
            event.accepted = true
          } else if (event.key === Qt.Key_End) {
            root.selectIndex(displayModel.count - 1)
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32
                     && event.text.charCodeAt(0) !== 127 && !(event.modifiers & Qt.AltModifier)
                     && !(event.modifiers & Qt.ControlModifier)) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }

        ConfirmDialog {
          id: confirmDialog
          anchors.fill: parent
          opened: root.confirmOpen
          z: 10
          message: root.confirmMessage()
          confirmText: root.actionVerb(root.pendingAction)
          background: root.background
          foreground: root.foreground
          scrim: root.scrim
          selectedBackground: root.selectedBackground
          selectedText: root.selectedText
          fontFamily: root.fontFamily
          cornerRadius: Style.cornerRadius
          onCanceled: root.cancelAction()
          onConfirmed: root.confirmAction()
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.space(10)

        Item {
          id: header
          width: parent.width
          height: Math.max(Style.space(54), headerTitle.implicitHeight + Style.space(8))

          Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              id: headerTitle
              text: "OmaSys  /  Task Manager"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              font.bold: true
            }

            Text {
              text: (root.hostname || "This computer") + "  ·  " + root.distribution + "  ·  kernel " + root.kernel
              color: Qt.darker(root.foreground, 1.45)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: Math.min(implicitWidth, card.width * 0.68)
            }
          }

          Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(330)
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: displayModel.count + " shown / " + root.allProcesses.length + " sampled"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignRight
            }

            Text {
              width: parent.width
              text: "Up " + Model.formatDuration(root.uptimeSeconds) + "  ·  F5 refresh  ·  Space pause"
              color: Qt.darker(root.foreground, 1.45)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
            }
          }
        }

        Row {
          id: metrics
          width: parent.width
          height: Style.space(98)
          spacing: Style.space(8)

          MetricCard {
            width: (metrics.width - metrics.spacing * 6) / 7
            label: "CPU"
            value: Math.round(root.cpuPercent) + "%"
            detail: root.load1.toFixed(2) + " load · " + root.cpuThreads + " threads"
            progress: root.cpuPercent / 100
            critical: root.cpuPercent >= 90
          }
          MetricCard {
            width: (metrics.width - metrics.spacing * 6) / 7
            label: "MEMORY"
            value: Math.round(root.memoryPercent) + "%"
            detail: Model.formatBytes(root.memoryUsedKiB * 1024) + " / " + Model.formatBytes(root.memoryTotalKiB * 1024)
            progress: root.memoryPercent / 100
            critical: root.memoryPercent >= 90
          }
          MetricCard {
            width: (metrics.width - metrics.spacing * 6) / 7
            label: "GPU"
            value: root.gpuPercent >= 0 ? Math.round(root.gpuPercent) + "%" : "N/A"
            detail: root.gpuPercent >= 0 ? "Busiest detected GPU" : "Driver has no usage API"
            progress: root.gpuPercent >= 0 ? root.gpuPercent / 100 : 0
            critical: root.gpuPercent >= 90
          }
          MetricCard {
            width: (metrics.width - metrics.spacing * 6) / 7
            label: "SWAP"
            value: root.swapTotalKiB > 0 ? Math.round(root.swapPercent) + "%" : "Off"
            detail: root.swapTotalKiB > 0
              ? Model.formatBytes(root.swapUsedKiB * 1024) + " / " + Model.formatBytes(root.swapTotalKiB * 1024)
              : "No swap configured"
            progress: root.swapPercent / 100
            critical: root.swapPercent >= 90
          }
          MetricCard {
            width: (metrics.width - metrics.spacing * 6) / 7
            label: "DISK /"
            value: Math.round(root.diskPercent) + "%"
            detail: Model.formatBytes(root.diskUsedKiB * 1024) + " / " + Model.formatBytes(root.diskTotalKiB * 1024)
            progress: root.diskPercent / 100
            critical: root.diskPercent >= 90
          }
          MetricCard {
            width: (metrics.width - metrics.spacing * 6) / 7
            label: "NETWORK"
            value: "D " + Model.formatRate(root.networkRxPerSecond)
            detail: "U " + Model.formatRate(root.networkTxPerSecond)
            progress: 0
            critical: false
          }
          MetricCard {
            width: (metrics.width - metrics.spacing * 6) / 7
            label: "TEMPERATURE"
            value: root.temperatureC >= 0 ? Math.round(root.temperatureC) + "°C" : "N/A"
            detail: "Load " + root.load1.toFixed(2) + " / " + root.load5.toFixed(2) + " / " + root.load15.toFixed(2)
            progress: root.temperatureC >= 0 ? Math.min(1, root.temperatureC / 100) : 0
            critical: root.temperatureC >= 90
          }
        }

        Row {
          id: toolbar
          width: parent.width
          height: Math.max(Style.space(38), searchSurface.implicitHeight)
          spacing: Style.space(8)

          BorderSurface {
            id: searchSurface
            width: Math.max(Style.space(280), toolbar.width - sortButtons.width - toolbar.spacing)
            height: toolbar.height
            color: Style.normalFillFor(root.foreground, root.accent)
            borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
            radius: Style.cornerRadius

            Text {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              text: root.filterText === "" ? "Type to search PID, user, command, or arguments..." : root.filterText
              color: root.filterText === "" ? Qt.darker(root.foreground, 1.6) : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onClicked: keyCatcher.forceActiveFocus()
            }
          }

          Row {
            id: sortButtons
            height: parent.height
            spacing: Style.space(4)

            Button {
              height: parent.height
              text: "CPU" + root.sortMarker("cpu")
              selected: root.sortKey === "cpu"
              foreground: root.foreground
              onClicked: root.setSort("cpu")
            }
            Button {
              height: parent.height
              text: "Memory" + root.sortMarker("memory")
              selected: root.sortKey === "memory"
              foreground: root.foreground
              onClicked: root.setSort("memory")
            }
            Button {
              height: parent.height
              text: "Name" + root.sortMarker("command")
              selected: root.sortKey === "command"
              foreground: root.foreground
              onClicked: root.setSort("command")
            }
            Button {
              height: parent.height
              text: "PID" + root.sortMarker("pid")
              selected: root.sortKey === "pid"
              foreground: root.foreground
              onClicked: root.setSort("pid")
            }
            Button {
              height: parent.height
              text: root.paused ? "Resume updates" : "Pause"
              foreground: root.foreground
              active: root.paused
              onClicked: root.paused = !root.paused
            }
            Button {
              height: parent.height
              text: "Refresh"
              foreground: root.foreground
              iconSpinning: root.refreshInFlight || root.processRefreshInFlight
              onClicked: root.refreshAll()
            }
          }
        }

        BorderSurface {
          id: tableHeader
          width: parent.width
          height: Style.space(34)
          color: Style.normalFillFor(root.foreground, root.accent)
          borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
          radius: Style.cornerRadius

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)

            TableHeaderCell { width: Style.space(72); text: "PID"; align: Text.AlignRight }
            TableHeaderCell { width: Style.space(106); text: "USER" }
            TableHeaderCell { width: Style.space(68); text: "CPU %"; align: Text.AlignRight }
            TableHeaderCell { width: Style.space(68); text: "MEM %"; align: Text.AlignRight }
            TableHeaderCell { width: Style.space(90); text: "RESIDENT"; align: Text.AlignRight }
            TableHeaderCell { width: Style.space(86); text: "STATE" }
            TableHeaderCell { width: Style.space(82); text: "AGE"; align: Text.AlignRight }
            TableHeaderCell {
              width: parent.width - Style.space(566)
              text: "COMMAND"
            }
          }
        }

        Item {
          id: processArea
          width: parent.width
          height: Math.max(Style.space(160), parent.height - header.height - metrics.height - toolbar.height
            - tableHeader.height - footer.height - parent.spacing * 5)
          clip: true

          ListView {
            id: processList
            anchors.fill: parent
            model: displayModel
            clip: true
            spacing: Style.space(2)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              id: processRow
              required property int index
              required property int pid
              required property int ppid
              required property int uid
              required property string user
              required property string processState
              required property int nice
              required property real cpu
              required property real memory
              required property real rssKiB
              required property real elapsedSeconds
              required property real totalCpuSeconds
              required property string command
              required property string arguments

              readonly property bool selected: index === root.selectedIndex

              width: ListView.view.width
              height: root.rowHeight
              radius: Style.cornerRadius
              color: selected ? root.selectedBackground : (rowMouse.containsMouse
                ? Style.hoverFillFor(root.foreground, root.accent)
                : "transparent")

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)

                TableCell { width: Style.space(72); text: String(processRow.pid); align: Text.AlignRight; selected: processRow.selected }
                TableCell { width: Style.space(106); text: processRow.user; selected: processRow.selected }
                TableCell { width: Style.space(68); text: processRow.cpu.toFixed(1); align: Text.AlignRight; selected: processRow.selected; hot: processRow.cpu >= 75 }
                TableCell { width: Style.space(68); text: processRow.memory.toFixed(1); align: Text.AlignRight; selected: processRow.selected; hot: processRow.memory >= 75 }
                TableCell { width: Style.space(90); text: Model.formatBytes(processRow.rssKiB * 1024); align: Text.AlignRight; selected: processRow.selected }
                TableCell { width: Style.space(86); text: Model.stateLabel(processRow.processState); selected: processRow.selected }
                TableCell { width: Style.space(82); text: Model.formatDuration(processRow.elapsedSeconds); align: Text.AlignRight; selected: processRow.selected }
                TableCell {
                  width: parent.width - Style.space(566)
                  text: processRow.command + (processRow.arguments !== processRow.command ? "  " + processRow.arguments : "")
                  selected: processRow.selected
                }
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                  root.selectIndex(processRow.index)
                  if (mouse.button === Qt.RightButton) root.requestAction("term")
                  keyCatcher.forceActiveFocus()
                }
                onDoubleClicked: {
                  root.selectIndex(processRow.index)
                  root.requestAction("term")
                }
              }
            }
          }

          Text {
            anchors.centerIn: parent
            width: parent.width
            height: Style.space(80)
            z: 100
            text: displayModel.count === 0
              ? (root.filterText === ""
                  ? "No processes returned\nCheck the collector output or refresh."
                  : "No process matches “" + root.filterText + "”\nPress Escape to clear the search.")
              : ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            lineHeight: 1.6
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
        }

        BorderSurface {
          id: footer
          width: parent.width
          height: Style.space(66)
          color: Style.normalFillFor(root.foreground, root.accent)
          borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
          radius: Style.cornerRadius

          property var process: root.selectedProcess()

          Column {
            anchors.left: parent.left
            anchors.right: actionButtons.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(3)

            Text {
              width: parent.width
              text: footer.process
                ? footer.process.command + "  ·  PID " + footer.process.pid + "  ·  PPID " + footer.process.ppid + "  ·  nice " + footer.process.nice
                : "Select a process"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: root.actionMessage !== ""
                ? root.actionMessage
                : (footer.process
                  ? ((root.currentUid >= 0 && footer.process.uid !== root.currentUid ? "Read-only system process  ·  " : "") + footer.process.arguments)
                  : "Process actions never request sudo and are limited to your own processes.")
              color: root.actionMessage !== ""
                ? (root.actionSucceeded ? root.accent : root.urgent)
                : Qt.darker(root.foreground, 1.45)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideMiddle
            }
          }

          Row {
            id: actionButtons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(4)

            Button {
              text: "Suspend"
              foreground: root.foreground
              enabled: footer.process !== null && footer.process.pid > 1 && footer.process.uid === root.currentUid && !actionProc.running
              tooltipText: "Send SIGSTOP · Alt+S"
              onClicked: root.requestAction("stop")
            }
            Button {
              text: "Resume"
              foreground: root.foreground
              enabled: footer.process !== null && footer.process.pid > 1 && footer.process.uid === root.currentUid && !actionProc.running
              tooltipText: "Send SIGCONT · Alt+R"
              onClicked: root.requestAction("cont")
            }
            Button {
              text: "End task"
              foreground: root.foreground
              enabled: footer.process !== null && footer.process.pid > 1 && footer.process.uid === root.currentUid && !actionProc.running
              tooltipText: "Request a clean exit with SIGTERM · Delete"
              onClicked: root.requestAction("term")
            }
            Button {
              text: "Force end"
              foreground: root.urgent
              accent: root.urgent
              bordered: true
              enabled: footer.process !== null && footer.process.pid > 1 && footer.process.uid === root.currentUid && !actionProc.running
              tooltipText: "Immediately send SIGKILL · Shift+Delete"
              onClicked: root.requestAction("kill")
            }
          }
        }
      }
    }
  }

  component MetricCard: BorderSurface {
    id: metric
    property string label: ""
    property string value: ""
    property string detail: ""
    property real progress: 0
    property bool critical: false

    height: metrics.height
    color: Style.normalFillFor(root.foreground, root.accent)
    borderSpec: Border.controlSpec("normal", root.foreground, root.accent)
    radius: Style.cornerRadius

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(4)

      Text {
        width: parent.width
        text: metric.label
        color: Qt.darker(root.foreground, 1.45)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: metric.value
        color: metric.critical ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: metric.label === "NETWORK" ? Style.font.subtitle : Style.font.heading
        font.bold: true
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: metric.detail
        color: Qt.darker(root.foreground, 1.45)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Rectangle {
        width: parent.width
        height: Style.space(3)
        radius: height / 2
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, metric.progress))
          height: parent.height
          radius: parent.radius
          color: metric.critical ? root.urgent : root.accent
        }
      }
    }
  }

  component TableHeaderCell: Item {
    property string text: ""
    property int align: Text.AlignLeft

    height: parent.height
    Text {
      anchors.fill: parent
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      text: parent.text
      color: Qt.darker(root.foreground, 1.35)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: parent.align
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
  }

  component TableCell: Item {
    property string text: ""
    property int align: Text.AlignLeft
    property bool selected: false
    property bool hot: false

    height: parent.height
    Text {
      anchors.fill: parent
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      text: parent.text
      color: parent.hot ? root.urgent : (parent.selected ? root.selectedText : root.foreground)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: parent.align
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
  }
}
