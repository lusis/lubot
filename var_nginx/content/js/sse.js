var sse_url = window.location.protocol+"//"+window.location.hostname+":"+window.location.port+"/slack";
if (!String.prototype.startsWith) {
  Object.defineProperty(String.prototype, 'startsWith', {
    enumerable: false,
    configurable: false,
    writable: false,
    value: function(searchString, position) {
      position = position || 0;
      return this.lastIndexOf(searchString, position) === position;
    }
  });
}

function connect() {
  var evtSource = new EventSource(sse_url);
  evtSource.onmessage = function(e) {
    log(e.data);
  }
  return false;
}

function log(text) {
  var ta = document.getElementById('log');
  ta.appendChild(document.createTextNode(text+"\n"));
  ta.scrollTop = ta.scrollHeight;
  return false;
}
