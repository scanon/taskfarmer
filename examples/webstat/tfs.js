(function($) {

    /* You can use code like this to explore the confusing interfaces */
    /*
      var msg = "$(this) = ";
      for( var prop in $(this)) { msg += "<p>" + prop + ":" + $(this)[prop] + "</p>\n";}
      alert(msg);
    */
    /*
     * This started of as a copy of Yams.  Thanks to Andrew Uselton.
     *
     *   The TFS constructor function initializes the tfs object
     * and initializes some of the core values for the jqplot object
     * it will use.  Once it has been instantiated a subsequent call
     * its init() function gets things going.
     * The init() function invokes the get_data() function
     * one intial time and then schedules a recurring 
     */
    function Tfs() {
	/*
	 *   The tfsOptions object controls tfs-specific display and
	 * control options.
	 */
	this.tfsOptions = {
	    /*
	     *  The "interval" value determines how often the interval
	     * timer is invoked to poll the server for new data. Right
	     * now it is hard coded but it will become a control
	     * shortly. All of the display controls are going to be
	     * gathered into a single object.  The "interval" value
	     * also determines how often the interval timer is
	     * invoked.
	     *
	     * N.B. This value does not have an effect on how often
	     * the data acquizition software introduces new data into
	     * the DB. That is now controlled by a cron job, which can
	     * be invoked no more frequently than once aver 60
	     * seconds. Similarly, the values.php script has a
	     * corresponding setting that it uses to determine how big
	     * to initially set the window, if that value is not
	     * supplied in the AJAX request. The default value of the 
	     * is set as bins*interval there and here, as well.
	     */
	    interval : 10,
	    unused : 0         // so I'm not always worrying about the comma
	};
	this.source = "stats.js";
	/*
	 *   The jqplotOptions is what controls a jqplot. Only very generic 
	 * and unchanging values get initialized here.
	 */
	this.jqplotOptions = {
	    legend:{show:true}, 
	    title:"Title",
	    axes:
	    {
		xaxis:
		{
		    label:"Time",  
		    show: true,
		    autoscale:true,
		    renderer:$.jqplot.DateAxisRenderer, 
		    tickOptions:{formatString:"%H:%M"},
		},
		yaxis:
		{
		    show: true,
		    autoscale:true,
		    tickOptions:{formatString:"%d"},
		}
	    },
	    series:[
		{
		    label:"stat time",  
		    color:"#ff0000", 
		    showLine:true, 
		    markerOptions:
		    {
			size: 1, 
			style:"circle"
		    }
		},
	    ],
	    cursor:
	    {
		tooltipLocation:"nw", 
		zoom:true, 
		constrainZoomTo:"x", 
		showTooltip:false, 
		clickReset:true
	    }
	};
	/*
	 *   The values array keeps all the data that tfs knows about
	 * from the DB. Right now all data is reaquired at each "interval",
	 * but eventually this will be maintained an updated incrementally.
	 * The data is a array of one or more time series. Each time series
	 * is itself and array of observations. Each observation, in turn, 
	 * is just a two element array with the pair <timestamp, value>, 
	 * where the timestamp is a string in the form of a PHP call:
	 * "date('Y-m-d H:i:s', <seconds in epoch>);". Thus each values 
	 * array entry takes three subscripts to get at the atomic data.
	 *   The values array recampitulates the data elements from all the
	 * sources array entries that are not empty of data.
	 */
	this.values = new Array();
	/*
	 *   The valsObj array is the result of parseJSON() of the JSON string
	 * returned by the call to the values.php server-side script. 
	 */
	this.valsObj = new Array();
	/*
	 *   If the values.php server-side script gets more than this many
	 * samples from the database, it will start binning them.
	 */
	this.bins = 60;
	/*
	 *   The "window" value is how many seconds are currently in the 
	 * graph's x-axis.
	 */
	this.window = this.tfsOptions.interval * this.bins;
	/*
	 *   When the data values are binned they can be averaged in the bin or
	 * one of the max, min, first, or last value can be selected. This sets
	 * up the selector response.
	 */
	this.setTimeNow = function()
	{
	    /*
	     * endDay is the seconds in epoch of the midnight prior to the 
	     * end of the window. this.nowTime is the seconds in epoch at the
	     * time the object is initialized. this.nowDay is the seconds
	     * in epoch of the midnight prior to this.nowTime. this.nowDate
	     * and this.nowTime will be updated any time new data comes from
	     * server with a timestamp larger/later than what this.now* already
	     * have.
	     */
	    var nowTimeDate = new Date();
	    $.tfs.nowTime = parseInt(nowTimeDate.getTime()/1000);
	    var nowDayDate = new Date(nowTimeDate.getFullYear(), 
				      nowTimeDate.getMonth(), 
				      nowTimeDate.getDate());
	    $.tfs.nowDay = parseInt(nowDayDate.getTime()/1000);
	    $.tfs.endDay = $.tfs.nowDay;
	    /*
	     * endWindow is the seconds after midnight of the end of the window.
	     */
	    $.tfs.endWindow = parseInt(nowTimeDate.getTime()/1000) - $.tfs.endDay;
	}

	this.makeDialog = function()
	{
	    $("#help").dialog({
		width: 600,
		modal: true,
		show: 'blind',
		hide: 'explode',
		autoOpen: false
	    });
	}
	/*
	 *   init() makes a first call to get data from the server and display
	 * it, then schedules a recurring event to do so in the future at "interval" 
	 * seconds. 
	 */
	this.init = function()
	{
	    this.setTimeNow();
            this.source=$.url.param("source")
            $(this.makeDialog);
	    /*
	     *   Note that these two invocations need to be registered as callbacks
	     * (i.e. use the $(callback) technique). I'm not sure why that is, since the
	     * init() function is not itself being called until 'document' is 'ready'. 
	     */
	    /*
	     *   The "current" value indicates if the graph is tracking currently
	     * observed values. The "interval" setting is maintained in seconds, but
	     * the setInterval() method wants milliseconds.
	     */
	    $.tfs.current = true;

	    this.intervalId = setInterval("$.tfs.get_data()", this.tfsOptions.interval*1000);
	    $.tfs.get_data();
	}
	/*
	 *   The timestamps returned by the values.php script are text in the format
	 * yyyy-MM-dd hh:mm:ss. In order to compare them with the window and other 
	 * times in the tfs object I need to convert to seconds in epoch. 
	 */
	this.sie = function(timestamp)
	{
	    var year   = timestamp.substring(0,4);
	    var month  = timestamp.substring(5,7);
	    var day    = timestamp.substring(8,10);
	    var hour   = timestamp.substring(11,13);
	    var minute = timestamp.substring(14,16);
	    var second = timestamp.substring(17,19);
	    /* The Date interface wants zero-based months */
	    var aDate = new Date(year, month - 1, day, hour, minute, second);
	    return(parseInt(aDate.getTime()/1000));
	}
	this.padNum = function(x)
	{
	    return((x < 10) ? "0" + x.toString() : x.toString());
	}
	/*
	 *   I also need to be able to convert seconds in epoch back to the 
	 * time format as used in the sources object retrned by values.php.
	 */
	this.makeTime = function(sie)
	{
	    var aDate = new Date(sie*1000);
	    return(aDate.getFullYear().toString() + "-" +
		   $.tfs.padNum(aDate.getMonth() + 1) + "-" +
		   $.tfs.padNum(aDate.getDate()) + " " +
		   $.tfs.padNum(aDate.getHours()) + ":" +
		   $.tfs.padNum(aDate.getMinutes()) + ":" +
		   $.tfs.padNum(aDate.getSeconds()));
	}
	/*
	 *   The graph function gets called by the completion handler for the 
	 * recurring event that polls the server for data. With the data in hand,
	 * parsed into the values array, the details of the jqplot jqplotOptions are 
	 * updated and the graph is redesplayed.
	 */
	this.graph = function()
	{
	    var colors = ["#ff0000", "#0000ff", "#00ff00", "#880000", "#000088", "#008800"];
	    /*
	     *   Initialize latestTime to the current window end in case there is no 
	     * data in the returned sources. Initialize earliestTime to the window beginning,
	     * but note that we'll only use this if there is no data at all.
	     */
            this.jqplotOptions.title = "Bytes In History";
	    this.jqplotOptions.series[0].label = "Bytes In"
	    this.plot = $.jqplot( "data", [this.valsObj.counters.h_bytesin], this.jqplotOptions );
	    this.plot.redraw();
	    window.defaultStatus = this.jqplotOptions.title;
	}

	this.jobtable = function()
	{
            var rows = [];
            var maxrows=1000;
            var i=0;
	    for( var h in this.valsObj.jobs ){
	       var job=this.valsObj.jobs[h];
               if (i < maxrows){
                 rows.push ([ job.id, job.finish-job.start, job.bytesin, job.bytesout, job.ident ]); 
                 i++;
               }
            }
	    $('#jobTable').dataTable( {
		"bDestroy" : true,
		"aaData": rows,
		"aoColumns": [
			{ "sTitle": "Job" },
			{ "sTitle": "Time", "sClass": "right" },
			{ "sTitle": "Bytes In" , "sClass": "right" },
			{ "sTitle": "Bytes Out", "sClass": "right" },
			{ "sTitle": "Ident" }
		] } );	

	}

	/* 
	 *   get_data() is the target of the recurring event. It composes and 
	 * sends the the request for data to the server's "values.php" script.
	 * It sets the completion event handler to parse the JSON string 
	 * returned and invoke "graph()".
	 */
	this.get_data = function()
	{
	    var needsComma = false;
	    var sourcesString = "";
	    $.get($.tfs.source,
		  function(data){
		      $.tfs.valsObj = [];
		      var values_object;
		      //document.getElementById("debugId").innerHTML = data;
		      try
		      {
			  /*
			   *   In my experience if you use eval, it
			   * wants a ";" at the end of the eval and
			   * actually returns the array of sources. If
			   * you use parseJSON there must be no ";"
			   * and it returns an object whose only
			   * property is "sources", which has an array
			   * as its value. Finally, eval is fine with
			   * just text for the properties, but JSON
			   * requires that properties be in
			   * double-quotes. parseJSON is safer because
			   * it will prevent any side effects if
			   * someone tries to inject code into the
			   * returned string.
			   */
			  //var some_values = eval(data);
			  values_object = $.parseJSON(data);
		      }
		      catch( error )
		      {
			  //document.getElementById("debugId").innerHTML = some_values;
			  //document.getElementById("debugId").innerHTML = error;
		      }
		      $.tfs.valsObj=values_object;
			  /*
			   * FIXME: What am I actually doing with the bins and binsize?
			   */
	  	      $("#TotalCount").text( values_object.counters.count );
		      $("#TotalBytesIn").text( values_object.counters.bytesin );
		      $("#TotalBytesOut").text( values_object.counters.bytesout );
		      //document.getElementById("debugId").innerHTML = $.tfs.valsObj[0].data;
		      $.tfs.graph();
		      $.tfs.jobtable();
		  });
	    return false;
	}

	/*
	 *  The "page.html" interface has a button for "pause". All it does 
	 * is invoke this fuction to cancel the regularly scheduled event.
	 *  Pressing "pause" while there is no scheduled event has no effect.
	 */
	this.pause = function()
	{
	    if( this.intervalId )
	    {
		clearInterval(this.intervalId);
	    }
	    this.intervalId = undefined;
	}
	/*
	 *   The "page.html" interface also has a "resume" button, which calls this 
	 * function. If the regularly scheduled event has been suspended then it is 
	 * restarted. Pressing "resume" while the event is already sheduled has no effect.
	 * Since there is a delay before the next scheduled event a get_data() is
	 * called immmediately. As in init() the interval, which is in seconds, is 
	 * multiplied by 1000 to so the setInterval() method gets milliseconds.
	 */
	this.resume = function()
	{
	    if( ! this.intervalId )
	    {
		this.intervalId = setInterval("$.tfs.get_data()", this.tfsOptions.interval * 1000);
	    }
	}
	/*
	 *   When the interface first starts up, and any time the "Current Data" 
	 * button is pressed, the date gets put back to today, the window gets put
	 * back to "now - window" to "now", and "current" is set to true. If the 
	 * the data retrieval interval timer is not set then it is started again,
	 * which will also issue an immedaite get_data().
	 */
	this.currentData = function()
	{
	    $.tfs.setTimeNow();
	    $.tfs.get_data();
	}
	this.doHelp = function()
	{
	    $("#help").dialog('open');
	    return false;
	}
    }
    /*
     *   When the script is read in a new tfs object is added to the jquery object.
     */
    $.tfs = new Tfs();
    /*
     * This is the standard jquery plug-in invokation convention.
     */
})(jQuery);

/*
 *   Set the init() function to be called when the document has completed loading.
 */
$(document).ready($.tfs.init());
