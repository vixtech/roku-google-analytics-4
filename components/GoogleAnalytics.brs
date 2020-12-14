' Implementation based on https://gist.github.com/IjzerenHein/df3f65093038dd70ad871f926be6f45e

sub Init()
    m.endpoint = "https://analytics.google.com/g/collect"
    m.config = invalid
    m.options = invalid
    m.codedUserProperties = {}
    m.userId = invalid
    m.screenName = invalid
    m.lastEventTime = invalid
    m.sessionHitsCount = 0
    m.top.functionName = "startTask"
    m.userEngagementIntervalSeconds = 30

    m.timer = CreateObject("roSgnode", "Timer")
    m.timer.observeField("fire","logUserEngagement")
    m.timer.duration = m.userEngagementIntervalSeconds
    m.timer.repeat = true
    ' start later
end sub

function initialize(params as object)
    ' Analytics stuff
    appInfo = CreateObject("roAppInfo")
    deviceInfo = CreateObject("roDeviceInfo")
    displaySize = deviceInfo.GetDisplaySize()
    screenRes = invalid

    if displaySize <> invalid and displaySize.w <> invalid and displaySize.h <> invalid
        screenRes = Str(displaySize.w).Trim() + "x" + Str(displaySize.h).Trim()
    end if

    setConfig({
        measurementId: params.measurementId
    })

    setOptions({
        appName: params.appName
        appVersion: appInfo.GetVersion()
        screenRes: screenRes
        clientId: deviceInfo.GetChannelClientId()
        docLocation: params.docLocation
        userLanguage: deviceInfo.GetCurrentLocale()
        customArgs: params.customArgs
        isFirstOpen: params.isFirstOpen
    })

    if params.userId <> invalid
      setUserId(params.userId)
    end if

    if params.userProperties <> invalid
      setUserProperties(params.userProperties)
    end if
end function

function setConfig(config as object)
    ' Config Properties
    ' - measurementId
    m.config = config
end function

sub setOptions(options as object)
    ' Options Properties
    ' - clientId
    ' - docTitle
    ' - docLocation
    ' - screenRes
    ' - appName
    ' - appVersion
    ' - userLanguage
    ' - origin
    ' - customArgs
    if options.customArgs = invalid
        options.customArgs = {}
    end if

    m.options = options
end sub

sub startTask()
    ' The only async method is "sendHttpRequest"
    ? "ANALYTICS: The only async method is sendHttpRequest"
end sub

function start()
    customArgs = m.options.customArgs
    
    gaSessionId = getGaSessionId()
    gaSessionNumber = getGaSessionNumber()

    customArgs["sid"] = gaSessionId
    customArgs["sct"] = gaSessionNumber

    options = m.options
    options.customArgs = customArgs

    m.options = options

    m.pendingSessionStart = true
    m.pendingFirstVisit = false

    if isFirstOpen()
        m.pendingFirstVisit = true
    end if

    logEvent("page_view", {})

    m.timer.control = "start"
end function

function getGaSessionId() as integer
    return CreateObject("roDateTime").AsSeconds()
end function

function getGaSessionNumber() as integer
    registry = getRegistry()

    lastSessionNumber = registry.read("lastSessionNumber")

    newSessionNumber = 1

    if lastSessionNumber <> invalid and lastSessionNumber <> ""
        newSessionNumber = lastSessionNumber.toInt() + 1
    end if

    registry.write("lastSessionNumber", newSessionNumber.toStr())

    return newSessionNumber
end function

function getFirstOpenTimeSeconds() as integer
    registry = getRegistry()

    firstOpenTimeSeconds = registry.read("firstOpenTimeSeconds")

    if firstOpenTimeSeconds <> "" and firstOpenTimeSeconds <> invalid
        return firstOpenTimeSeconds.toInt()
    end if

    firstOpenTimeSeconds = CreateObject("roDateTime").AsSeconds()

    registry.write("firstOpenTimeSeconds", firstOpenTimeSeconds.toStr())

    return firstOpenTimeSeconds
