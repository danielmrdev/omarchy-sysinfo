import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "i18n.js" as I18n

BarWidget {
  id: root
  moduleName: "danielmrdev.sysinfo"

  readonly property string activeLanguage: {
    var locale = Qt.locale()
    var preferred = locale && locale.uiLanguages ? locale.uiLanguages : []
    return I18n.resolveLanguage(locale && locale.name ? String(locale.name) : "", preferred)
  }
  readonly property string uiLanguage: I18n.normalizeOverride(setting("uiLanguage", "system"))

  function tr(key) {
    return I18n.t(key, root.activeLanguage, root.uiLanguage)
  }

  function persistSetting(key, value) {
    var entry = { id: root.moduleName }
    var current = root.settings || {}
    for (var name in current) if (name !== "id") entry[name] = current[name]
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setUiLanguage(language) {
    persistSetting("uiLanguage", I18n.normalizeOverride(language))
  }

  property bool dataAvailable: false
  property int cpu: 0
  property var cores: []
  property int mem: 0
  property int disk: 0
  property bool diskAvailable: false
  property int temp: 0
  property bool tempAvailable: false
  property int fan: 0
  property bool fanAvailable: false
  property real ramUsedGb: 0
  property real ramTotalGb: 0
  property real diskUsed: 0
  property real diskTotal: 0
  property var storage: []

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

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false
  readonly property real openPanelIndicatorWidth: metricButton.width
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  property real horizontalMargin: Style.spaceReal(8.5)

  Text {
    id: maximumCpuLabel
    visible: false
    textFormat: Text.PlainText
    text: "100%"
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    renderType: Text.NativeRendering
  }

  implicitWidth: metricButton.implicitWidth + 2 * root.horizontalMargin
  implicitHeight: root.vertical ? metricButton.implicitHeight : (root.bar ? root.bar.barSize : metricButton.implicitHeight)

  function finiteNumber(value) {
    return typeof value === "number" && isFinite(value)
  }

  function clampPercent(value) {
    return Math.max(0, Math.min(100, Math.round(Number(value) || 0)))
  }

  function refresh() {
    if (!infoProc.running) infoProc.running = true
  }

  function markUnavailable() {
    dataAvailable = false
    cpu = 0
    cores = []
    mem = 0
    disk = 0
    diskAvailable = false
    temp = 0
    tempAvailable = false
    fan = 0
    fanAvailable = false
    ramUsedGb = 0
    ramTotalGb = 0
    diskUsed = 0
    diskTotal = 0
    storage = []
    metricButton.refreshTooltip()
  }

  function scriptPath() {
    var url = String(Qt.resolvedUrl("sysinfo.sh"))
    if (url.indexOf("file://") === 0) return url.substring(7)
    return url
  }

  function tooltipSummary() {
    var unavailable = root.tr("unavailable")
    var cpuText = root.dataAvailable ? root.cpu + "%" : unavailable
    var ram = root.dataAvailable
      ? root.ramUsedGb.toFixed(1) + " / " + root.ramTotalGb.toFixed(1) + " GiB (" + root.mem + "%)"
      : unavailable
    var diskText = root.dataAvailable && root.diskAvailable
      ? root.diskUsed.toFixed(1) + " / " + root.diskTotal.toFixed(1) + " GiB (" + root.disk + "%)"
      : unavailable
    var temperature = root.dataAvailable && root.tempAvailable ? root.temp + "°C" : unavailable
    var fanSpeed = root.dataAvailable && root.fanAvailable ? root.fan + " RPM" : unavailable
    return root.tr("title") + " - " + root.tr("cpu") + ": " + cpuText
      + "\n" + root.tr("tooltipRam") + ": " + ram
      + "\n" + root.tr("tooltipDisk") + ": " + diskText
      + "\n" + root.tr("thermals") + ": " + root.tr("tooltipTemp") + " " + temperature
      + " · " + root.tr("fan") + " " + fanSpeed
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("anchorItem" in target) target.anchorItem = metricButton
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch)
      panelLoader.item.closeForPopoutSwitch()
  }

  // All live details move into Panel.qml; the bar tooltip stays a four-metric summary.
  component Metric: Item {
    id: metric
    property var bar: null
    property var registeredBar: null
    property string iconText: ""
    property string valueText: ""
    property real valueSlotWidth: 0
    property string tooltipText: ""
    readonly property bool tooltipHovered: visible && mouse.containsMouse
    property color iconColor: metric.bar ? metric.bar.barForeground : Color.foreground
    property color valueColor: metric.bar ? metric.bar.barForeground : Color.foreground

    function syncClickRegistration() {
      if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(metric)
      registeredBar = metric.bar
      if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(metric)
    }

    function triggerPress(button) {
      if (button === Qt.LeftButton) root.togglePanel()
    }

    function refreshTooltip() {
      if (!metric.bar || !mouse.containsMouse) return
      if (metric.bar.tooltipTarget === metric)
        metric.bar.tooltipText = metric.tooltipText
      else
        metric.bar.showTooltip(metric, metric.tooltipText)
    }

    onBarChanged: syncClickRegistration()
    Component.onCompleted: syncClickRegistration()
    Component.onDestruction: {
      if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(metric)
    }

    readonly property real contentWidth: iconLabel.implicitWidth + row.spacing
      + Math.max(metric.valueSlotWidth, valueLabel.implicitWidth)

    implicitWidth: contentWidth
    implicitHeight: !metric.bar || metric.bar.vertical ? row.implicitHeight : metric.bar.barSize

    Row {
      id: row
      anchors.centerIn: parent
      spacing: Style.spacing.lg

      Text {
        id: iconLabel
        textFormat: Text.PlainText
        text: metric.iconText
        font.family: metric.bar ? metric.bar.fontFamily : Style.font.family
        font.pixelSize: Style.bar.iconFont
        color: metric.iconColor
        renderType: Text.NativeRendering
      }
      Text {
        id: valueLabel
        textFormat: Text.PlainText
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

  Metric {
    id: metricButton
    anchors.left: parent.left
    anchors.leftMargin: root.horizontalMargin
    anchors.verticalCenter: parent.verticalCenter
    width: implicitWidth
    height: implicitHeight
    bar: root.bar
    iconText: "󰍛"
    valueText: root.dataAvailable ? root.cpu + "%" : "—"
    valueSlotWidth: maximumCpuLabel.implicitWidth
    valueColor: root.cpuColor
    tooltipText: root.tooltipSummary()
  }

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
        if (!raw) {
          root.markUnavailable()
          return
        }
        try {
          var info = JSON.parse(raw)
          if (!root.finiteNumber(info.cpu) || !root.finiteNumber(info.mem))
            throw new Error("missing CPU or memory value")

          root.cpu = root.clampPercent(info.cpu)
          root.mem = root.clampPercent(info.mem)

          var nextCores = []
          if (Array.isArray(info.cores)) {
            for (var i = 0; i < info.cores.length; i++) {
              if (root.finiteNumber(info.cores[i])) nextCores.push(root.clampPercent(info.cores[i]))
            }
          }
          root.cores = nextCores
          root.ramUsedGb = root.finiteNumber(info.ramUsedGb) ? Math.max(0, info.ramUsedGb) : 0
          root.ramTotalGb = root.finiteNumber(info.ramTotalGb) ? Math.max(0, info.ramTotalGb) : 0
          root.tempAvailable = info.tempAvailable === true && root.finiteNumber(info.temp)
          root.temp = root.tempAvailable ? Math.max(0, Math.round(info.temp)) : 0
          root.fanAvailable = info.fanAvailable === true && root.finiteNumber(info.fan)
          root.fan = root.fanAvailable ? Math.max(0, Math.round(info.fan)) : 0

          var nextStorage = []
          if (Array.isArray(info.storage)) {
            for (var j = 0; j < info.storage.length; j++) {
              var volume = info.storage[j]
              if (!volume || typeof volume.mount !== "string") continue
              var available = volume.available === true
              nextStorage.push({
                mount: volume.mount,
                available: available,
                usedGiB: available && root.finiteNumber(volume.usedGiB) ? Math.max(0, volume.usedGiB) : 0,
                totalGiB: available && root.finiteNumber(volume.totalGiB) ? Math.max(0, volume.totalGiB) : 0,
                percent: available && root.finiteNumber(volume.percent) ? root.clampPercent(volume.percent) : 0
              })
            }
          }
          root.storage = nextStorage
          var rootVolume = null
          for (var k = 0; k < nextStorage.length; k++) {
            if (nextStorage[k].mount === "/") { rootVolume = nextStorage[k]; break }
          }
          root.diskAvailable = !!rootVolume && rootVolume.available
          root.disk = root.diskAvailable ? rootVolume.percent : 0
          root.diskUsed = root.diskAvailable ? rootVolume.usedGiB : 0
          root.diskTotal = root.diskAvailable ? rootVolume.totalGiB : 0
          root.dataAvailable = true
          metricButton.refreshTooltip()
        } catch (error) {
          console.warn("danielmrdev.sysinfo: invalid system metrics JSON")
          root.markUnavailable()
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message) console.warn("danielmrdev.sysinfo: collector stderr", message)
      }
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0) {
        console.warn("danielmrdev.sysinfo: collector exited", exitCode, exitStatus)
        root.markUnavailable()
      }
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  onBarChanged: Qt.callLater(injectPanel)
  onUiLanguageChanged: metricButton.refreshTooltip()
  Component.onCompleted: Qt.callLater(injectPanel)
}
