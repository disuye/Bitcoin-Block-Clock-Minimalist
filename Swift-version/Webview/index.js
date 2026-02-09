const init = async () => {
        
    // Design elements to render after DOM loaded...
    
    document.addEventListener('DOMContentLoaded', function show_stuff() {
        
        // Simple clock...

        setInterval(function() {
                    clock();
                    }, 250);
        
        function clock() {
            var timeNow = new Date().toLocaleTimeString([], { hour12: false, });
            document.getElementById('clock').innerHTML = timeNow;
        }
   
        // const "timeZoneOption" defined in BitcoinBlockClock.m when run as a screensaver; defined in index.html when run as web page...
        
        switch(timeZoneOption) {
            case "timeZoneCity":
            var timeZone = (Intl.DateTimeFormat().resolvedOptions().timeZone).replace(/_/g, ' ').replace(/\//g, '&nbsp;/\&nbsp;');
            break;
            case "timeZoneDisable":
            var timeZone = null;
            break;
            default:
                case "timeZoneAbbrv":
                var timeZone = (new Date().toLocaleTimeString([], { hour12: false, hour: '2-digit', minute: '2-digit', timeZoneName: 'short' })).slice(5);
                break;
        };
        document.getElementById('time_zone').innerHTML = timeZone;
    });

    
    // index.html design elements...

    const status = `status:&nbsp;`;
    const cursor = `<span class="cursor">&nbsp;&middot;<span>`;
    
    // Get the current block height while waiting for the next ws = ...options: ['blocks'] to push...

    const { bitcoin: { blocks } } = mempoolJS({ hostname: 'mempool.space' });
    const blocksTipHeight = await blocks.getBlocksTipHeight();
    const lastDigit = String(blocksTipHeight).slice(-1);
        if (lastDigit == 1) {
            var padding = "1.0vw";
        } else if (lastDigit == 3) {
            var padding = "2.2vw";
        } else if (lastDigit == 8 || lastDigit == 7 || lastDigit == 2) {
            var padding = "2.6vw";
        } else {
            var padding = "2.8vw";
        };
    document.getElementById('block_height').style.setProperty("padding-right", padding, "important");
    document.getElementById('block_height').textContent = JSON.stringify(blocksTipHeight, undefined, 2);
    
    if (blocks) {
        // Current block timestamp...
        const hash = await blocks.getBlockHeight({ height: blocksTipHeight });
        const blockNow = await blocks.getBlock({ hash });
        const blockTimeStamp = new Date(JSON.parse(blockNow.timestamp) * 1000).toLocaleTimeString([], { hour12: false, });
        document.getElementById('time_stamp').textContent = blockTimeStamp;
        document.getElementById('status').innerHTML = status + "connected to <a href='https://mempool.space/'>mempool.space</a>";
        clearTimeout(checkcnx); // Trash the looping page reload (checkcnx is first defined in index.html)
    };

    document.querySelector('body').style.setProperty("opacity", "1.0", "important");
    
    // Open websocket...

    const { bitcoin: { websocket } } = mempoolJS({ hostname: 'mempool.space' });
    const ws = websocket.initClient({ options: ['blocks', 'stats'], }); // Other available options ['blocks', 'stats', 'mempool-blocks', 'live-2h-chart']
    
    // Do something if internet connection is interrupted...

    window.addEventListener('offline', function() {
                            const checkcnx = setTimeout(function(){
                                                        location.reload();
                                                    }, 10000);
                            document.getElementById('status').innerHTML = status + "connection offline";
                    });
    
    // Render new data...
    
    ws.addEventListener('message', function incoming({data}) {
                        const pushdata = JSON.parse(data.toString());
                        
                        // Push data arrives from const ws = ...options: ['blocks']. approx. every 5~15 minutes.
                        
                        if (pushdata.block) {
                        // Update block height...
                        newBlockHeight = JSON.parse(pushdata.block.height);
                        const lastDigit = String(newBlockHeight).slice(-1);
                            if (lastDigit == 1) {
                                var padding = "1.0vw";
                            } else if (lastDigit == 3) {
                                var padding = "2.2vw";
                            } else if (lastDigit == 8 || lastDigit == 7 || lastDigit == 2) {
                                var padding = "2.6vw";
                            } else {
                                var padding = "2.8vw";
                            };
                            document.getElementById('block_height').style.setProperty("padding-right", padding, "important");
                        document.getElementById('block_height').textContent = newBlockHeight;
                        // Update block timestamp...
                        document.getElementById('time_stamp').textContent = new Date(JSON.parse(pushdata.block.timestamp) * 1000).toLocaleTimeString([], { hour12: false, });
                        }
                });
    };
init();
