# Install & run

The watch face is an app that gets installed on the watch. Opening the app shows
the watch face.
This is how I install and run the app on my watch:
- on the iPhone: privacy & security -> turn on developer mode
- on the watch: privacy & security -> turn on developer mode
- open the project on XCode
- make sure the watch is listed in the list of devices (view with cmd+shift+2)
  if it is not visible, steps to try:
    - plug your phone to your computer using a cable
    - make sure bluetooth is on on the phone, the watch, and the computer
    - make sure the phone, the watch, and the computer are all on the same
      network
    - (!!!careful for data loss at this step!!!) unpair / pair again the watch
      to the phone
- select the watch as the run destination
- inside `TerminalFace Watch App/ContentView.swift`, under `Constants`, make
  sure that preview mode is not set to true:
```swift
static let previewMode = true  // make sure this is not set to false
```
- run the app: in XCode, under Product -> Run (cmd + r)
  this will make the app run on the watch. if you close it, you should be able
  to find it in the app grid.
