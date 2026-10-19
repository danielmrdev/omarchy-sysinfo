import QtQuick
import qs.Commons
import qs.Ui
import "i18n.js" as I18n

Panel {
  id: root
  moduleName: "danielmrdev.sysinfo"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property var barIdentity: hostWidget || root
  // Keep in sync with manifest.json.
  readonly property string pluginVersion: "1.1.0"
  readonly property string pluginAuthor: "Daniel"
  readonly property string projectUrl: "https://github.com/danielmrdev/omarchy-sysinfo"
  readonly property string changelogUrl: root.projectUrl + "/blob/main/CHANGELOG.md"
  readonly property string marketplaceUrl: "https://plugins.omarchy.org/plugin.html?id=danielmrdev.sysinfo"
  readonly property string issueUrl: root.projectUrl + "/issues/new"
  property string viewMode: "metrics"
  readonly property string systemLanguage: {
    var locale = Qt.locale()
    var preferred = locale && locale.uiLanguages ? locale.uiLanguages : []
    return I18n.resolveLanguage(locale && locale.name ? String(locale.name) : "", preferred)
  }
  readonly property string uiLanguage: hostWidget && typeof hostWidget.uiLanguage === "string"
    ? I18n.normalizeOverride(hostWidget.uiLanguage)
    : "system"
  readonly property color foreground: Color.popups.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var coreValues: hostWidget && hostWidget.dataAvailable && Array.isArray(hostWidget.cores) ? hostWidget.cores : []
  readonly property var volumes: hostWidget && hostWidget.dataAvailable && Array.isArray(hostWidget.storage) ? hostWidget.storage : []

  function tr(key) {
    return I18n.t(key, root.systemLanguage, root.uiLanguage)
  }

  function setUiLanguage(language) {
    if (hostWidget && typeof hostWidget.setUiLanguage === "function")
      hostWidget.setUiLanguage(language)
  }

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

  function showAbout() {
    root.viewMode = "about"
    contentScroll.contentY = 0
    Qt.callLater(function() { if (root.opened) backButton.forceActiveFocus() })
  }

  function showMetrics() {
    root.viewMode = "metrics"
    contentScroll.contentY = 0
    Qt.callLater(function() { if (root.opened) aboutButton.forceActiveFocus() })
  }

  function focusControl(control) {
    control.forceActiveFocus()
    var position = control.mapToItem(contentScroll.contentItem, 0, 0)
    if (position.y < contentScroll.contentY)
      contentScroll.contentY = position.y
    else if (position.y + control.height > contentScroll.contentY + contentScroll.height)
      contentScroll.contentY = position.y + control.height - contentScroll.height
  }

  function focusPageControl(direction, allowPanelSwitch) {
    var controls = root.viewMode === "about"
      ? [backButton, changelogButton, marketplaceButton, issueButton, githubButton,
        languageSystemButton, languageEnglishButton, languageSpanishButton]
      : [btopButton, aboutButton]
    var currentIndex = -1
    for (var i = 0; i < controls.length; i++) {
      if (controls[i].activeFocus) { currentIndex = i; break }
    }
    if (currentIndex < 0) {
      root.focusControl(controls[direction < 0 ? controls.length - 1 : 0])
      return
    }
    var nextIndex = currentIndex + (direction < 0 ? -1 : 1)
    if (nextIndex >= 0 && nextIndex < controls.length) {
      root.focusControl(controls[nextIndex])
      return
    }
    if (allowPanelSwitch && root.switchPanel(direction)) return
    if (allowPanelSwitch) keyCatcher.forceActiveFocus()
  }

  function activateFocusedControl() {
    if (root.viewMode === "about") {
      if (backButton.activeFocus) { root.showMetrics(); return }
      if (changelogButton.activeFocus) { Qt.openUrlExternally(root.changelogUrl); return }
      if (marketplaceButton.activeFocus) { Qt.openUrlExternally(root.marketplaceUrl); return }
      if (issueButton.activeFocus) { Qt.openUrlExternally(root.issueUrl); return }
      if (githubButton.activeFocus) { Qt.openUrlExternally(root.projectUrl); return }
      if (languageSystemButton.activeFocus) { root.setUiLanguage("system"); return }
      if (languageEnglishButton.activeFocus) { root.setUiLanguage("en"); return }
      if (languageSpanishButton.activeFocus) { root.setUiLanguage("es"); return }
    } else if (aboutButton.activeFocus) {
      root.showAbout()
      return
    }
    root.openBtop()
  }

  function formatVolume(volume) {
    if (!volume || !volume.available) return root.tr("unavailable")
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
    contentHeight: panel.fittedContentHeight(root.viewMode === "about" ? aboutColumn.implicitHeight : contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onCloseRequested: root.close()
      onActivateRequested: root.activateFocusedControl()
      onMoveRequested: function(dx, dy) {
        if (dx !== 0 || dy !== 0) root.focusPageControl(dx !== 0 ? dx : dy, false)
      }
      onTabRequested: function(direction) { root.focusPageControl(direction, true) }

      Flickable {
        id: contentScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: root.viewMode === "about" ? aboutColumn.implicitHeight : contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: contentColumn
          width: contentScroll.width
          spacing: Style.space(14)
          visible: root.viewMode === "metrics"

          Item {
            id: metricsHeader
            width: parent.width
            readonly property real cpuGlyphSize: Style.font.displayLarge + Style.space(4)
            readonly property real cpuGlyphOffset: Style.space(3)
            height: Math.max(cpuGlyph.implicitHeight + cpuGlyphOffset * 2, titleLabels.implicitHeight, btopButton.implicitHeight, aboutButton.implicitHeight)

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

              Text {
                id: titleText
                textFormat: Text.PlainText
                width: parent.width
                text: root.tr("title")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                textFormat: Text.PlainText
                text: root.tr("metricsSubtitle")
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }
            }

            Button {
              id: btopButton
              anchors.right: aboutButton.left
              anchors.rightMargin: Style.space(4)
              anchors.top: titleLabels.top
              iconText: "󰆍"
              text: "btop"
              tooltipText: root.tr("openBtop")
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              iconSize: Style.font.icon
              focusable: true
              onClicked: root.openBtop()
            }

            Button {
              id: aboutButton
              anchors.right: parent.right
              anchors.top: titleLabels.top
              text: root.tr("about")
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              focusable: true
              onClicked: root.showAbout()
            }
          }

          PanelSeparator { foreground: root.foreground }

          Row {
            width: parent.width
            spacing: Style.space(18)

            SummaryBlock {
              width: (parent.width - parent.spacing) / 2
              label: root.tr("cpu")
              valueText: root.hostWidget && root.hostWidget.dataAvailable ? root.hostWidget.cpu + "%" : root.tr("unavailable")
              progress: root.hostWidget && root.hostWidget.dataAvailable ? root.hostWidget.cpu : -1
              valueColor: root.hostWidget && root.hostWidget.dataAvailable ? root.hostWidget.cpuColor : root.foreground
            }
            SummaryBlock {
              width: (parent.width - parent.spacing) / 2
              label: root.tr("memory")
              valueText: root.hostWidget && root.hostWidget.dataAvailable
                ? root.hostWidget.ramUsedGb.toFixed(1) + " / " + root.hostWidget.ramTotalGb.toFixed(1) + " GiB · " + root.hostWidget.mem + "%"
                : root.tr("unavailable")
              progress: root.hostWidget && root.hostWidget.dataAvailable ? root.hostWidget.mem : -1
              valueColor: root.foreground
            }
          }

          PanelSectionHeader {
            text: root.tr("cpuCores")
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
            text: root.tr("unavailable")
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: root.tr("storage")
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
            text: root.tr("unavailable")
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: root.tr("thermals")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(18)

            SummaryBlock {
              width: (parent.width - parent.spacing) / 2
              label: root.tr("temperature")
              valueText: root.hostWidget && root.hostWidget.tempAvailable
                ? root.hostWidget.temp + "°C"
                : root.tr("unavailable")
              valueColor: root.foreground
            }
            SummaryBlock {
              width: (parent.width - parent.spacing) / 2
              label: root.tr("fan")
              valueText: root.hostWidget && root.hostWidget.fanAvailable
                ? root.hostWidget.fan + " RPM"
                : root.tr("unavailable")
              valueColor: root.foreground
            }
          }
        }

        Column {
          id: aboutColumn
          width: contentScroll.width
          spacing: Style.space(14)
          visible: root.viewMode === "about"

          Row {
            width: parent.width

            Button {
              id: backButton
              text: root.tr("metrics")
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              focusable: true
              onClicked: root.showMetrics()
            }
          }

          PanelHero {
            width: parent.width
            title: root.tr("title")
            detail: "v" + root.pluginVersion
            meta: root.tr("aboutDeveloper") + " · " + root.pluginAuthor
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: "󰍛"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: root.tr("aboutLinks").toUpperCase()
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(4)

              Button {
                id: changelogButton
                width: parent.width
                text: root.tr("aboutChangelog")
                iconText: "\uf15c"
                bordered: true
                leftAlign: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.body
                verticalPadding: Style.space(6)
                horizontalPadding: Style.space(10)
                focusable: true
                onClicked: Qt.openUrlExternally(root.changelogUrl)
              }
              Button {
                id: marketplaceButton
                width: parent.width
                text: root.tr("aboutMarketplace")
                iconText: "\uf07a"
                bordered: true
                leftAlign: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.body
                verticalPadding: Style.space(6)
                horizontalPadding: Style.space(10)
                focusable: true
                onClicked: Qt.openUrlExternally(root.marketplaceUrl)
              }
              Button {
                id: issueButton
                width: parent.width
                text: root.tr("aboutIssue")
                iconText: "\uf071"
                bordered: true
                leftAlign: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.body
                verticalPadding: Style.space(6)
                horizontalPadding: Style.space(10)
                focusable: true
                onClicked: Qt.openUrlExternally(root.issueUrl)
              }
              Button {
                id: githubButton
                width: parent.width
                text: root.tr("aboutGithub")
                iconText: "\uf09b"
                bordered: true
                leftAlign: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.body
                verticalPadding: Style.space(6)
                horizontalPadding: Style.space(10)
                focusable: true
                onClicked: Qt.openUrlExternally(root.projectUrl)
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: root.tr("uiLanguage").toUpperCase()
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(4)

              Button {
                id: languageSystemButton
                text: root.tr("uiLanguageSystem")
                selected: root.uiLanguage === "system"
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.space(2)
                horizontalPadding: Style.space(8)
                focusable: true
                onClicked: root.setUiLanguage("system")
              }
              Button {
                id: languageEnglishButton
                text: root.tr("uiLanguageEn")
                selected: root.uiLanguage === "en"
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.space(2)
                horizontalPadding: Style.space(8)
                focusable: true
                onClicked: root.setUiLanguage("en")
              }
              Button {
                id: languageSpanishButton
                text: root.tr("uiLanguageEs")
                selected: root.uiLanguage === "es"
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.space(2)
                horizontalPadding: Style.space(8)
                focusable: true
                onClicked: root.setUiLanguage("es")
              }
            }
          }
        }
      }
    }
  }
}