end function

function isFirstOpen() as boolean
    if m.options.isFirstOpen <> invalid
        return m.options.isFirstOpen
    end if

    registry = getRegistry()

    if registry.exists("firstOpenMark")
        return false
    else
        registry.write("firstOpenMark", "ok")
        return true
    end if
end function

function getRegistry() as object
    return CreateObject("roRegistrySection", "googleanalytics")
end function

sub logUserEngagement()
    logEvent("user_engagement", {
        _et: m.userEngagementIntervalSeconds * 1000
    })

    logEvent("app_time", {
        time_difference: m.userEngagementIntervalSeconds * 1000
    })
end sub

function send(codedEvent as Object)
    nowTime = CreateObject("roDateTime")

    queryArgs = {}
    
    if m.options.customArgs <> invalid
        for each key in m.options.customArgs
            queryArgs[key] = m.options.customArgs[key]
        end for
    end if

    m.sessionHitsCount = m.sessionHitsCount + 1

    queryArgs.v = 2
    queryArgs.tid = m.config.measurementId
    queryArgs.cid = m.options.clientId
    queryArgs._p = Rnd(CreateObject("roDateTime").AsSeconds())
    queryArgs._s = m.sessionHitsCount

    if m.options.userLanguage <> invalid
        queryArgs.ul = LCase(m.options.userLanguage)
    end if

    if m.options.appName <> invalid
        queryArgs.an = m.options.appName
    end if

    if m.options.appVersion <> invalid
        queryArgs.av = m.options.appVersion
    end if

    if m.options.docTitle <> invalid
        queryArgs.dt = m.options.docTitle
    end if

    if m.options.docLocation <> invalid
        queryArgs.dl = m.options.docLocation
    end if

    if m.options.screenRes <> invalid
        queryArgs.sr = m.options.screenRes
    end if

    if codedEvent.en = "page_view"
        queryArgs.seg = 0

        if m.pendingFirstVisit = true
            queryArgs._fv = 2
            m.pendingFirstVisit = false
        end if
    
        if m.pendingSessionStart = true
            queryArgs._ss = 2
            m.pendingSessionStart = false
        end if
    else
        queryArgs.seg = 1
    end if

    for each key in codedEvent
        queryArgs[key] = codedEvent[key]
    end for

    queryParts = []

    for each key in queryArgs
        queryParts.Push(key.EncodeUriComponent() + "=" + convertToString(queryArgs[key]).EncodeUriComponent())
    end for

    queryString = queryParts.Join("&")

    m.lastEventTime = nowTime

    request = CreateObject("roSGNode", "GoogleAnalytics")
    request.functionName = "sendHttpRequest"
    request.httpMethod = "POST"
    request.httpUrl = m.endpoint + "?" + queryString
    request.control = "RUN"
end function

function sendHttpRequest()
  method = m.top.httpMethod
  url = m.top.httpUrl

  ? "[ANALYTICS] " method " " url

  port = CreateObject("roMessagePort")

  request = CreateObject("roUrlTransfer")
  request.SetCertificatesFile("common:/certs/ca-bundle.crt")
  request.SetMessagePort(port)
  request.SetRequest(method)
  request.SetUrl(url)

  requestSent = request.AsyncPostFromString("")

  if (requestSent)
    msg = wait(0, port)

    if (type(msg) = "roUrlEvent")
      statusCode = msg.GetResponseCode()

      if statusCode < 200 or statusCode > 299
        ? "ANALYTICS: ERROR - " msg.GetFailureReason()
      end if
    end if
  end if
end function

