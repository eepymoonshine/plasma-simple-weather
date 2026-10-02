/*
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

// Temperature line for the next hours, with rain chance bars underneath.
// Samples sit in the middle of their column so labels can line up with them.
Canvas {
    id: chart

    property var temps: []
    property var pops: []        // rain chance per sample, 0-100
    property var markers: []     // sample indices that get a dot
    property color lineColor: "#E8A33D"
    property color rainColor: "#6A9BCC"

    function xAt(i) { return width * (i + 0.5) / Math.max(temps.length, 1) }

    onTempsChanged: requestPaint()
    onPopsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var n = temps.length
        if (n < 2) return

        // Rain bars use the bottom 40%
        var colW = width / n
        ctx.fillStyle = Qt.alpha(rainColor, 0.45)
        for (var r = 0; r < pops.length; r++) {
            var bh = height * 0.4 * Math.min(pops[r], 100) / 100
            if (bh > 0) ctx.fillRect(r * colW + 1, height - bh, colW - 2, bh)
        }

        // Temperature line in the top 75%, scaled to the range shown
        var lo = Math.min.apply(null, temps), hi = Math.max.apply(null, temps)
        if (hi - lo < 4) { var mid = (hi + lo) / 2; lo = mid - 2; hi = mid + 2 }
        var top = 4, bottom = height * 0.75
        function y(t) { return bottom - (bottom - top) * (t - lo) / (hi - lo) }

        ctx.beginPath()
        ctx.moveTo(xAt(0), height)
        for (var i = 0; i < n; i++) ctx.lineTo(xAt(i), y(temps[i]))
        ctx.lineTo(xAt(n - 1), height)
        ctx.closePath()
        ctx.fillStyle = Qt.alpha(lineColor, 0.12)
        ctx.fill()

        ctx.beginPath()
        ctx.moveTo(xAt(0), y(temps[0]))
        for (var j = 1; j < n; j++) ctx.lineTo(xAt(j), y(temps[j]))
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 2
        ctx.lineJoin = "round"
        ctx.stroke()

        ctx.fillStyle = lineColor
        for (var m = 0; m < markers.length; m++) {
            var k = markers[m]
            if (k >= n) continue
            ctx.beginPath()
            ctx.arc(xAt(k), y(temps[k]), 3, 0, 2 * Math.PI)
            ctx.fill()
        }
    }
}
