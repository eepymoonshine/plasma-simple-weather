/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Settings
    readonly property string locationName: Plasmoid.configuration.locationName || ""
    readonly property bool hasLocation: locationName !== ""
    readonly property bool fahrenheit: Plasmoid.configuration.temperatureUnit === "fahrenheit"
    readonly property string windUnit: Plasmoid.configuration.windUnit || "kmh"
    readonly property int refreshMinutes: Math.max(Plasmoid.configuration.refreshInterval || 15, 5)

    // Weather data, filled by parseForecast()
    property var current: null   // {temp, feels, humidity, code, isDay, wind, windDir, precip, pressure, pop, uv}
    property var hourly: []      // next 24 hours: {time, temp, pop, code, isDay}
    property var daily: []       // {date, code, min, max, pop, sunrise, sunset, uv}
    property string errorMsg: ""
    property bool loading: false
    property double lastSuccess: 0

    readonly property var currentInfo: current ? weatherInfo(current.code, current.isDay) : weatherInfo(-1, true)

    // Open-Meteo request
    readonly property string forecastUrl: !hasLocation ? "" :
        "https://api.open-meteo.com/v1/forecast"
        + "?latitude=" + Plasmoid.configuration.latitude
        + "&longitude=" + Plasmoid.configuration.longitude
        + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m,pressure_msl"
        + "&hourly=temperature_2m,precipitation_probability,weather_code,is_day,uv_index"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max"
        + "&timezone=auto&forecast_days=7"
        + "&temperature_unit=" + (fahrenheit ? "fahrenheit" : "celsius")
        + "&wind_speed_unit=" + windUnit

    // Name, latitude and longitude change one after another when a location is picked, so wait
    // for them to settle instead of firing a request for each half-updated location
    onForecastUrlChanged: settleTimer.restart()
    Component.onCompleted: refresh()

    Timer {
        id: settleTimer
        interval: 300
        onTriggered: root.refresh()
    }

    property var pendingRequest: null

    function refresh() {
        if (pendingRequest) pendingRequest.abort()
        pendingRequest = null
        if (!hasLocation) {
            current = null; hourly = []; daily = []; errorMsg = ""; loading = false
            return
        }
        loading = true
        var url = forecastUrl
        var xhr = new XMLHttpRequest()
        pendingRequest = xhr
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            // A newer request replaced this one, or the location changed meanwhile
            if (xhr !== pendingRequest || url !== forecastUrl) return
            pendingRequest = null
            loading = false
            if (xhr.status === 200) {
                try {
                    parseForecast(JSON.parse(xhr.responseText))
                    errorMsg = ""
                    lastSuccess = Date.now()
                    retryTimer.stop()
                } catch (e) {
                    errorMsg = i18n("Unexpected response from Open-Meteo")
                }
            } else {
                var reason = ""
                try { reason = JSON.parse(xhr.responseText).reason || "" } catch (e) {}
                errorMsg = reason !== "" ? reason : i18n("Couldn't reach Open-Meteo")
                // Offline at login is common; try again soon rather than waiting a full interval
                retryTimer.restart()
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function parseForecast(d) {
        var c = d.current, h = d.hourly, dl = d.daily

        // Hourly data starts at midnight; skip ahead to the current hour
        var nowHour = c.time.substring(0, 13) + ":00"
        var start = 0
        while (start < h.time.length && h.time[start] < nowHour) start++

        var hours = []
        for (var i = start; i < Math.min(start + 24, h.time.length); i++) {
            hours.push({ time: h.time[i], temp: h.temperature_2m[i], pop: h.precipitation_probability[i] || 0,
                         code: h.weather_code[i], isDay: h.is_day[i] === 1 })
        }

        var days = []
        for (var j = 0; j < dl.time.length; j++) {
            days.push({ date: dl.time[j], code: dl.weather_code[j],
                        min: dl.temperature_2m_min[j], max: dl.temperature_2m_max[j],
                        pop: dl.precipitation_probability_max[j] || 0,
                        sunrise: dl.sunrise[j], sunset: dl.sunset[j], uv: dl.uv_index_max[j] || 0 })
        }

        current = {
            temp: c.temperature_2m, feels: c.apparent_temperature, humidity: c.relative_humidity_2m,
            code: c.weather_code, isDay: c.is_day === 1, precip: c.precipitation,
            wind: c.wind_speed_10m, windDir: c.wind_direction_10m, pressure: c.pressure_msl,
            pop: hours.length ? hours[0].pop : 0,
            uv: start < h.uv_index.length ? (h.uv_index[start] || 0) : 0
        }
        hourly = hours
        daily = days
    }

    Timer {
        interval: root.refreshMinutes * 60000
        running: root.hasLocation
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: retryTimer
        interval: 60000
        onTriggered: root.refresh()
    }

    // WMO weather codes -> emoji and description. ️ forces the color emoji form.
    function weatherInfo(code, isDay) {
        switch (code) {
        case 0: return { emoji: isDay ? "☀️" : "🌙", text: i18n("Clear sky") }
        case 1: return { emoji: isDay ? "🌤️" : "🌙", text: i18n("Mainly clear") }
        case 2: return { emoji: isDay ? "⛅" : "☁️", text: i18n("Partly cloudy") }
        case 3: return { emoji: "☁️", text: i18n("Overcast") }
        case 45: case 48: return { emoji: "🌫️", text: i18n("Fog") }
        case 51: case 53: case 55: return { emoji: "🌦️", text: i18n("Drizzle") }
        case 56: case 57: return { emoji: "🌧️", text: i18n("Freezing drizzle") }
        case 61: case 63: return { emoji: "🌧️", text: i18n("Rain") }
        case 65: return { emoji: "🌧️", text: i18n("Heavy rain") }
        case 66: case 67: return { emoji: "🌧️", text: i18n("Freezing rain") }
        case 71: case 73: return { emoji: "🌨️", text: i18n("Snow") }
        case 75: return { emoji: "🌨️", text: i18n("Heavy snow") }
        case 77: return { emoji: "❄️", text: i18n("Snow grains") }
        case 80: case 81: return { emoji: isDay ? "🌦️" : "🌧️", text: i18n("Rain showers") }
        case 82: return { emoji: "🌧️", text: i18n("Heavy showers") }
        case 85: case 86: return { emoji: "🌨️", text: i18n("Snow showers") }
        case 95: return { emoji: "⛈️", text: i18n("Thunderstorm") }
        case 96: case 99: return { emoji: "⛈️", text: i18n("Thunderstorm with hail") }
        default: return { emoji: "🌡️", text: "" }
        }
    }

    // Formatting
    readonly property string unitLetter: fahrenheit ? "F" : "C"

    function formatTemp(t, withUnit) {
        if (t === undefined || t === null) return "--°"
        return Math.round(t) + "°" + (withUnit ? unitLetter : "")
    }

    function formatWind(speed, deg) {
        var units = { kmh: "km/h", mph: "mph", ms: "m/s", kn: "kn" }
        var dirs = [i18n("N"), i18n("NE"), i18n("E"), i18n("SE"), i18n("S"), i18n("SW"), i18n("W"), i18n("NW")]
        return Math.round(speed) + " " + units[windUnit] + " " + dirs[Math.round(deg / 45) % 8]
    }

    // Open-Meteo times are local wall-clock strings like "2026-10-02T14:00"
    function parseLocal(s) {
        var p = s.split(/[-T:]/)
        return new Date(p[0], p[1] - 1, p[2], p[3] || 0, p[4] || 0)
    }
    function formatHour(s) {
        return Qt.formatTime(parseLocal(s), Qt.locale().timeFormat(Locale.ShortFormat))
    }
    // Just the hour for chart labels: "6 PM" or "18:00", following the locale's clock style
    function formatHourShort(s) {
        var twelveHour = /a/i.test(Qt.locale().timeFormat(Locale.ShortFormat))
        return Qt.formatTime(parseLocal(s), twelveHour ? "h AP" : "HH:mm")
    }
    function formatDay(s, index) {
        if (index === 0) return i18n("Today")
        return Qt.locale().dayName(parseLocal(s).getDay(), Locale.ShortFormat)
    }

    // Cold blue to hot coral, based on °C
    function tempColor(t) {
        var c = fahrenheit ? (t - 32) * 5 / 9 : t
        if (c < 0) return "#8FB8EF"
        if (c < 10) return "#6A9BCC"
        if (c < 18) return "#5FB3A1"
        if (c < 26) return "#E8A33D"
        return "#D97757"
    }

    readonly property color accent: "#E8A33D"
    readonly property color rainColor: "#6A9BCC"

    readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    compactRepresentation: CompactView {}
    fullRepresentation: FullView {}

    Plasmoid.icon: "weather-few-clouds"
    toolTipMainText: hasLocation ? locationName : i18n("Simple Weather")
    toolTipSubText: {
        if (!hasLocation) return i18n("Choose a location in the widget settings")
        if (!current) return errorMsg !== "" ? errorMsg : i18n("Loading…")
        return currentInfo.emoji + " " + currentInfo.text + ", " + formatTemp(current.temp, true)
            + "\n" + i18n("Feels like %1", formatTemp(current.feels, true))
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            onTriggered: root.refresh()
        }
    ]
}
