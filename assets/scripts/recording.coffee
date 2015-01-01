class Cropper
  constructor: (@audio, @start, @end) ->
    @element = document.createElement 'div'
    @canvas = document.createElement 'canvas'
    @canvas.width = 400
    @canvas.height = 100
    @context = @canvas.getContext '2d'
    @element.appendChild @canvas
    @graph = @audio.volumeAverages 200
    @draw()
  
  draw: ->
    scalar = @canvas.width / @graph.length
    middle = @canvas.height / 2
    @context.fillStyle = '#000'
    for h, i in @graph
      x = scalar * i
      h *= middle
      @context.fillRect x, middle - h, scalar, h * 2

  sound: -> @audio.crop @start, @end

class Recording
  constructor: (@element, @audio = null, cropStart = 0, cropEnd = 0) ->
    @cropper = null
    @nameField = null
    if @audio?
      @showCropper cropStart, cropStop
    else
      @showStartButton()
  
  beginRecording: (button) ->
    button.disabled = true
    # setup the recorder
    r = new window.jswav.Recorder()
    r.onError = (err) => @showError err
    r.onDone = (audio) =>
      @audio = audio
      @showCropper 0, @audio.duration
    r.onStart = =>
      # setup the button
      @element.innerHTML = ''
      button = document.createElement 'button'
      button.innerHTML = 'End recording'
      button.addEventListener 'click', -> r.stop()
      @element.appendChild button
    # Start recording
    r.start()
  
  showCropper: (start, end) ->
    @cropper = new Cropper @audio, @start, @end
    @nameField = document.createElement 'input'
    @nameField.value = 'Untitled' + Math.random()
    @element.innerHTML = ''
    @element.appendChild @nameField
    @element.appendChild @cropper.element
  
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
  
  toUpload: ->
    return null if not @cropper?
    dict =
      name: @nameField.value
      data: @cropper.sound().base64
      cut:
        start: @cropper.start
        end: @cropper.end

window.Recording = Recording