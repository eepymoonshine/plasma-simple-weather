/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_locationName
    property real cfg_latitude
    property real cfg_longitude
    property string cfg_temperatureUnit
    property string cfg_windUnit
    property alias cfg_refreshInterval: refreshSpin.value
    property alias cfg_showEmoji: showEmoji.checked
    property alias cfg_showUnit: showUnit.checked
    property string cfg_panelFontFamily
    property real cfg_panelFontSize
    property int cfg_panelFontWeight
    property alias cfg_panelFontItalic: fontItalic.checked

    // Spin box with a unit, e.g. value 85 with scale 10 shows "8,5 pt"
    component UnitSpinBox: QQC2.SpinBox {
        property string suffix
        property int scale: 1
        property int decimals: 0

        // Same width so they line up, and padded since the style hugs the left border
        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
        leftPadding: Kirigami.Units.mediumSpacing
        // Allow typing the unit and either "." or ","
        validator: RegularExpressionValidator { regularExpression: /\d+([.,]\d+)?\s*\S*/ }
        textFromValue: function(value, locale) {
            return (value / scale).toLocaleString(locale, 'f', decimals) + suffix
        }
        valueFromText: function(text, locale) {
            return Math.round(parseFloat(text.replace(",", ".")) * scale)
        }
    }

    // Combo for a setting, selected after load so it doesn't stick on the first item
    component ValueComboBox: QQC2.ComboBox {
        property var current
        signal picked(var value)
        textRole: "text"
        valueRole: "value"
        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(current))
        onActivated: picked(currentValue)
    }

    // Location search (Open-Meteo geocoding)
    property var results: []
    property bool searching: false
    property string searchError: ""

    function search() {
        var query = searchField.text.trim()
        if (query === "") return
        searching = true
        searchError = ""
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            searching = false
            if (xhr.status !== 200) {
                results = []
                searchError = i18n("Couldn't reach Open-Meteo")
                return
            }
            try {
                results = JSON.parse(xhr.responseText).results || []
            } catch (e) {
                results = []
            }
            if (results.length === 0) searchError = i18n("No places found")
        }
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=8&name="
            + encodeURIComponent(query) + "&language=" + Qt.locale().name.split("_")[0])
        xhr.send()
    }

    function describe(place) {
        return [place.admin1, place.country].filter(function(s) { return s }).join(", ")
    }

    Kirigami.FormLayout {
        QQC2.Label {
            Kirigami.FormData.label: i18n("Location:")
            text: cfg_locationName !== ""
                ? cfg_locationName + "  (" + cfg_latitude.toFixed(2) + ", " + cfg_longitude.toFixed(2) + ")"
                : i18n("Not set, search for a city below")
            font.bold: cfg_locationName !== ""
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Find:")
            QQC2.TextField {
                id: searchField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                placeholderText: i18n("City name")
                onAccepted: page.search()
            }
            QQC2.Button {
                text: i18n("Search")
                icon.name: "search"
                enabled: searchField.text.trim() !== "" && !page.searching
                onClicked: page.search()
            }
            QQC2.BusyIndicator {
                visible: page.searching
                Layout.preferredHeight: searchField.height
                Layout.preferredWidth: searchField.height
            }
        }

        QQC2.Label {
            visible: page.searchError !== ""
            text: page.searchError
            opacity: 0.7
        }

        ColumnLayout {
            visible: page.results.length > 0
            spacing: 0
            Repeater {
                model: page.results
                delegate: QQC2.ItemDelegate {
                    required property var modelData
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                    text: modelData.name + " — " + page.describe(modelData)
                    onClicked: {
                        cfg_locationName = modelData.country ? modelData.name + ", " + modelData.country : modelData.name
                        cfg_latitude = modelData.latitude
                        cfg_longitude = modelData.longitude
                        page.results = []
                        page.searchError = ""
                        searchField.text = ""
                    }
                }
            }
        }

        Item { Kirigami.FormData.isSection: true }

        ValueComboBox {
            Kirigami.FormData.label: i18n("Temperature:")
            model: [
                { text: i18n("Celsius (°C)"), value: "celsius" },
                { text: i18n("Fahrenheit (°F)"), value: "fahrenheit" }
            ]
            current: cfg_temperatureUnit
            onPicked: function(value) { cfg_temperatureUnit = value }
        }

        ValueComboBox {
            Kirigami.FormData.label: i18n("Wind speed:")
            model: [
                { text: i18n("Kilometers per hour"), value: "kmh" },
                { text: i18n("Miles per hour"), value: "mph" },
                { text: i18n("Meters per second"), value: "ms" },
                { text: i18n("Knots"), value: "kn" }
            ]
            current: cfg_windUnit
            onPicked: function(value) { cfg_windUnit = value }
        }

        UnitSpinBox {
            id: refreshSpin
            Kirigami.FormData.label: i18n("Refresh every:")
            suffix: " min"
            from: 5; to: 120; stepSize: 5
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox { id: showEmoji; Kirigami.FormData.label: i18n("Panel:"); text: i18n("Show weather emoji") }
        QQC2.CheckBox { id: showUnit; text: i18n("Show unit (°C / °F)") }

        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.FormData.label: i18n("Font:")
            QQC2.CheckBox {
                id: customFont
                text: i18n("Custom")
                checked: cfg_panelFontFamily !== ""
                onToggled: cfg_panelFontFamily = checked ? (fontCombo.editText || Kirigami.Theme.defaultFont.family) : ""
            }
            QQC2.ComboBox {
                id: fontCombo
                enabled: customFont.checked
                editable: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                model: Qt.fontFamilies()
                // Ignore changes while loading, or the first font in the list wins
                property bool loaded: false
                Component.onCompleted: {
                    var fam = cfg_panelFontFamily || Kirigami.Theme.defaultFont.family
                    var i = find(fam)
                    if (i >= 0) currentIndex = i
                    else editText = fam
                    loaded = true
                }
                // Saves both picked and typed names, no Enter needed
                onEditTextChanged: if (loaded && customFont.checked && editText !== "") cfg_panelFontFamily = editText
            }
        }

        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.FormData.label: i18n("Size:")
            QQC2.CheckBox {
                id: customSize
                text: i18n("Custom")
                checked: cfg_panelFontSize > 0
                onToggled: cfg_panelFontSize = checked ? sizeSpin.value / 10 : 0
            }
            UnitSpinBox {
                id: sizeSpin
                enabled: customSize.checked
                // Stored in tenths of a point for half-point steps
                suffix: " pt"; scale: 10; decimals: 1
                from: 40; to: 300; stepSize: 5
                value: cfg_panelFontSize > 0 ? Math.round(cfg_panelFontSize * 10) : 90
                onValueModified: cfg_panelFontSize = value / 10
            }
        }

        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.FormData.label: i18n("Style:")
            // Fonts without the chosen weight fall back to the closest one they have
            ValueComboBox {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                model: [
                    { text: i18n("Thin"), value: Font.Thin },
                    { text: i18n("Extra Light"), value: Font.ExtraLight },
                    { text: i18n("Light"), value: Font.Light },
                    { text: i18n("Regular"), value: Font.Normal },
                    { text: i18n("Medium"), value: Font.Medium },
                    { text: i18n("Semi Bold"), value: Font.DemiBold },
                    { text: i18n("Bold"), value: Font.Bold },
                    { text: i18n("Extra Bold"), value: Font.ExtraBold },
                    { text: i18n("Black"), value: Font.Black }
                ]
                current: cfg_panelFontWeight
                onPicked: function(value) { cfg_panelFontWeight = value }
            }
            QQC2.CheckBox { id: fontItalic; text: i18n("Italic") }
        }
    }
}
