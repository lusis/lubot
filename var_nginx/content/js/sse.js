var evtSource;
var sse_url = window.location.protocol+"//"+window.location.hostname+":"+window.location.port+"/api/logs";
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

function sseConnect() {
  evtSource = new EventSource(sse_url);
  $("#sse_connect_status").attr("onclick", "sseDisconnect();");
  evtSource.addEventListener("keepalive", function(e) {
    console.log("Keepalive from server: "+e.data);
    $("#sse_connect_status").css("color", "green");
  })
  evtSource.addEventListener("logevent", function(e) {
    var evt = JSON.parse(e.data);
    sseLog("["+evt.timestamp+"] ("+evt.sender+") "+evt.message);
  })
  evtSource.onerror = function(e) {
    switch(evtSource.readyState) {
      case 0:
        $("#sse_connect_status").attr("onclick", "sseDisconnect();");
        $("#sse_connect_status").css("color", "yellow");
        break;
      case 1:
        $("#sse_connect_status").attr("onclick", "sseDisconnect();");
        $("#sse_connect_status").css("color", "green");
        break;
      case 2:
        $("#sse_connect_status").attr("onclick", "sseConnect();");
        $("#sse_connect_status").css("color", "red");
        break;
      default:
        $("#sse_connect_status").attr("onclick", "sseDisconnect();");
        $("#sse_connect_status").css("color", "green");
    }
  }

  return false;
}

function sseDisconnect() {
  $("#sse_connect_status").css("color", "red");
  $("#sse_connect_status").attr("onclick", "sseConnect();");
  evtSource.close();
}

function sseLog(text) {
  $("#logwindow").append(document.createTextNode(text+"\n"));
  $("#logwindow").scrollTop = $("#logwindow").scrollHeight;
	console.log(text);
  	return false;
}
