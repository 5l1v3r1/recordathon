(function() {
  
  function Recorder(configuration) {
    this.player = null;
    this.name = null;
    this.element = document.getElementById('recording');
    if (configuration) {
      this.showPlayer(configuration);
    } else {
      this.showStart();
    }
    this._setupEvents();
  }
  
  Recorder.prototype.record = function() {
    this.element.innerHTML = 'Waiting...';
    var r = new window.jswav.Recorder();
    
    r.onerror = function(err) {
      this.showError(err);
    }.bind(this);
    
    r.ondone = function(sound) {
      this.showPlayer({name: '', sound: sound, start: 0,
        end: sound.header.getDuration()});
    }.bind(this);
    
    r.onstart = function() {
      this.element.innerHTML = '';
      var button = document.createElement('button');
      button.innerHTML = 'Stop recording';
      button.addEventListener('click', r.stop.bind(r));
      this.element.appendChild(button);
    }.bind(this);
    
    r.start();
  };
  
  Recorder.prototype.reshowPlayer = function() {
    this.element.innerHTML = '';
    
    // Create input field
    var inputLine = document.createElement('div');
    inputLine.innerHTML = 'Name: ';
    inputLine.appendChild(this.name);
    
    // Reset button
    var reset = document.createElement('button');
    reset.innerHTML = 'Reset';
    reset.addEventListener('click', function() {
      this.player = null;
      this.name = null;
      this.showStart();
    }.bind(this));
    
    // Save button
    var save = document.createElement('button');
    save.innerHTML = 'Save';
    save.addEventListener('click', this.save.bind(this));
    
    // Add elements
    this.element.appendChild(inputLine);
    this.element.appendChild(this.player.canvas);
    this.element.appendChild(reset);
    this.element.appendChild(document.createTextNode(' '));
    this.element.appendChild(save);
  };
  
  Recorder.prototype.showError = function(err) {
    this.element.innerHTML = 'Error: ' + err + '<br>';
    var button = document.createElement('button');
    button.innerHTML = 'OK';
    button.addEventListener('click', function() {
      if (this.player) {
        this.reshowPlayer();
      } else {
        this.showStart();
      }
    }.bind(this));
    this.element.appendChild(button);
  };
  
  Recorder.prototype.showPlayer = function(c) {
    this.player = new window.recordathon.Player(c.sound, c.start, c.end);
    this.player.canvas.style.display = 'block';
    this.name = document.createElement('input');
    this.name.value = c.name;
    this.reshowPlayer();
  };
  
  Recorder.prototype.showStart = function() {
    this.element.innerHTML = '';
    var button = document.createElement('button');
    button.innerHTML = 'Start recording';
    button.addEventListener('click', this.record.bind(this));
    this.element.appendChild(button);
  };
  
  Recorder.prototype.save = function() {
    this.element.innerHTML = 'Uploading...';
    var req = null;
    if (window.XMLHttpRequest) {
      req = new window.XMLHttpRequest();
    } else if (window.ActiveXObject) {
      req = new window.ActiveXObject("Microsoft.XMLHTTP");
    } else {
      return this.showError('Cannot make AJAX request.');
    }
    req.onreadystatechange = function() {
      if (req.readyState === 4) {
        if (req.status === 200) {
          window.location = '/'
        } else {
          this.showError('Failed to upload');
        }
      }
    }.bind(this);
    req.open('POST', '/upload', true);
    req.setRequestHeader('Content-Type', 'application/json');
    var object = {name: this.name.value, data: this.player.sound.base64(),
      cut: {start: this.player.start, end: this.player.end}};
    req.send(JSON.stringify(object));
  };
  
  Recorder.prototype._setupEvents = function() {
    document.addEventListener('keypress', function(evt) {
      code = evt.which;
      if ('number' !== typeof code) {
        code = evt.keyCode;
      }
      if (!this.player || !this.name || code !== 0x20 ||
          document.activeElement === this.name) {
        return;
      }
      this.player.playPause();
    }.bind(this));
  };
  
  if (!window.recordathon) {
    window.recordathon = {};
  }
  window.recordathon.Recorder = Recorder;
  
})();