function parseEvent(eventName as String, eventParams as Object) as object
    codedEvent = {
        en: eventName.Replace(" ", "_")
    }

    if m.options.origin <> invalid
        codedEvent["ep.origin"] = m.options.origin
    end if

    for each key in eventParams
        value = eventParams[key]

        if value <> invalid
            codedKey = "ep." + key
            codedValue = value

            if GetInterface(value, "ifInt") <> invalid or GetInterface(value, "ifFloat") <> invalid or GetInterface(value, "ifDouble") <> invalid
                codedKey = "epn." + key
            end if

            if Type(codedValue) = "roInt" Or Type(codedValue) = "roInteger"
                if key.Instr("_") = -1
                    ' convert integers to double (for custom parameters only)
                    codedValue = Cdbl(codedValue)
                end if
            end if

            if key = "ec" or key = "_et"
                codedKey = key
            end if

            if key = "currency"
                codedKey = "cu"
            end if

            codedEvent[codedKey] = codedValue
        end if
    end for

    return codedEvent
end function

sub logEvent(eventName as String, eventParams as Object)
    codedEvent = parseEvent(eventName, eventParams)

    if m.userId <> invalid and m.userId <> ""
        codedEvent.uid = m.userId
    end if

    if m.screenName <> invalid and m.screenName <> ""
        codedEvent["ep.screen_name"] = m.screenName
    end if

    if m.codedUserProperties <> invalid
        for each key in m.codedUserProperties
            codedEvent[key] = m.codedUserProperties[key]
        end for
    end if

    send(codedEvent)
end sub

sub logScreenView(screenName as String)
    params = {
        firebase_screen: screenName
    }

    if m.screenName <> invalid and m.screenName <> ""
        params.firebase_previous_screen = m.screenName
    end if

    if m.screenName <> screenName
        setCurrentScreen(screenName)
        logEvent("screen_view", params)
    end if
end sub

function parseUserProperties(userProperties as Object) as Object
    codedUserProperties = {}

    for each key in userProperties
        value = userProperties[key]
        if value <> invalid
            if key.Instr("up.") = 0 or key.Instr("upn.") = 0
                ' already coded
                codedKey = key
            else
                codedKey = "up." + key

                if GetInterface(value, "ifInt") <> invalid or GetInterface(value, "ifFloat") <> invalid or GetInterface(value, "ifDouble") <> invalid
                    codedKey = "upn." + key
                end if
            end if

            codedUserProperties[codedKey] = value
        end if
    end for

    return codedUserProperties
end function

sub setUserProperties(userProperties as Object)
    m.codedUserProperties = parseUserProperties(userProperties)

    firstOpenTimeSeconds = getFirstOpenTimeSeconds()

    m.codedUserProperties["up.id"] = m.userId
    m.codedUserProperties["upn.first_open_time"] = (roundFloatToInteger(firstOpenTimeSeconds / 3600) * 3600).ToStr() + "000"
end sub

sub setUserId(userId)
    m.userId = userId
end sub

sub setCurrentScreen(screenName as String)
    m.screenName = screenName
end sub

sub resetAnalyticsData ()
    m.screenName = invalid
    m.userId = invalid
    m.codedUserProperties = invalid
end sub

function convertToString(variable As Dynamic) As String
    if GetInterface(variable, "ifIntOps") <> invalid then
        return variable.ToStr()
    else if Type(variable) = "roInt" Or Type(variable) = "roInteger" Then
        return Str(variable).Trim()
    else if Type(variable) = "roFloat" Or Type(variable) = "Float" Then
        strValue = Str(variable).Trim()
  
        if strValue.Instr(".") = -1
          strValue = strValue + ".0"
        end if
  
        return strValue
    else if Type(variable) = "roBoolean" Or Type(variable) = "Boolean" Then
        if variable = True Then
            return "true"
        end If
        return "false"
    else if Type(variable) = "roString" Or Type(variable) = "String" Then
        Return variable
    else if variable = invalid then
        return ""
    else
        return Type(variable)
    end if
end function

function roundFloatToInteger(number as Float) as Integer
    truncateValue = Fix(number)
    decimalValue = number - truncateValue
  
    if decimalValue > 0.5
      return truncateValue + 1
    else
      return truncateValue
    end if  
  end function
