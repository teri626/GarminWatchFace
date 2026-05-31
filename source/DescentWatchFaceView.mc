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

        _drawTime(dc, clockTime);
        _drawDate(dc, now);
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
