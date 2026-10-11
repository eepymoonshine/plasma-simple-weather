/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: compact

    readonly property string fontFamily: Plasmoid.configuration.panelFontFamily || Kirigami.Theme.defaultFont.family
    readonly property real fontSize: Plasmoid.configuration.panelFontSize > 0
        ? Plasmoid.configuration.panelFontSize : Kirigami.Theme.defaultFont.pointSize
    readonly property int fontWeight: Plasmoid.configuration.panelFontWeight || Font.Bold
    readonly property bool fontItalic: Plasmoid.configuration.panelFontItalic === true

    Layout.minimumWidth: row.implicitWidth + Kirigami.Units.largeSpacing * 2
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: root.isVertical ? row.implicitHeight + Kirigami.Units.largeSpacing * 2 : Kirigami.Units.iconSizes.medium
    Layout.preferredHeight: root.isVertical ? Layout.minimumHeight : -1

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) root.refresh()
            else root.expanded = !root.expanded
        }
    }

    GridLayout {
        id: row
        anchors.centerIn: parent
        flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        columns: root.isVertical ? 1 : -1
        rows: root.isVertical ? -1 : 1
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: 0

        // Center the digits in the panel. Centering the line box instead leaves them about
        // a pixel high: layout rounding and baseline snapping add up
        transform: Translate {
            y: root.isVertical ? 0 : Math.round((compact.height - digitMetrics.tightBoundingRect.height) / 2)
                    - (Math.round(row.y + tempLabel.y + tempLabel.baselineOffset) + digitMetrics.tightBoundingRect.y)
        }
        TextMetrics { id: digitMetrics; font: tempLabel.font; text: "0" }

        // Separate label so the emoji font's taller line doesn't shift the temperature
        PlasmaComponents.Label {
            visible: Plasmoid.configuration.showEmoji !== false || !root.hasLocation
            Layout.alignment: Qt.AlignCenter
            text: root.hasLocation ? root.currentInfo.emoji : "⚙️"
            font.pointSize: compact.fontSize * 1.1
            opacity: root.current || !root.hasLocation ? 1 : 0.5
        }

        PlasmaComponents.Label {
            id: tempLabel
            visible: root.hasLocation
            Layout.alignment: Qt.AlignCenter
            text: root.current
                ? root.formatTemp(root.current.temp, Plasmoid.configuration.showUnit !== false)
                : (root.errorMsg !== "" ? "⚠" : "--°")
            font.pointSize: compact.fontSize
            font.family: compact.fontFamily
            // Cleared so the theme font's style name (e.g. "Text") doesn't override the weight
            font.styleName: ""
            font.weight: compact.fontWeight
            font.italic: compact.fontItalic
            font.features: ({ "tnum": 1 })
        }
    }
}
