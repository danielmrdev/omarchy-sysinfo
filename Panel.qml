import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "danielmrdev.sysinfo"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var barIdentity: hostWidget || root
  // Keep in sync with manifest.json.
  readonly property string pluginVersion: "1.0.0"
  readonly property color foreground: Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var coreValues: hostWidget && hostWidget.dataAvailable && Array.isArray(hostWidget.cores) ? hostWidget.cores : []
  readonly property var volumes: hostWidget && hostWidget.dataAvailable && Array.isArray(hostWidget.storage) ? hostWidget.storage : []

  function open() {
    controller.show()
  }

  function close() {
    controller.hide()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  function openBtop() {
    close()
    Qt.callLater(function() {
      if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
    })
  }

  function formatVolume(volume) {
    if (!volume || !volume.available) return "Not available"
    return volume.usedGiB.toFixed(1) + " / " + volume.totalGiB.toFixed(1)
      + " GiB · " + volume.percent + "%"
  }

  function progressWidth(width, percent) {
    return width * Math.max(0, Math.min(100, Number(percent) || 0)) / 100
  }

  component SummaryBlock: Column {
    id: block
    required property string label
    required property string valueText
    property real progress: -1
    property color valueColor: root.foreground

    spacing: Style.space(5)

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: block.label
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: block.valueText
      color: block.valueColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
      elide: Text.ElideRight
    }

    Item {
      visible: block.progress >= 0
      width: parent.width
      height: visible ? Style.space(4) : 0

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Color.muted
      }
      Rectangle {
        width: root.progressWidth(parent.width, block.progress)
        height: parent.height
        radius: height / 2
        color: block.valueColor
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onActivateRequested: root.openBtop()
      onMoveRequested: function(dx, dy) {
        if (dx !== 0 || dy !== 0) btopButton.forceActiveFocus()
      }
      onTabRequested: function(direction) {
        if (!btopButton.activeFocus) btopButton.forceActiveFocus()
        else if (!root.switchPanel(direction)) keyCatcher.forceActiveFocus()
      }

      Flickable {
        id: contentScroll
        anchors.fill: parent
        contentWidth: contentColumn.width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: contentColumn
          width: contentScroll.width
          spacing: Style.space(14)

          Item {
            id: metricsHeader
            width: parent.width
            readonly property real cpuGlyphSize: Style.font.displayLarge + Style.space(4)
            readonly property real cpuGlyphOffset: Style.space(3)
            height: Math.max(cpuGlyph.implicitHeight + cpuGlyphOffset * 2, titleLabels.implicitHeight, btopButton.implicitHeight)

            Text {
              id: cpuGlyph
              textFormat: Text.PlainText
              text: "󰍛"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: metricsHeader.cpuGlyphSize
              anchors.left: parent.left
              anchors.top: titleLabels.top
              anchors.topMargin: metricsHeader.cpuGlyphOffset
            }

            Column {
              id: titleLabels
              anchors.left: cpuGlyph.right
              anchors.leftMargin: Style.space(14)
              anchors.right: btopButton.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Item {
                id: titleRow
                implicitWidth: titleText.implicitWidth + Style.space(8) + versionText.implicitWidth
                implicitHeight: Math.max(titleText.implicitHeight, versionText.implicitHeight)
                width: implicitWidth
                height: implicitHeight

                Text {
                  id: titleText
                  textFormat: Text.PlainText
                  text: "System info"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  id: versionText
                  textFormat: Text.PlainText
                  text: "v" + root.pluginVersion
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  anchors.left: titleText.right
                  anchors.leftMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Text {
                textFormat: Text.PlainText
                text: "LIVE SYSTEM METRICS"
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }
            }

            Button {
              id: btopButton
              anchors.right: parent.right
              anchors.top: titleLabels.top
              iconText: "󰆍"
              text: "btop"
              tooltipText: "Open btop"
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              iconSize: Style.font.icon
              focusable: true
              onClicked: root.openBtop()
            }
          }

          PanelSeparator { foreground: root.foreground }

          Row {
            width: parent.width
            spacing: Style.space(18)

            SummaryBlock {
              width: (parent.width - parent.spacing) / 2
              label: "CPU"
              valueText: root.hostWidget && root.hostWidget.dataAvailable ? root.hostWidget.cpu + "%" : "Not available"
              progress: root.hostWidget && root.hostWidget.dataAvailable ? root.hostWidget.cpu : -1
              valueColor: root.hostWidget && root.hostWidget.dataAvailable ? root.hostWidget.cpuColor : root.foreground
            }
            SummaryBlock {
              width: (parent.width - parent.spacing) / 2
              label: "MEMORY"
              valueText: root.hostWidget && root.hostWidget.dataAvailable
                ? root.hostWidget.ramUsedGb.toFixed(1) + " / " + root.hostWidget.ramTotalGb.toFixed(1) + " GiB · " + root.hostWidget.mem + "%"
                : "Not available"
              progress: root.hostWidget && root.hostWidget.dataAvailable ? root.hostWidget.mem : -1
              valueColor: root.foreground
            }
          }

          PanelSectionHeader {
            text: "CPU CORES"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Flow {
            id: coreFlow
            width: parent.width
            spacing: Style.space(8)
            height: childrenRect.height

            Repeater {
              model: root.coreValues

              delegate: Item {
                required property int index
                required property var modelData

                width: (coreFlow.width - coreFlow.spacing * 3) / 4
                height: coreContent.implicitHeight

                Column {
                  id: coreContent
                  width: parent.width
                  spacing: Style.space(4)

                  Row {
                    width: parent.width
                    spacing: Style.space(4)
                    Text {
                      id: coreName
                      textFormat: Text.PlainText
                      text: "C" + index
                      width: Style.space(22)
                      color: Qt.darker(root.foreground, 1.4)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                    Text {
                      textFormat: Text.PlainText
                      text: modelData + "%"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                      width: Math.max(1, parent.width - coreName.width - parent.spacing)
                    }
                  }

                  Item {
                    width: parent.width
                    height: Style.space(3)
                    Rectangle {
                      anchors.fill: parent
                      radius: height / 2
                      color: Color.muted
                    }
                    Rectangle {
                      width: root.progressWidth(parent.width, modelData)
                      height: parent.height
                      radius: height / 2
                      color: Color.accent
                    }
                  }
                }
              }
            }
          }

          Text {
            visible: root.coreValues.length === 0
            textFormat: Text.PlainText
            text: "Not available"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: "STORAGE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            id: storageList
            width: parent.width
            spacing: Style.space(12)

            Repeater {
              model: root.volumes

              delegate: Column {
                required property var modelData
                width: storageList.width
                spacing: Style.space(4)

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    id: mountName
                    textFormat: Text.PlainText
                    text: modelData.mount
                    width: parent.width * 0.48
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideMiddle
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: root.formatVolume(modelData)
                    width: Math.max(1, parent.width - mountName.width - parent.spacing)
                    color: modelData.available ? root.foreground : Qt.darker(root.foreground, 1.4)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                  }
                }

                Item {
                  visible: modelData.available
                  width: parent.width
                  height: Style.space(4)
                  Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Color.muted
                  }
                  Rectangle {
                    width: root.progressWidth(parent.width, modelData.percent)
                    height: parent.height
                    radius: height / 2
                    color: Color.accent
                  }
                }
              }
            }

          }

          Text {
            visible: root.volumes.length === 0
            textFormat: Text.PlainText
            text: "Not available"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: "THERMALS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(18)

            SummaryBlock {
              width: (parent.width - parent.spacing) / 2
              label: "TEMPERATURE"
              valueText: root.hostWidget && root.hostWidget.tempAvailable
                ? root.hostWidget.temp + "°C"
                : "Not available"
              valueColor: root.foreground
            }
            SummaryBlock {
              width: (parent.width - parent.spacing) / 2
              label: "FAN"
              valueText: root.hostWidget && root.hostWidget.fanAvailable
                ? root.hostWidget.fan + " RPM"
                : "Not available"
              valueColor: root.foreground
            }
          }
        }
      }
    }
  }
}
