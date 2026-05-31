import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class DescentWatchFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new DescentWatchFaceView() ];
    }

}

function getApp() as DescentWatchFaceApp {
    return Application.getApp() as DescentWatchFaceApp;
}
