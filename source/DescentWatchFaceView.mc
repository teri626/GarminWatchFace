import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class DescentWatchFaceView extends WatchUi.WatchFace {

    // Screen center for Descent G2 (390x390)
    private var _screenWidth  as Number = 390;
    private var _screenHeight as Number = 390;
    private var _centerX      as Number = 195;
    private var _centerY      as Number = 195;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _screenWidth  = dc.getWidth();
        _screenHeight = dc.getHeight();
        _centerX      = _screenWidth  / 2;
        _centerY      = _screenHeight / 2;
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        // Black background (AMOLED saves battery)
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var clockTime = System.getClockTime();
        var now       = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);

        _drawBattery(dc);
        _drawTime(dc, clockTime);
        _drawDate(dc, now);
    }

    private function _drawBattery(dc as Dc) as Void {
        var stats = System.getSystemStats();
        var pct   = stats.battery.toNumber();

        var iconColor = Graphics.COLOR_GREEN;
        if (pct < 10) {
            iconColor = Graphics.COLOR_RED;
        } else if (pct < 30) {
            iconColor = Graphics.COLOR_YELLOW;
        }

        var pctStr    = pct + "%";
        var textWidth = dc.getTextWidthInPixels(pctStr, Graphics.FONT_XTINY);

        // Battery icon dimensions
        var bodyH = dc.getFontHeight(Graphics.FONT_XTINY) * 2 / 3;
        var bodyW = 44;
        var termW = 3;
        var termH = bodyH / 2;
        var gap   = 5;
        var rowY  = 30;

        // Center icon + gap + text as a group
        var totalW = bodyW + termW + gap + textWidth;
        var iconX  = _centerX - totalW / 2;
        var iconY  = rowY - bodyH / 2;

        // Battery body outline
        dc.setColor(iconColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(iconX, iconY, bodyW, bodyH);

        // Battery terminal (right side)
        dc.fillRectangle(iconX + bodyW, rowY - termH / 2, termW, termH);

        // Battery fill (inside body)
        var fillW = ((bodyW - 4) * pct / 100).toNumber();
        if (fillW > 0) {
            dc.fillRectangle(iconX + 2, iconY + 2, fillW, bodyH - 4);
        }

        // Percentage text — fixed white color
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            iconX + bodyW + termW + gap,
            rowY,
            Graphics.FONT_XTINY,
            pctStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function _drawTime(dc as Dc, clockTime as System.ClockTime) as Void {
        var timeStr = Lang.format("$1$:$2$", [
            clockTime.hour,
            clockTime.min.format("%02d")
        ]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _centerX,
            _centerY - 30,
            Graphics.FONT_NUMBER_THAI_HOT,
            timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function _drawDate(dc as Dc, now as Gregorian.Info) as Void {
        var dateStr = Lang.format("$1$ $2$", [now.day_of_week, now.day]);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _centerX,
            _centerY + 60,
            Graphics.FONT_MEDIUM,
            dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
    }

    function onEnterSleep() as Void {
    }

}
