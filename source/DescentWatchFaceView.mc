import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.SensorHistory;
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
        _drawTemperature(dc);
        _drawSteps(dc);
        _drawTime(dc, clockTime);
        _drawDate(dc, now);
        _drawDayOfWeek(dc, now);
        _drawLunarDate(dc, now);
    }

    private function _drawZoneDividers(dc as Dc) as Void {
        // Zone heights: 20%, 10%, 40%, 10%, 20%
        // Horizontal dividers at cumulative: 20%, 30%, 70%, 80%
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, _screenHeight * 20 / 100, _screenWidth, _screenHeight * 20 / 100);
        dc.drawLine(0, _screenHeight * 30 / 100, _screenWidth, _screenHeight * 30 / 100);
        dc.drawLine(0, _screenHeight * 70 / 100, _screenWidth, _screenHeight * 70 / 100);
        dc.drawLine(0, _screenHeight * 80 / 100, _screenWidth, _screenHeight * 80 / 100);

        // Vertical dividers splitting zone 2 into 3 columns (left | mid | right).
        // Left is wider (date needs room); mid is narrower; right gets the remainder.
        // Dividers at x=143 and x=213 → left=26–143(117px), mid=143–213(70px), right=213–364(151px)
        var z2Top = _screenHeight * 20 / 100;
        var z2Bot = _screenHeight * 30 / 100;
        dc.drawLine(143, z2Top, 143, z2Bot);
        dc.drawLine(213, z2Top, 213, z2Bot);
    }

    private function _drawTemperature(dc as Dc) as Void {
        // Use SensorHistory for wrist ambient temperature (Celsius, from onboard sensor).
        // Falls back silently if sensor data is unavailable.
        var temp = null;
        if (Toybox has :SensorHistory && SensorHistory has :getTemperatureHistory) {
            var iter = SensorHistory.getTemperatureHistory({:period => 1});
            if (iter != null) {
                var sample = iter.next();
                if (sample != null) { temp = sample.data; }
            }
        }
        if (temp == null) { return; }

        var rowY    = 64;
        var chnFont = _chineseFont != null ? _chineseFont : Graphics.FONT_XTINY;
        var sysFont = Graphics.FONT_XTINY;
        var tempStr = (temp as Float).format("%.0f");
        var icon    = WatchUi.loadResource(Rez.Drawables.Thermometer) as Graphics.BitmapReference;
        var iconW   = icon.getWidth();
        var iconH   = icon.getHeight();
        var gap     = 4;

        // Layout: [icon] 温度 [value] °C, centered on left half of zone 1 (x≈110)
        var wWenDu = dc.getTextWidthInPixels("温度",  chnFont);
        var wVal   = dc.getTextWidthInPixels(tempStr, sysFont);
        var wDegC  = dc.getTextWidthInPixels("°C",    sysFont);
        var total  = iconW + gap + wWenDu + gap + wVal + wDegC;
        var x      = 110 - total / 2;

        dc.drawBitmap(x, rowY - iconH / 2, icon);
        x += iconW + gap;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, rowY, chnFont, "温度", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += wWenDu + gap;
        dc.drawText(x, rowY, sysFont, tempStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += wVal;
        dc.drawText(x, rowY, sysFont, "°C",    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function _drawSteps(dc as Dc) as Void {
        // Daily step count comes from ActivityMonitor (pedometer/health tracking),
        // not Activity (workout tracking). Activity.getActivityInfo().steps is for
        // the current workout session only.
        var steps = 0;
        var info  = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            steps = info.steps;
        }

        var rowY     = 64;
        var sysFont  = Graphics.FONT_XTINY;
        var stepsStr = (steps as Number).toString();
        var icon     = WatchUi.loadResource(Rez.Drawables.StepsIcon) as Graphics.BitmapReference;
        var iconW    = icon.getWidth();
        var iconH    = icon.getHeight();
        var gap      = 4;

        // Layout: [icon] [count], centered on right half of zone 1 (x≈270)
        var wSteps = dc.getTextWidthInPixels(stepsStr, sysFont);
        var total  = iconW + gap + wSteps;
        var x      = 270 - total / 2;

        dc.drawBitmap(x, rowY - iconH / 2, icon);
        x += iconW + gap;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, rowY, sysFont, stepsStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
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
        // Digits 0-9 are now included in the BMFont (STHeiti 20px), so everything
        // uses chnFont — digit height matches Chinese character height exactly.
        var chnFont = _chineseFont != null ? _chineseFont : Graphics.FONT_SMALL;

        var monthStr = now.month.toString();
        var dayStr   = now.day.toString();

        // Left column center = 84px ((26+143)/2, based on divider at x=143).
        var w1 = dc.getTextWidthInPixels(monthStr, chnFont);
        var w2 = dc.getTextWidthInPixels("月",      chnFont);
        var w3 = dc.getTextWidthInPixels(dayStr,    chnFont);
        var w4 = dc.getTextWidthInPixels("日",      chnFont);
        var x  = 84 - (w1 + w2 + w3 + w4) / 2;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, rowY, chnFont, monthStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += w1;
        dc.drawText(x, rowY, chnFont, "月",     Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += w2;
        dc.drawText(x, rowY, chnFont, dayStr,   Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += w3;
        dc.drawText(x, rowY, chnFont, "日",     Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function _drawDayOfWeek(dc as Dc, now as Gregorian.Info) as Void {
        // day_of_week with FORMAT_SHORT: 1=Sun, 2=Mon, ..., 7=Sat
        var suffixes = ["日","一","二","三","四","五","六"];
        var suffix   = suffixes[(now.day_of_week as Number) - 1];
        var rowY     = _screenHeight * 25 / 100;
        var chnFont  = _chineseFont != null ? _chineseFont : Graphics.FONT_SMALL;

        // "星期" prefix + single-char suffix, centered in the middle column (x=168, shifted left).
        var wPrefix = dc.getTextWidthInPixels("星期",  chnFont);
        var wSuffix = dc.getTextWidthInPixels(suffix, chnFont);
        // Mid column center = 178px ((143+213)/2).
        var x       = 178 - (wPrefix + wSuffix) / 2;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x,           rowY, chnFont, "星期", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x + wPrefix, rowY, chnFont, suffix, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Precomputed Chinese lunar calendar data, generated from the lunardate Python library.
    // 16 values per year: [cnyGregMonth, cnyGregDay, leapMonth, m1..m13]
    // m1–m13 are days per lunar month in order (13 entries; trailing 0 = unused, no leap that year).
    // For leap year L: entries are [m1..mL, mL(leap), mL+1..m12].
    // Covers 2025–2036 (index 0 = 2025). 2025 is included to handle Jan–Feb 2026 before CNY.
    private const LUNAR_DATA = [
        // 2025: CNY=1/29, leap=6
        1, 29, 6,  30, 29, 30, 29, 29, 30, 29, 30, 29, 30, 30, 30, 29,
        // 2026: CNY=2/17, no leap
        2, 17, 0,  30, 29, 30, 29, 29, 30, 29, 29, 30, 30, 30, 29,  0,
        // 2027: CNY=2/6,  no leap
        2,  6, 0,  30, 30, 29, 30, 29, 29, 30, 29, 29, 30, 30, 29,  0,
        // 2028: CNY=1/26, leap=5
        1, 26, 5,  30, 30, 30, 29, 30, 29, 29, 30, 29, 29, 30, 30, 29,
        // 2029: CNY=2/13, no leap
        2, 13, 0,  30, 30, 29, 30, 29, 30, 29, 30, 29, 29, 30, 30,  0,
        // 2030: CNY=2/3,  no leap
        2,  3, 0,  29, 30, 29, 30, 30, 29, 30, 29, 30, 29, 30, 29,  0,
        // 2031: CNY=1/23, leap=3
        1, 23, 3,  29, 30, 30, 29, 30, 29, 30, 30, 29, 30, 29, 30, 29,
        // 2032: CNY=2/11, no leap
        2, 11, 0,  30, 29, 29, 30, 29, 30, 30, 29, 30, 30, 29, 30,  0,
        // 2033: CNY=1/31, leap=11
        1, 31, 11, 29, 30, 29, 29, 30, 29, 30, 29, 30, 30, 30, 29, 30,
        // 2034: CNY=2/19, no leap
        2, 19, 0,  29, 30, 29, 29, 30, 29, 30, 29, 30, 30, 29, 30,  0,
        // 2035: CNY=2/8,  no leap
        2,  8, 0,  30, 29, 30, 29, 29, 30, 29, 29, 30, 30, 29, 30,  0,
        // 2036: CNY=1/28, leap=6
        1, 28, 6,  30, 30, 29, 30, 29, 29, 30, 29, 29, 30, 29, 30, 30,
    ];

    // Compute Julian Day Number (integer) for a Gregorian date.
    private function _toJD(y as Number, m as Number, d as Number) as Number {
        var a  = (14 - m) / 12;
        var yr = y + 4800 - a;
        var mo = m + 12 * a - 3;
        return d + (153 * mo + 2) / 5 + 365 * yr + yr / 4 - yr / 100 + yr / 400 - 32045;
    }

    // Returns lunar month * 100 + lunar day (e.g. 517 = month 5, day 17).
    // Uses the precomputed LUNAR_DATA table; returns 0 if date is out of range.
    private function _getLunarMonthDay(y as Number, m as Number, d as Number) as Number {
        if (y < 2025 || y > 2036) { return 0; }

        // Determine which lunar year the date falls in
        var thisBase = (y - 2025) * 16;
        var cnyMThis = LUNAR_DATA[thisBase];
        var cnyDThis = LUNAR_DATA[thisBase + 1];
        var lunarY   = (m < cnyMThis || (m == cnyMThis && d < cnyDThis)) ? y - 1 : y;
        if (lunarY < 2025) { return 0; }

        var base  = (lunarY - 2025) * 16;
        var cnyM  = LUNAR_DATA[base];
        var cnyD  = LUNAR_DATA[base + 1];
        var leapM = LUNAR_DATA[base + 2];

        // Days elapsed since Chinese New Year
        var elapsed = _toJD(y, m, d) - _toJD(lunarY, cnyM, cnyD);

        // Walk through lunar months to find current month and day
        for (var i = 0; i < 13; i++) {
            var size = LUNAR_DATA[base + 3 + i];
            if (size == 0) { break; }
            if (elapsed < size) {
                // Map flat index i → actual lunar month number
                var lunarMonth = 0;
                if (leapM == 0) {
                    lunarMonth = i + 1;
                } else if (i < leapM) {
                    lunarMonth = i + 1;       // before leap insertion
                } else if (i == leapM) {
                    lunarMonth = leapM;        // the leap month itself (same number)
                } else {
                    lunarMonth = i;            // after leap insertion, index shifts by 1
                }
                return lunarMonth * 100 + elapsed + 1;
            }
            elapsed -= size;
        }
        return 1230;
    }

    private function _drawLunarDate(dc as Dc, now as Gregorian.Info) as Void {
        var md      = _getLunarMonthDay(now.year as Number, now.month as Number, now.day as Number);
        if (md == 0) { return; }

        var lunarMonth = md / 100;
        var lunarDay   = md % 100;
        var rowY       = _screenHeight * 25 / 100;
        var chnFont    = _chineseFont != null ? _chineseFont : Graphics.FONT_SMALL;

        // Lunar month in Chinese: 正月, 二…九月, 十月, 十一月, 十二月
        // Month 1 uses 正 (not 一); the 月 character is drawn separately after monthCh.
        var units = ["一","二","三","四","五","六","七","八","九","十"];
        var monthCh = "";
        if (lunarMonth == 1) {
            monthCh = "正";
        } else if (lunarMonth <= 9) {
            monthCh = units[lunarMonth - 1];
        } else if (lunarMonth == 10) {
            monthCh = "十";
        } else {
            monthCh = "十" + units[lunarMonth - 11];   // 十一 or 十二
        }

        // Format lunar day:  1–10 → 初一…初十  11–19 → 十一…十九
        //                   20   → 二十         21–29 → 廿一…廿九   30 → 三十
        var prefix = "";
        var dayCh  = "";
        if (lunarDay <= 10) {
            prefix = "初"; dayCh = units[lunarDay - 1];
        } else if (lunarDay < 20) {
            prefix = "十"; dayCh = units[lunarDay - 11];
        } else if (lunarDay == 20) {
            prefix = "二"; dayCh = "十";
        } else if (lunarDay < 30) {
            prefix = "廿"; dayCh = units[lunarDay - 21];
        } else {
            prefix = "三"; dayCh = "十";
        }

        // Layout: 农 [gap] monthCh 月 prefix dayCh — all BMFont, centered on right column (x=307).
        // gap ≈ 1.5 char widths between 农 and the date portion.
        var gap    = dc.getTextWidthInPixels("一", chnFont) * 3 / 4;
        var wNong  = dc.getTextWidthInPixels("农",     chnFont);
        var wMon   = dc.getTextWidthInPixels(monthCh,  chnFont);
        var wYue   = dc.getTextWidthInPixels("月",     chnFont);
        var wPre   = dc.getTextWidthInPixels(prefix,   chnFont);
        var wDay   = dc.getTextWidthInPixels(dayCh,    chnFont);
        var total  = wNong + gap + wMon + wYue + wPre + wDay;
        // Right column center = 288px ((213+364)/2 ≈ 288).
        var x      = 288 - total / 2;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, rowY, chnFont, "农", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += wNong + gap;
        dc.drawText(x, rowY, chnFont, monthCh, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += wMon;
        dc.drawText(x, rowY, chnFont, "月", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += wYue;
        dc.drawText(x, rowY, chnFont, prefix, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += wPre;
        dc.drawText(x, rowY, chnFont, dayCh, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
    }

    function onEnterSleep() as Void {
    }

}
