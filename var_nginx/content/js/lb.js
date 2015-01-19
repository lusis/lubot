var plugin_base_url = window.location.protocol+"//"+window.location.hostname+":"+window.location.port+"/api/plugins";
var run_api_url = plugin_base_url+"/run/";
var help_api_url = plugin_base_url+"/help/";
var plugin_list_url = plugin_base_url+"/list";
var plugin_stats_url = plugin_base_url+"/stats/";
var plugin_details_url = plugin_base_url+"/details/";

function getPlugins(callback) {
  console.log("Getting plugin list");
  $.ajax({
    type: "GET",
    url: plugin_details_url+"all",
    success: callback,
    error: function(res){ console.log("failed to pull list of plugins: "+JSON.stringify(res));}
  });
}

function getPluginStats(plugin, callback) {
  console.log("Getting stats for plugin: "+plugin);
  $.ajax({
    type: "GET",
    url: plugin_stats_url+plugin,
    success: callback,
    error: function(res){ console.log("failed to pull stats for plugin "+plugin+": "+JSON.stringify(res));}
  });
}

function toggleTestRow(plugin) {
  $("#plugin_"+plugin+"_test_input_row").toggle();
  $("#plugin_"+plugin+"_test_output").toggle();
}

function toggleHelpRow(plugin) {
  $("#plugin_"+plugin+"_help_output_row").toggle();
  runPluginHelp(plugin);
}
function getPluginsCallback(res) {
  _.each(res, function(thing) {
    var rowId = "plugin_"+thing.id
    var nameId = "plugin_name_"+thing.id
    var versionId = "plugin_version_"+thing.id
    var errorsId = "plugin_errors_"+thing.id
    var execsId = "plugin_executions_"+thing.id
    var testId = "plugin_test_"+thing.id
    var helpId = "plugin_help_"+thing.id
    var testInputRowId = "plugin_"+thing.id+"_test_input_row"
    var testInputId = "plugin_"+thing.id+"_test_input"
    var testOutputRowId = "plugin_"+thing.id+"_test_output_row"
    var testOutputId = "plugin_"+thing.id+"_test_output"
    var helpOutputId = "plugin_"+thing.id+"_help_output"
    var helpOutputRowId = "plugin_"+thing.id+"_help_output_row"
    var plugin_row = [
      "<tr id="+rowId+">",
      "<td id="+nameId+">"+thing.id+"</td>",
      "<td id="+versionId+"></td>",
      "<td id="+errorsId+"></td>",
      "<td id="+execsId+"></td>",
      "<td id="+testId+"><span onclick=\"toggleTestRow('"+thing.id+"');\" class='glyphicon glyphicon-comment'></span></td>",
      "<td id="+helpId+"><span onclick='toggleHelpRow(\""+thing.id+"\");' class='glyphicon glyphicon-question-sign'></span></td>",
      "</tr>",
      "<tr id="+testInputRowId+" style='display: none;'>",
      "<td></td><td colspan='3'><input id="+testInputId+" style='width: 90%;' type='text' placeholder='<botname> "+thing.id+" <options>'><span onclick='displayPluginRun(\""+thing.id+"\");' class='glyphicon glyphicon-play'></td><td></td>",
      "</tr>",
      "<tr id="+testOutputRowId+" style='display: none;'>",
      "<td></td><td id="+testOutputId+" style='display: none;' colspan='3' id='"+testOutputId+"'></td><td></td>",
      "</tr>",
      "<tr id="+helpOutputRowId+" style='display: none; width:100%;'><td></td><td id="+helpOutputId+" colspan='4'></td><td></td></tr>"
    ].join("\n");
    if ($("#"+rowId).length) {
      console.log("plugin row exists");
    } else {
      $("#active_plugins").append(plugin_row);
    }
    $("#"+versionId).html(thing.version);
    getPluginStats(thing.id, function(res){
	    console.log("Got stats results: "+JSON.stringify(res));
	    $("#"+errorsId).html(res.errors);
	    $("#"+execsId).html(res.executions);
    });
  })
}

function populatePluginTable() {
}

function getPluginLogs(plugin) {

}

function getPluginDetails(plugin) {
}

function runPlugin(plugin, text) {
	var plugin_url = run_api_url+plugin;
	$.ajax({
		type: "POST",
		data: JSON.stringify({channel: "webconsole", user: "consoleuser", text: text}),
		url: plugin_url,
		success: function(res){ populatePluginResults(plugin, res);},
		error: function(res){ populatePluginResults(plugin, "failed to run plugin: "+plugin, true);},
	});
}

function populatePluginResults(plugin, res, err) {
  var runOutputElement = "#plugin_"+plugin+"_test_output";
  $(runOutputElement).empty();
  $(runOutputElement+"_row").show();
  var response = "";
  if(res.attachments) {
    response = res.attachments[0].fallback;
  } else {
    response = res.text;
  }
  if(err) {
	  $(runOutputElement).addClass("alert alert-danger");
	  $(runOutputElement).attr("role", "alert");
  }else{
	  $(runOutputElement).addClass("alert alert-success");
	  $(runOutputElement).removeClass("alert-danger");
  }
  $(runOutputElement).append("<pre style='width: 100%;'>"+response+"</pre>");
}

function displayPluginRun(plugin) {
  var runInputElement = "#plugin_"+plugin+"_test_input";
  var runOutputElement = "#plugin_"+plugin+"_test_output";
  var command = $(runInputElement).val();
  console.log("Input: "+$(runInputElement).val());
  runPlugin(plugin, command);
}

function displayPluginHelp(text, plugin) {
  $("#plugin_"+plugin+"_help_output").append("<pre>"+text+"</pre>");
}

function runPluginHelp(plugin) {
  if($("#plugin_"+plugin+"_help_output").is(":visible")) {
    console.log("Ajax call happening");
    $("#plugin_"+plugin+"_help_output").empty();
    var plugin_url = help_api_url+plugin;
    $.ajax({
      type: "GET",
      async: false,
      url: plugin_url,
      success: function(res){ displayPluginHelp(res.msg, plugin)},
      error: function(res){console.log("failed to run plugin: "+plugin)},
    });
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
