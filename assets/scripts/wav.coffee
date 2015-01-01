class WAVRecorder
  constructor: ->
    @buffers = []
    @sampleCount = 0
    @sampleRate = 0
    @stream = null
    @stopped = false
    @onDone = null
    @onError = null
    @onStart = null
  
  getWAV: ->
    return WAV.generateBuffers @buffers, @sampleCount, @sampleRate
  
  start: ->
    getUserMedia (err, stream) =>
      if @stopped
        stream.stop()
        return
      return @onError? err if err?
      @stream = stream
      @_handleStream()
  
  stop: ->
    @stopped = true
    @stream.stop() if @stream?
  
  _handleStream: ->
    AudioContext = window.AudioContext or window.webkitAudioContext
    context = new AudioContext()
    source = context.createMediaStreamSource @stream
    processor = context.createScriptProcessor 16384, 1, 1
    processor.onaudioprocess = (evt) =>
      if @sampleRate is 0
        @sampleRate = Math.round evt.inputBuffer.sampleRate
      data = evt.inputBuffer.getChannelData 0
      @buffers.push data
      @sampleCount += data.length
      evt.outputBuffer = evt.inputBuffer
    source.connect processor
    processor.connect context.destination
    @stream.onended = =>
      source.disconnect processor
      processor.disconnect context.destination
      @onDone?()
    @onStart?()

class WAV
  constructor: (@buffer, @view) ->
  
  base64: ->
    binary = ''
    bytes = new Uint8Array @buffer
    for x in bytes
      binary += String.fromCharCode x
    return window.btoa binary
  
  crop: (start, end) ->
    maximum = view.getUint32(40) / 2
    rate = view.getUint32 24
    startIdx = Math.max 0, Math.min(start*rate, maximum)
    endIdx = Math.max 0, Math.min(end*rate, maximum)
    return WAV.generateSub @view, start, end, rate
  
  duration: ->
    size = view.getUint32(40) / 2
    rate = view.getUint32 24
    return size / rate
  
  @decodeBase64: (b64) ->
    raw = window.atob b64
    buffer = new ArrayBuffer raw.length
    bytes = new Uint8Array buffer
    for i in [0...raw.length]
      bytes[i] = raw.charCodeAt i
    view = new DataView buffer
    return new WAV buffer, view
  
  @generateBuffers: (buffers, sampleCount, sampleRate) ->
    # Create all the buffer info
    size = 44 + sampleCount*2
    buffer = new ArrayBuffer size
    view = new DataView buffer
    # Write the actual data
    @_setupHeader view, sampleCount, sampleRate
    byteIdx = 44
    for subList in buffers
      for x in subList
        view.setInt16 byteIdx, Math.round(x*0x8000), true
        byteIdx += 2
    # Return the result
    return new WAV buffer, view
  
  @generateSub: (oldView, start, end, sampleRate) ->
    sampleCount = end - start
    # Create buffer and view
    size = 44 + sampleCount*2
    buffer = new ArrayBuffer size
    view = new DataView buffer
    # Write the actual data
    @_setupHeader view, sampleCount, sampleRate
    dest = 44
    for source in [start*2...end*2]
      view.setUint8 dest, oldView.getUint8(source)
      ++dest
    # Return the result
    return new WAV buffer, view
  
  @_setupHeader: (view, sampleCount, sampleRate) ->
    size = 44 + sampleCount*2
    view.setUint32 0, 0x46464952, true
    view.setUint32 4, size-8, true
    view.setUint32 8, 0x45564157, true
    view.setUint32 12, 0x20746d66, true
    view.setUint32 16, 0x10, true
    view.setUint16 20, 1, true
    view.setUint16 22, 1, true
    view.setUint32 24, sampleRate, true
    view.setUint32 28, sampleRate*2, true
    view.setUint16 32, 2, true
    view.setUint16 34, 16, true
    view.setUint32 36, 0x61746164, true
    view.setUint32 40, sampleCount*2, true

getUserMedia = (cb) ->
  keys = ['getUserMedia', 'webkitGetUserMedia', 'mozGetUserMedia',
    'msGetUserMedia']
  gum = null
  for key in keys
    break if (gum = navigator[key])?
  if not gum?
    setTimeout (-> cb 'getUserMedia unavailable', null), 10
    return
  gum.call navigator, {audio: true, video: false},
    (stream) ->
      cb null, stream
    (err) ->
      if err?
        cb err, null
      else
        cb 'Unknown error', null
  return

window.WAVRecorder = WAVRecorder
window.WAV = WAV