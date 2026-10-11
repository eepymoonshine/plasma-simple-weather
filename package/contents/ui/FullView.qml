/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: full
    clip: true

    readonly property color cardColor: Qt.alpha(Kirigami.Theme.textColor, 0.07)
    readonly property bool hasData: root.current !== null

    Layout.minimumWidth: Kirigami.Units.gridUnit * 19
    Layout.preferredWidth: Kirigami.Units.gridUnit * 21
    // Fit the content exactly, or Plasma's saved popup size can leave a gap at the bottom
    readonly property real contentHeight: mainColumn.implicitHeight + Kirigami.Units.smallSpacing * 2
    Layout.minimumHeight: contentHeight
    Layout.preferredHeight: contentHeight
    Layout.maximumHeight: contentHeight

    // Ticks the "Updated … ago" text
    property double now: Date.now()
    Timer {
        interval: 30000
        running: full.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: full.now = Date.now()
    }

    // Building blocks

    component SectionTitle: PlasmaComponents.Label {
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize - 1
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2
        font.bold: true
        opacity: 0.55
    }

    component Card: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        radius: root.cardRadius
        color: full.cardColor
        implicitHeight: inner.implicitHeight + Kirigami.Units.mediumSpacing * 2

        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: Kirigami.Units.mediumSpacing
            spacing: Kirigami.Units.smallSpacing
        }
    }

    component RingCard: Rectangle {
        id: ringCard
        property string title
        property real percent
        property string label
        property color ringColor

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1   // equal thirds
        radius: root.cardRadius
        color: full.cardColor
        implicitHeight: ringCol.implicitHeight + Kirigami.Units.mediumSpacing * 2

        ColumnLayout {
            id: ringCol
            anchors.fill: parent
            anchors.margins: Kirigami.Units.mediumSpacing
            spacing: Kirigami.Units.smallSpacing

            UsageRing {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 56; Layout.preferredHeight: 56
                percent: ringCard.percent
                label: ringCard.label
                ringColor: ringCard.ringColor
                lineWidth: 5; showPercentSign: true; fontScale: 0.22
            }
            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: ringCard.title
                font.bold: true; font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }
    }

    component DetailRow: RowLayout {
        id: detailRow
        property string label
        property string value
        Layout.fillWidth: true
        PlasmaComponents.Label { text: detailRow.label; opacity: 0.65 }
        Item { Layout.fillWidth: true }
        PlasmaComponents.Label { text: detailRow.value; font.features: ({ "tnum": 1 }) }
    }

    component Emoji: PlasmaComponents.Label {
        property real size: Kirigami.Theme.defaultFont.pointSize * 1.4
        font.pointSize: size
    }

    // Layout

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        anchors.leftMargin: Kirigami.Units.mediumSpacing
        anchors.rightMargin: Kirigami.Units.mediumSpacing
        spacing: Kirigami.Units.smallSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "weather-few-clouds"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            PlasmaComponents.Label {
                text: i18n("Weather")
                font.bold: true
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.25
            }
            Item { Layout.fillWidth: true }

            Rectangle {
                visible: root.hasLocation
                Layout.maximumWidth: Kirigami.Units.gridUnit * 10
                Layout.preferredWidth: placeLabel.implicitWidth + Kirigami.Units.largeSpacing
                Layout.preferredHeight: placeLabel.implicitHeight + Kirigami.Units.smallSpacing
                radius: height / 2
                color: Qt.alpha(root.accent, 0.18)

                PlasmaComponents.Label {
                    id: placeLabel
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - Kirigami.Units.largeSpacing)
                    text: root.locationName
                    elide: Text.ElideRight
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.bold: true; color: root.accent
                }
            }
        }

        // No location yet
        Card {
            visible: !root.hasLocation
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: i18n("Choose a location to see the weather.")
                wrapMode: Text.WordWrap
            }
            PlasmaComponents.Button {
                text: i18n("Choose Location…")
                icon.name: "mark-location"
                onClicked: Plasmoid.internalAction("configure").trigger()
            }
        }

        // Errors (softer when we still have older data to show)
        Rectangle {
            visible: root.hasLocation && root.errorMsg !== ""
            Layout.fillWidth: true
            radius: root.cardRadius
            color: Qt.alpha(full.hasData ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.negativeTextColor, 0.12)
            implicitHeight: errorLabel.implicitHeight + Kirigami.Units.largeSpacing * 2

            PlasmaComponents.Label {
                id: errorLabel
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                text: "⚠ " + (full.hasData
                    ? i18n("Couldn't update, showing earlier data")
                    : root.errorMsg + " · " + i18n("Retrying in a minute"))
                color: full.hasData ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.negativeTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                wrapMode: Text.WordWrap
            }
        }

        // Loading the first time
        PlasmaComponents.BusyIndicator {
            visible: root.hasLocation && !full.hasData && root.errorMsg === ""
            Layout.alignment: Qt.AlignHCenter
        }

        // Current conditions
        Card {
            visible: full.hasData
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                Emoji {
                    text: root.currentInfo.emoji
                    size: Kirigami.Theme.defaultFont.pointSize * 2.8
                }
                ColumnLayout {
                    spacing: 0
                    PlasmaComponents.Label {
                        text: full.hasData ? root.formatTemp(root.current.temp, false) : ""
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.2
                        font.bold: true
                        color: full.hasData ? root.tempColor(root.current.temp) : Kirigami.Theme.textColor
                    }
                    PlasmaComponents.Label {
                        text: root.currentInfo.text
                        opacity: 0.8
                    }
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignRight
                        visible: root.daily.length > 0
                        text: root.daily.length > 0
                            ? "↑ " + root.formatTemp(root.daily[0].max, false) + "   ↓ " + root.formatTemp(root.daily[0].min, false)
                            : ""
                        font.bold: true
                        font.features: ({ "tnum": 1 })
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignRight
                        text: full.hasData ? i18n("Feels like %1", root.formatTemp(root.current.feels, false)) : ""
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        opacity: 0.65
                    }
                }
            }
        }

        // Rings
        RowLayout {
            visible: full.hasData
            Layout.fillWidth: true
            // Don't stretch, or the cards resize when rows appear below
            Layout.fillHeight: false
            spacing: Kirigami.Units.mediumSpacing

            RingCard {
                title: i18n("Humidity")
                percent: full.hasData ? root.current.humidity : 0
                ringColor: "#5FB3A1"
            }
            RingCard {
                title: i18n("Rain chance")
                percent: full.hasData ? root.current.pop : 0
                ringColor: root.rainColor
            }
            RingCard {
                readonly property real uv: full.hasData ? root.current.uv : 0
                title: i18n("UV index")
                percent: Math.min(uv / 11 * 100, 100)
                label: uv.toLocaleString(Qt.locale(), 'f', uv < 10 ? 1 : 0)
                ringColor: uv < 3 ? Kirigami.Theme.positiveTextColor
                    : uv < 6 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.negativeTextColor
            }
        }

        // Next 24 hours
        Card {
            visible: root.hourly.length > 1
            RowLayout {
                Layout.fillWidth: true
                SectionTitle { text: i18n("Next 24 hours") }
                Item { Layout.fillWidth: true }
                Rectangle { width: 6; height: 6; radius: 3; color: root.rainColor; opacity: 0.6 }
                PlasmaComponents.Label {
                    text: i18n("rain chance")
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    opacity: 0.55
                }
            }

            TempChart {
                id: hourChart
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                temps: root.hourly.map(function(h) { return h.temp })
                pops: root.hourly.map(function(h) { return h.pop })
                markers: [0, 4, 8, 12, 16, 20]
                lineColor: root.accent
                rainColor: root.rainColor
            }

            // A label column under every marked hour, centered on its dot
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: hourLabels.count > 0 ? hourLabels.itemAt(0).implicitHeight : 0

                Repeater {
                    id: hourLabels
                    model: hourChart.markers.filter(function(k) { return k < root.hourly.length })
                    delegate: ColumnLayout {
                        required property int modelData
                        readonly property var hour: root.hourly[modelData]
                        spacing: 0
                        width: implicitWidth
                        x: Math.max(0, Math.min(parent.width - width, hourChart.xAt(modelData) - width / 2))

                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData === 0 ? i18n("Now") : root.formatHourShort(hour.time)
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            opacity: 0.65
                        }
                        Emoji {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.weatherInfo(hour.code, hour.isDay).emoji
                        }
                        PlasmaComponents.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.formatTemp(hour.temp, false)
                            font.bold: true
                        }
                    }
                }
            }
        }

        // 7 days
        Card {
            id: dailyCard
            visible: root.daily.length > 0
            readonly property real lowest: Math.min.apply(null, root.daily.map(function(d) { return d.min }))
            readonly property real highest: Math.max.apply(null, root.daily.map(function(d) { return d.max }))

            SectionTitle { text: i18n("%1-day forecast", root.daily.length) }

            Repeater {
                model: root.daily
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: root.formatDay(modelData.date, index)
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                        elide: Text.ElideRight
                    }
                    Emoji {
                        text: root.weatherInfo(modelData.code, true).emoji
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                        horizontalAlignment: Text.AlignHCenter
                    }
                    PlasmaComponents.Label {
                        // Only worth showing once rain is reasonably likely
                        text: modelData.pop >= 20 ? modelData.pop + "%" : ""
                        color: root.rainColor
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        font.bold: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                    }
                    PlasmaComponents.Label {
                        text: root.formatTemp(modelData.min, false)
                        opacity: 0.65
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.8
                        font.features: ({ "tnum": 1 })
                    }

                    // The day's range on a scale shared by the whole week
                    Rectangle {
                        id: track
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                        readonly property real span: Math.max(dailyCard.highest - dailyCard.lowest, 1)

                        Rectangle {
                            x: track.width * (modelData.min - dailyCard.lowest) / track.span
                            width: Math.max(track.width * (modelData.max - modelData.min) / track.span, track.height)
                            height: parent.height
                            radius: 3
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: root.tempColor(modelData.min) }
                                GradientStop { position: 1; color: root.tempColor(modelData.max) }
                            }
                        }
                    }

                    PlasmaComponents.Label {
                        text: root.formatTemp(modelData.max, false)
                        font.bold: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.8
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }

        // Details
        Card {
            visible: full.hasData
            SectionTitle { text: i18n("Details") }
            DetailRow { label: i18n("Wind"); value: full.hasData ? root.formatWind(root.current.wind, root.current.windDir) : "" }
            DetailRow { label: i18n("Precipitation"); value: full.hasData ? (root.current.precip || 0).toLocaleString(Qt.locale(), 'f', 1) + " mm" : "" }
            DetailRow { label: i18n("Pressure"); value: full.hasData && root.current.pressure ? Math.round(root.current.pressure) + " hPa" : "" }
            DetailRow { label: i18n("Sunrise"); value: root.daily.length ? root.formatHour(root.daily[0].sunrise) : "" }
            DetailRow { label: i18n("Sunset"); value: root.daily.length ? root.formatHour(root.daily[0].sunset) : "" }
        }

        // Footer
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: {
                    if (root.loading) return i18n("Updating…")
                    if (root.lastSuccess <= 0) return ""
                    var mins = Math.floor((full.now - root.lastSuccess) / 60000)
                    return mins < 1 ? i18n("Updated just now") : i18n("Updated %1 min ago", mins)
                }
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                opacity: 0.65
            }
            Item { Layout.fillWidth: true }
            // Open-Meteo's free tier asks for attribution
            PlasmaComponents.ToolButton {
                text: "Open-Meteo"
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                display: QQC2.AbstractButton.TextOnly
                onClicked: Qt.openUrlExternally("https://open-meteo.com/")
                QQC2.ToolTip.text: i18n("Weather data by Open-Meteo.com")
                QQC2.ToolTip.visible: hovered
            }
            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                enabled: root.hasLocation && !root.loading
                onClicked: root.refresh()
                QQC2.ToolTip.text: i18n("Refresh")
                QQC2.ToolTip.visible: hovered
            }
        }
    }
}
