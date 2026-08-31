import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ViDataFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new ViDataFaceView() ];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() as Void {
        // Drop the snapshot so a new zone or unit shows at once rather than
        // waiting for the minute to roll over.
        Frame.invalidate();
        WatchUi.requestUpdate();
    }

}

function getApp() as ViDataFaceApp {
    return Application.getApp() as ViDataFaceApp;
}