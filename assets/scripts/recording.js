// Generated by CoffeeScript 1.7.1
(function() {
  var RawRecorder, Recording, WAVData, getUserMedia;

  RawRecorder = (function() {
    function RawRecorder() {
      this.buffers = [];
      this.sampleCount = 0;
      this.sampleRate = 0;
      this.stream = null;
      this.stopped = false;
      this.onDone = null;
      this.onError = null;
      this.onStart = null;
    }

    RawRecorder.prototype.getWAVData = function() {
      return WAVData.generate(this.buffers, this.sampleCount, this.sampleRate);
    };

    RawRecorder.prototype.start = function() {
      return getUserMedia((function(_this) {
        return function(err, stream) {
          if (_this.stopped) {
            stream.stop();
            return;
          }
          if (err != null) {
            return typeof _this.onError === "function" ? _this.onError(err) : void 0;
          }
          _this.stream = stream;
          return _this._handleStream();
        };
      })(this));
    };

    RawRecorder.prototype.stop = function() {
      this.stopped = true;
      if (this.stream != null) {
        return this.stream.stop();
      }
    };

    RawRecorder.prototype._handleStream = function() {
      var AudioContext, context, processor, source;
      AudioContext = window.AudioContext || window.webkitAudioContext;
      context = new AudioContext();
      source = context.createMediaStreamSource(this.stream);
      processor = context.createScriptProcessor(16384, 1, 1);
      processor.onaudioprocess = (function(_this) {
        return function(evt) {
          var data;
          if (_this.sampleRate === 0) {
            _this.sampleRate = Math.round(evt.inputBuffer.sampleRate);
          }
          data = evt.inputBuffer.getChannelData(0);
          _this.buffers.push(data);
          _this.sampleCount += data.length;
          return evt.outputBuffer = evt.inputBuffer;
        };
      })(this);
      source.connect(processor);
      processor.connect(context.destination);
      this.stream.onended = (function(_this) {
        return function() {
          source.disconnect(processor);
          processor.disconnect(context.destination);
          return typeof _this.onDone === "function" ? _this.onDone() : void 0;
        };
      })(this);
      return typeof this.onStart === "function" ? this.onStart() : void 0;
    };

    return RawRecorder;

  })();

  Recording = (function() {
    function Recording(element, audio) {
      this.element = element;
      this.audio = audio != null ? audio : null;
      if (this.audio != null) {
        this.showCropper();
      } else {
        this.showStartButton();
      }
    }

    Recording.prototype.beginRecording = function(button) {
      var r;
      button.disabled = true;
      r = new RawRecorder();
      r.onError = (function(_this) {
        return function(err) {
          return _this.showError(err);
        };
      })(this);
      r.onDone = (function(_this) {
        return function() {
          _this.audio = r.getWAVData();
          return _this.showCropper();
        };
      })(this);
      r.onStart = (function(_this) {
        return function() {
          _this.element.innerHTML = '';
          button = document.createElement('button');
          button.innerHTML = 'End recording';
          button.addEventListener('click', function() {
            return r.stop();
          });
          return _this.element.appendChild(button);
        };
      })(this);
      return r.start();
    };

    Recording.prototype.showCropper = function() {
      this.element.innerHTML = '';
      return console.log('data is', this.audio.base64());
    };

    Recording.prototype.showError = function(err) {
      var button;
      this.element.innerHTML = 'Error: ' + err + '&nbsp;&nbsp;';
      button = document.createElement('button');
      button.innerHTML = 'Dismiss';
      button.addEventListener('click', (function(_this) {
        return function() {
          return _this.showStartButton();
        };
      })(this));
      return this.element.appendChild(button);
    };

    Recording.prototype.showStartButton = function() {
      var button;
      this.element.innerHTML = '';
      button = document.createElement('button');
      button.innerHTML = 'Start recording';
      button.addEventListener('click', (function(_this) {
        return function() {
          return _this.beginRecording(button);
        };
      })(this));
      return this.element.appendChild(button);
    };

    return Recording;

  })();

  WAVData = (function() {
    function WAVData(buffer, view) {
      this.buffer = buffer;
      this.view = view;
    }

    WAVData.prototype.base64 = function() {
      var binary, bytes, x, _i, _len;
      binary = '';
      bytes = new Uint8Array(this.buffer);
      for (_i = 0, _len = bytes.length; _i < _len; _i++) {
        x = bytes[_i];
        binary += String.fromCharCode(x);
      }
      return window.btoa(binary);
    };

    WAVData.prototype.crop = function(start, end) {
      var endIdx, maximum, rate, startIdx;
      maximum = view.getUint32(40) / 2;
      rate = view.getUint32(24);
      startIdx = Math.max(0, Math.min(start * rate, maximum));
      endIdx = Math.max(0, Math.min(end * rate, maximum));
      return WAVData.generateSub(this.view, start, end, rate);
    };

    WAVData.prototype.duration = function() {
      var rate, size;
      size = view.getUint32(40) / 2;
      rate = view.getUint32(24);
      return size / rate;
    };

    WAVData.generate = function(buffers, sampleCount, sampleRate) {
      var buffer, byteIdx, size, subList, view, x, _i, _j, _len, _len1;
      size = 44 + sampleCount * 2;
      buffer = new ArrayBuffer(size);
      view = new DataView(buffer);
      this._setupHeader(view, sampleCount, sampleRate);
      byteIdx = 44;
      for (_i = 0, _len = buffers.length; _i < _len; _i++) {
        subList = buffers[_i];
        for (_j = 0, _len1 = subList.length; _j < _len1; _j++) {
          x = subList[_j];
          view.setInt16(byteIdx, Math.round(x * 0x8000), true);
          byteIdx += 2;
        }
      }
      return new WAVData(buffer, view);
    };

    WAVData.generateSub = function(oldView, start, end, sampleRate) {
      var buffer, dest, sampleCount, size, source, view, _i, _ref, _ref1;
      sampleCount = end - start;
      size = 44 + sampleCount * 2;
      buffer = new ArrayBuffer(size);
      view = new DataView(buffer);
      this._setupHeader(view, sampleCount, sampleRate);
      dest = 44;
      for (source = _i = _ref = start * 2, _ref1 = end * 2; _ref <= _ref1 ? _i < _ref1 : _i > _ref1; source = _ref <= _ref1 ? ++_i : --_i) {
        view.setUint8(dest, oldView.getUint8(source));
        ++dest;
      }
      return new WAVData(buffer, view);
    };

    WAVData._setupHeader(function(view, sampleCount, sampleRate) {
      var size;
      size = 44 + sampleCount * 2;
      view.setUint32(0, 0x46464952, true);
      view.setUint32(4, size - 8, true);
      view.setUint32(8, 0x45564157, true);
      view.setUint32(12, 0x20746d66, true);
      view.setUint32(16, 0x10, true);
      view.setUint16(20, 1, true);
      view.setUint16(22, 1, true);
      view.setUint32(24, sampleRate, true);
      view.setUint32(28, sampleRate * 2, true);
      view.setUint16(32, 2, true);
      view.setUint16(34, 16, true);
      view.setUint32(36, 0x61746164, true);
      return view.setUint32(40, sampleCount * 2, true);
    });

    return WAVData;

  })();

  getUserMedia = function(cb) {
    var gum, key, keys, _i, _len;
    keys = ['getUserMedia', 'webkitGetUserMedia', 'mozGetUserMedia', 'msGetUserMedia'];
    gum = null;
    for (_i = 0, _len = keys.length; _i < _len; _i++) {
      key = keys[_i];
      if ((gum = navigator[key]) != null) {
        break;
      }
    }
    if (gum == null) {
      setTimeout((function() {
        return cb('getUserMedia unavailable', null);
      }), 10);
      return;
    }
    gum.call(navigator, {
      audio: true,
      video: false
    }, function(stream) {
      return cb(null, stream);
    }, function(err) {
      if (err != null) {
        return cb(err, null);
      } else {
        return cb('Unknown error', null);
      }
    });
  };

  window.Recording = Recording;

}).call(this);
