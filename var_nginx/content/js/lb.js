var prefix = "ws:";
if (window.location.protocol === "https") prefix = "wss:";
var lbws_url = prefix+"//"+window.location.hostname+":"+window.location.port+"/lbws";
var etcd_proxy_url = window.location.protocol+"//"+window.location.hostname+":"+window.location.port+"/etcd_proxy?url=";
var ws = null;

function addNodetoEtcd(node) {
	var etcd_url = window.location.protocol+"//"+window.location.hostname+":5001/v2/keys/lbs/backends/node"+node;
	$.ajax({
		type: "PUT",
		async: false,
		url: etcd_proxy_url+etcd_url,
		processData: false,
		data: "value=127.0.0.1:314"+node,
		success: function(res){ console.log("Adding backend "+node)},
		error: function(res){console.log("failed to add backend "+node)},
	});
}
function addAdditionalNodes() {
	var remaining_nodes = [2, 3, 4, 5];
	for (var iter in remaining_nodes) {
		console.log("Current iteration: "+remaining_nodes[iter].toString());
		addNodetoEtcd(remaining_nodes[iter].toString());
	}
}

function connect() {
  if (ws !== null) return log('already connected');
  ws = new WebSocket(lbws_url);
  ws.onopen = function () {
    log('connected');
  };
  ws.onerror = function (error) {
    log(error);
  };
  ws.onmessage = function (e) {
    log('recv: ' + e.data);
    var tableData = new Array();
    if (e.data === "connected") {
      //Do nothing
    } else {
      if (_.isUndefined(e.data)) {
        return false;
      } else {
        var j = JSON.parse(e.data);
        _.each(j, function(value, key) {
          log(key+" = "+value);
          updateTable(key, value);
        })
        return false;
      }
    }
  };
  ws.onclose = function () {
    log('disconnected');
    ws = null;
  };
  return false;
}
function disconnect() {
  if (ws === null) return log('already disconnected');
  ws.close();
  return false;
}
function send() {
  if (ws === null) return log('please connect first');
  ws.send(text);
  return false;
}

function updateTable(k,v) {
  // Check if there's an existing row
  var tdid = k.split('/').slice(-1).pop()
  if ($('tr#'+tdid).length > 0) {
    console.log("Updating existing row: "+k);
    if ($("#current_"+tdid).length > 0) {
      console.log("This is the active backend: "+tdid)
      $('tr#'+tdid).addClass('success');
    }
    $('td#'+tdid+"_name").text(k);
    $('td#'+tdid+"_address").text(v);
  } else {
    if ($("#current_"+tdid).length > 0) {
      $('#loadbalancers').append("<tr id="+tdid+" class='success'><td id="+tdid+"_name>"+k+"</td><td id="+tdid+"_address>"+v+"</td></tr>");
    } else {
      $('#loadbalancers').append("<tr id="+tdid+"><td id="+tdid+"_name>"+k+"</td><td id="+tdid+"_address>"+v+"</td></tr>");
    }
  }
}

function log(text) {
  console.log(text);
  return false;
}
