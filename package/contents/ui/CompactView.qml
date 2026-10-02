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
    readonly property bool fontBold: Plasmoid.configuration.panelFontBold !== false

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

        // Separate label so the emoji font's taller line doesn't shift the temperature
        PlasmaComponents.Label {
            visible: Plasmoid.configuration.showEmoji !== false || !root.hasLocation
            Layout.alignment: Qt.AlignCenter
            text: root.hasLocation ? root.currentInfo.emoji : "⚙️"
            font.pointSize: compact.fontSize * 1.1
            opacity: root.current || !root.hasLocation ? 1 : 0.5
        }

        PlasmaComponents.Label {
            visible: root.hasLocation
            Layout.alignment: Qt.AlignCenter
            text: root.current
                ? root.formatTemp(root.current.temp, Plasmoid.configuration.showUnit !== false)
                : (root.errorMsg !== "" ? "⚠" : "--°")
            font.pointSize: compact.fontSize
            font.family: compact.fontFamily
            font.bold: compact.fontBold
            font.features: ({ "tnum": 1 })
        }
    }
}
