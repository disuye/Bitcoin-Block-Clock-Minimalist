const init = async () => {
    
    // Simple clock...
    
    setInterval(function() {
                clock();
                }, 200);
    
    function clock() {
        var timeNow = new Date();
        document.getElementById('clock').innerHTML = timeNow.toLocaleTimeString([], { hour12: false, });
    }
    
    // Update index.html page elements & status notification...

    const status = `status:&nbsp;`;
    const cursor = `<span class="cursor">&nbsp;&middot;<span>`;
    
    // Get the current tip height while waiting for the next ws = ...options: ['blocks'] to push...

    const { bitcoin: { blocks } } = mempoolJS({ hostname: 'mempool.space' });
    const blocksTipHeight = await blocks.getBlocksTipHeight();
    document.getElementById("block_height").textContent = JSON.stringify(blocksTipHeight, undefined, 2);
    
    if (blocks){
        const hash = await blocks.getBlockHeight({ height: blocksTipHeight });
        const blockNow = await blocks.getBlock({ hash });
        const blockTimeStamp = new Date(JSON.parse(blockNow.timestamp) * 1000).toLocaleTimeString([], { hour12: false, timeZoneName: 'short' });
        document.getElementById("time_stamp").textContent = blockTimeStamp;
        document.getElementById("status").innerHTML = status + "connected to <a href='https://mempool.space/'>mempool.space</a>";
        clearTimeout(checkcnx); // Trash the looping page reload (checkcnx is first defined in index.html)
    }
    
    // Open websocket...

    const { bitcoin: { websocket } } = mempoolJS({ hostname: 'mempool.space' });
    const ws = websocket.initClient({ options: ['blocks', 'stats'], }); // Other available options ['blocks', 'stats', 'mempool-blocks', 'live-2h-chart']
    
    // Do something if internet connection is interrupted...

    window.addEventListener('offline', function() {
                            const checkcnx = setTimeout(function(){
                                                        location.reload();
                                                    }, 10000);
                            document.getElementById("status").innerHTML = status + "connection offline";
                            });
    
    // Render new data...
    
    ws.addEventListener('message', function incoming({data}) {
                        const pushdata = JSON.parse(data.toString());
                        
                        // Push data arrives from const ws = ...options: ['blocks']. approx. every 5~15 minutes.
                        
                        if (pushdata.block) {
                        document.getElementById("block_height").textContent = JSON.parse(pushdata.block.height);
                        document.getElementById("time_stamp").textContent = new Date(JSON.parse(pushdata.block.timestamp) * 1000).toLocaleTimeString([], { hour12: false, timeZoneName: 'short' });
                        }
                        
                        });
    };
init();
