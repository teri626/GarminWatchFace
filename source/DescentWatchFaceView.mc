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
    // Garmin's built-in fonts contain no CJK glyphs, so Chinese characters require a
    // custom BMFont. BMFont is a pre-rendered bitmap font format consisting of two files:
    //   chinese.fnt   — text file with per-glyph metrics (atlas position, size, offsets)
    //   chinese_0.png — glyph atlas: all characters rendered white-on-transparent by PIL
    // The TTF source is STHeiti Medium (macOS system font), subsetted to only the needed
    // Chinese characters. Digits 0-9 are intentionally excluded and rendered with the
    // system font to keep the asset small.
    // Stored as a member so onUpdate (called every second) never re-allocates it.
    private var _chineseFont  as WatchUi.FontResource? = null;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _screenWidth  = dc.getWidth();
        _screenHeight = dc.getHeight();
        _centerX      = _screenWidth  / 2;
        _centerY      = _screenHeight / 2;
        // Decode the ResourceId into a drawable FontResource once here.
        // onLayout runs once at view init, so this never causes repeated allocation.
        _chineseFont  = WatchUi.loadResource(Rez.Fonts.ChineseFont) as WatchUi.FontResource;
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        // Black background (AMOLED saves battery)
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var clockTime = System.getClockTime();
        var now       = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        _drawZoneDividers(dc);
        _drawBattery(dc);
        _drawTime(dc, clockTime);
        _drawDate(dc, now);
    }

    private function _drawZoneDividers(dc as Dc) as Void {
        // Zone heights: 20%, 10%, 40%, 10%, 20%
        // Dividers at cumulative: 20%, 30%, 70%, 80%
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, _screenHeight * 20 / 100, _screenWidth, _screenHeight * 20 / 100);
        dc.drawLine(0, _screenHeight * 30 / 100, _screenWidth, _screenHeight * 30 / 100);
        dc.drawLine(0, _screenHeight * 70 / 100, _screenWidth, _screenHeight * 70 / 100);
        dc.drawLine(0, _screenHeight * 80 / 100, _screenWidth, _screenHeight * 80 / 100);
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
        var secStr = clockTime.sec.format("%02d");
        var rowY   = _centerY;  // vertically centered in zone 3 (30%–70%)

        // Measure both strings to center the group
        var timeW = dc.getTextWidthInPixels(timeStr, Graphics.FONT_NUMBER_THAI_HOT);
        var secW  = dc.getTextWidthInPixels(secStr,  Graphics.FONT_NUMBER_HOT);
        var gap   = 16;
        var groupX = _centerX - (timeW + gap + secW) / 2;

        // hh:mm in large font
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            groupX,
            rowY,
            Graphics.FONT_NUMBER_THAI_HOT,
            timeStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // ss — bottom-aligned with hh:mm
        // bottom of hh:mm = rowY + timeH/2; center ss at that bottom minus secH/2
        var timeH = dc.getFontHeight(Graphics.FONT_NUMBER_THAI_HOT);
        var secH  = dc.getFontHeight(Graphics.FONT_NUMBER_HOT);
        var secY  = rowY + (timeH - secH) / 2;
        dc.drawText(
            groupX + timeW + gap,
            secY,
            Graphics.FONT_NUMBER_HOT,
            secStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function _drawDate(dc as Dc, now as Gregorian.Info) as Void {
        var rowY    = _screenHeight * 25 / 100;
        var sysFont = Graphics.FONT_MEDIUM;

        // Fall back to system font if the resource failed to load (glyphs show as boxes,
        // but the app won't crash).
        var chnFont = _chineseFont != null ? _chineseFont : sysFont;

        var monthStr = now.month.toString();
        var dayStr   = now.day.toString();

        // Mixed-font rendering: digits use the system font (already contains 0-9, no need
        // to embed them in the custom asset); Chinese labels use the BMFont.
        // Measure each segment individually, then compute a single starting x so the full
        // "5月31日" string is centered as a group inside zone 2.
        var w1 = dc.getTextWidthInPixels(monthStr, sysFont);
        var w2 = dc.getTextWidthInPixels("月",      chnFont);
        var w3 = dc.getTextWidthInPixels(dayStr,    sysFont);
        var w4 = dc.getTextWidthInPixels("日",      chnFont);
        var x  = _centerX - (w1 + w2 + w3 + w4) / 2;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, rowY, sysFont, monthStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += w1;
        dc.drawText(x, rowY, chnFont, "月",      Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += w2;
        dc.drawText(x, rowY, sysFont, dayStr,    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += w3;
        dc.drawText(x, rowY, chnFont, "日",      Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
    }

    function onEnterSleep() as Void {
    }

}
