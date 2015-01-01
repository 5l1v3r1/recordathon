class Recording
  constructor: (@element, @audio = null) ->
    if @audio?
      @showCropper()
    else
      @showStartButton()
  
  beginRecording: (button) ->
    button.disabled = true
    # setup the recorder
    r = new window.WAVRecorder()
    r.onError = (err) => @showError err
    r.onDone = =>
      @audio = r.getWAV()
      @showCropper()
    r.onStart = =>
      # setup the button
      @element.innerHTML = ''
      button = document.createElement 'button'
      button.innerHTML = 'End recording'
      button.addEventListener 'click', -> r.stop()
      @element.appendChild button
    # Start recording
    r.start()
  
  showCropper: ->
    @element.innerHTML = ''
    console.log 'data is', @audio.base64()
  
  showError: (err) ->
    @element.innerHTML = 'Error: ' + err + '&nbsp;&nbsp;'
    button = document.createElement 'button'
    button.innerHTML = 'Dismiss'
    button.addEventListener 'click', => @showStartButton()
    @element.appendChild button
  
  showStartButton: ->
    @element.innerHTML = ''
    button = document.createElement 'button'
    button.innerHTML = 'Start recording'
    button.addEventListener 'click', => @beginRecording button
    @element.appendChild button

window.Recording = Recording