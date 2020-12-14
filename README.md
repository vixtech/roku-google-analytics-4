# roku-google-analytics-4
Brightscript implementation of Google Analytics 4 (GA4), That is compatible with Firebase

## Installation
Copy the files inside "components" to your application.

## Usage
Put the code bellow in the start of your MainScene.

```brightscript
m.global.AddField("analytics", "node", false)
m.global.analytics = CreateObject("roSGNode", "GoogleAnalytics")
m.global.analytics.callFunc("initialize", {
  measurementId: "G-YOURMEASURENTID"
  appName: "YOUR APP NAME"
  docLocation: "https://YOUR DOC LOCATION"
  customArgs: {
    "ep.EXAMPLEPROPERTY": "HERE YOU CAN PUT ANY CUSTOM ARG, FOR EXAMPLE A DEFAULT EVENT PROPERTY (ep.*)"
  }
  isFirstOpen: myIsFirstOpen ' THIS VALUE IS OPTIONAL, THE DEFAULT BEHAVIOR IS TO USE THE STORAGE TO KNOW IF IT's THE FIRST OPEN
  userId: myUserId
  userProperties: {
    "userPropA": "SET USER PROPERTIES HERE"
  }
})
m.global.analytics.callFunc("start")
```

You can change the userId and userProperty later
```brightscript
m.global.analytics.callFunc("setUserId", myUserId)
m.global.analytics.callFunc("setUserProperties", myUserProperties)
```

You can log events with the function:
```brightscript
m.global.analytics.callFunc("logEvent", "my_event_name", {
  "myEventPropertyName": myEventPropertyValue
})
```
