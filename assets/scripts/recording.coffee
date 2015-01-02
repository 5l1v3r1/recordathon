class Cropper
  constructor: (@sound, @start, @end) ->
    @element = document.createElement 'div'
    @canvas = document.createElement 'canvas'
    @canvas.width = 400
    @canvas.height = 70
    @canvas.style.backgroundColor = '#DDD'
    @context = @canvas.getContext '2d'
    @element.appendChild @canvas
    @histogram = @sound.histogram @canvas.width
    @draw()
    # Drag events
    draggingBar = -1
    @canvas.addEventListener 'mousedown', (evt) =>
      leftBar = @canvas.width * @start / @sound.header.getDuration()
      rightBar = @canvas.width * @end / @sound.header.getDuration()
      if Math.abs(evt.offsetX - leftBar) < 10
        draggingBar = 0
      else if Math.abs(evt.offsetX - rightBar) < 10
        draggingBar = 1
    @canvas.addEventListener 'mouseup', ->
      draggingBar = -1
    @canvas.addEventListener 'mousemove', (evt) =>
      return if draggingBar is -1
      newVal = @sound.header.getDuration() * evt.offsetX / @canvas.width
      if draggingBar is 0
        @start = newVal
      else
        @end = newVal
      if @end < @start
        [@end, @start] = [@start, @end]
        draggingBar = 1 - draggingBar
      @draw()
  
  draw: ->
    @context.clearRect 0, 0, @canvas.width, @canvas.height
    scalar = @canvas.width / @histogram.length
    middle = @canvas.height / 2
    @context.fillStyle = '#F00'
    for h, i in @histogram
      x = scalar * i
      h *= middle
      @context.fillRect x, middle - h, scalar, h * 2
    @context.fillStyle = '#000'
    leftBar = @canvas.width * @start / @sound.header.getDuration()
    rightBar = @canvas.width * @end / @sound.header.getDuration()
    for x in [leftBar, rightBar]
      @context.fillRect x - 1, 0, 2, @canvas.height
    return
  
  cropped: ->
    res = new Audio()
    res.src = 'data:audio/wav;base64,' + @sound.crop(@start, @end).base64()
    return res

class Recording
  constructor: (@element, audio = null, start = 0, end = 0, name = null) ->
    @cropper = null
    @nameField = null
    if audio?
      @showCropper audio, start, end, name
    else
      @showStartButton()
    audio = null
    document.addEventListener 'keypress', (evt) =>
      return if @nameField? and @nameField == document.activeElement
      return if not @cropper?
      return if evt.keyCode isnt 0x20
      if audio?
        audio.pause()
        audio = null
      else
        audio = @cropper.cropped()
        audio.play()
        audio.addEventListener 'ended', ->
          audio = null
  
  beginRecording: (button) ->
    button.disabled = true
    # Setup the recorder
    r = new window.jswav.Recorder()
    r.onerror = (err) => @showError err
    r.ondone = (sound) =>
      @showCropper sound, 0, sound.header.getDuration()
    r.onstart = =>
      # Setup the button
      @element.innerHTML = ''
      button = document.createElement 'button'
      button.innerHTML = 'End recording'
      button.addEventListener 'click', -> r.stop()
      @element.appendChild button
    # Start recording
    r.start()
  
  showCropper: (sound, start, end, name = '') ->
    @cropper = new Cropper sound, start, end
    @nameField = document.createElement 'input'
    @nameField.value = name
    reset = document.createElement 'button'
    reset.addEventListener 'click', =>
      @cropper = null
      @nameField = null
      @showStartButton()
    reset.innerHTML = 'Reset'
    upload = document.createElement 'button'
    upload.addEventListener 'click', => @upload()
    upload.innerHTML = 'Save'
    @element.innerHTML = '<label>Name:</label>'
    @element.appendChild @nameField
    @element.appendChild @cropper.element
    @element.appendChild reset
    @element.appendChild upload
  
  showError: (err) ->
    @element.innerHTML = 'Error: ' + err + '&nbsp;&nbsp;'
    button = document.createElement 'button'
    button.innerHTML = 'Dismiss'
    button.addEventListener 'click', =>
      if @cropper?
        @showCropper @cropper.sound, @cropper.start, @cropper.end,
          @nameField.value
      else
        @showStartButton()
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
      data: @cropper.sound.base64()
      cut:
        start: @cropper.start
        end: @cropper.end
    return dict
  
  upload: ->
    @element.innerHTML = 'Uploading...'
    req = null
    if window.XMLHttpRequest?
      req = new window.XMLHttpRequest()
    else if window.ActiveXObject?
      req = new window.ActiveXObject "Microsoft.XMLHTTP"
    else return @showError 'Unable to make AJAX request'
    req.onreadystatechange = =>
      if req.readyState is 4
        if req.status is 200
          window.location = '/'
        else
          @showError 'Failed to upload.'
    req.open 'POST', '/upload', true
    req.setRequestHeader 'Content-Type', 'application/json'
    req.send JSON.stringify @toUpload()

window.Recording = Recording