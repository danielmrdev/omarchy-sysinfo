import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "daniel.sysinfo"

  property int cpu: 0
  property var cores: []
  property int mem: 0
  property int disk: 0
  property int temp: 0
  property int fan: 0
  property real ramUsedGb: 0
  property real ramTotalGb: 0
  property real diskUsed: 0
  property real diskTotal: 0

  // CPU color thresholds, overridable per-widget from shell.json settings.
  property int cpuWarn: Number(setting("cpuWarn", 60))
  property int cpuCrit: Number(setting("cpuCrit", 85))

  readonly property color barTextColor: root.bar ? root.bar.barForeground : Color.foreground

  readonly property color cpuColor: {
    if (root.cpu >= root.cpuCrit) return Color.urgent
    if (root.cpu >= root.cpuWarn) {
      var t = (root.cpu - root.cpuWarn) / Math.max(1, root.cpuCrit - root.cpuWarn)
      return Qt.rgba(
        root.barTextColor.r + (Color.urgent.r - root.barTextColor.r) * t,
        root.barTextColor.g + (Color.urgent.g - root.barTextColor.g) * t,
        root.barTextColor.b + (Color.urgent.b - root.barTextColor.b) * t,
        1)
    }
    return root.barTextColor
  }

  function refresh() {
    if (!infoProc.running) infoProc.running = true
  }

  function scriptPath() {
    var url = String(Qt.resolvedUrl("sysinfo.sh"))
    if (url.indexOf("file://") === 0) return url.substring(7)
    return url
  }

  function cpuTooltip() {
    var lines = ["CPU: " + root.cpu + "%"]
    for (var i = 0; i < root.cores.length; i++) lines.push("Core " + i + ": " + root.cores[i] + "%")
    return lines.join("\n")
  }

  // Outer separation from neighboring widgets (the bar's ModuleList uses
  // spacing 0, so each widget carries its own margin, like WidgetButton).
  // Match WidgetButton: each module contributes 8.5px per side.
  property real horizontalMargin: Style.spaceReal(8.5)

  implicitWidth: root.vertical
    ? metricsColumn.implicitWidth
    : metricsRow.implicitWidth + 2 * root.horizontalMargin
  implicitHeight: root.vertical ? metricsColumn.implicitHeight : metricsRow.implicitHeight

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: infoProc
    command: ["bash", root.scriptPath()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) return
        try {
          var info = JSON.parse(raw)
          root.cpu = info.cpu
          root.cores = info.cores
          root.mem = info.mem
          root.disk = info.disk
          root.temp = info.temp
          root.fan = info.fan
          root.ramUsedGb = info.ramUsedGb
          root.ramTotalGb = info.ramTotalGb
          root.diskUsed = info.diskUsed
          root.diskTotal = info.diskTotal
        } catch (error) {
          console.warn("daniel.sysinfo: bad JSON", raw)
        }
      }
    }
  }

  // Non-clickable metric: icon at bar icon size, value at clock text size,
  // tooltip routed through the bar host on hover.
  component Metric: Item {
    id: metric
    property var bar: null
    property var registeredBar: null
    property string iconText: ""
    property string valueText: ""
    property string tooltipText: ""
    property color iconColor: metric.bar ? metric.bar.barForeground : Color.foreground
    property color valueColor: metric.bar ? metric.bar.barForeground : Color.foreground
    readonly property bool tooltipHovered: visible && mouse.containsMouse

    function refreshTooltip() {
      if (!metric.bar || !metric.tooltipHovered) return
      if (metric.bar.tooltipTarget === metric) {
        metric.bar.tooltipText = metric.tooltipText
      } else {
        metric.bar.showTooltip(metric, metric.tooltipText)
      }
    }

    // The bar's modulePointer MouseArea sits on top of every module and
    // routes clicks to registered targets (cursor + click both come from
    // registration); hover passes through to this MouseArea because
    // modulePointer has hoverEnabled false.
    function syncClickRegistration() {
      if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(metric)
      registeredBar = metric.bar
      if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(metric)
    }

    function triggerPress(button) {
      if (metric.bar) metric.bar.run("omarchy-launch-or-focus-tui btop")
    }

    onBarChanged: syncClickRegistration()
    onTooltipTextChanged: refreshTooltip()
    Component.onCompleted: syncClickRegistration()
    Component.onDestruction: {
      if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(metric)
    }

    implicitWidth: row.implicitWidth
    // Fill the full bar height like other bar buttons (WidgetButton uses
    // barSize too); content is centered. Otherwise the slot shrinks to the
    // text height and sits top-aligned next to full-height neighbors.
    implicitHeight: !metric.bar || metric.bar.vertical ? row.implicitHeight : metric.bar.barSize

    Row {
      id: row
      anchors.centerIn: parent
      spacing: Style.spacing.lg

      Text {
        text: metric.iconText
        font.family: metric.bar ? metric.bar.fontFamily : Style.font.family
        font.pixelSize: Style.bar.iconFont
        color: metric.iconColor
        renderType: Text.NativeRendering
      }
      Text {
        text: metric.valueText
        font.family: metric.bar ? metric.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        color: metric.valueColor
        renderType: Text.NativeRendering
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: { if (metric.bar) metric.bar.showTooltip(metric, metric.tooltipText) }
      onExited: { if (metric.bar) metric.bar.hideTooltip(metric) }
    }
  }

  Row {
    id: metricsRow
    visible: !root.vertical
    spacing: Style.spacing.xl
    anchors.left: parent.left
    anchors.leftMargin: root.horizontalMargin

    Metric {
      bar: root.bar
      iconText: "󰍛"
      valueText: root.cpu + "%"
      valueColor: root.cpuColor
      tooltipText: root.cpuTooltip()
    }
    Metric {
      bar: root.bar
      iconText: "󰘚"
      valueText: root.mem + "%"
      tooltipText: "RAM: " + root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GB"
    }
    Metric {
      bar: root.bar
      iconText: "󰋊"
      valueText: root.disk + "%"
      tooltipText: "HD: " + root.diskUsed.toFixed(1) + " / " + root.diskTotal.toFixed(1) + " GiB"
    }
    Metric {
      bar: root.bar
      iconText: "󰔐"
      valueText: root.temp + "°C"
      tooltipText: "Temp: " + root.temp + "°C\nFan: " + root.fan + " RPM"
    }
  }

  Column {
    id: metricsColumn
    visible: root.vertical
    spacing: Style.spacing.xl
    anchors.left: parent.left
    anchors.leftMargin: root.horizontalMargin

    Metric {
      bar: root.bar
      iconText: "󰍛"
      valueText: root.cpu + "%"
      valueColor: root.cpuColor
      tooltipText: root.cpuTooltip()
    }
    Metric {
      bar: root.bar
      iconText: "󰘚"
      valueText: root.mem + "%"
      tooltipText: "RAM: " + root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GB"
    }
    Metric {
      bar: root.bar
      iconText: "󰋊"
      valueText: root.disk + "%"
      tooltipText: "HD: " + root.diskUsed.toFixed(1) + " / " + root.diskTotal.toFixed(1) + " GiB"
    }
    Metric {
      bar: root.bar
      iconText: "󰔐"
      valueText: root.temp + "°C"
      tooltipText: "Temp: " + root.temp + "°C\nFan: " + root.fan + " RPM"
    }
  }
}
