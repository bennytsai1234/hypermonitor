let timer = null;

self.onmessage = (e) => {
    if (e.data.action === 'start') {
        if (timer) clearInterval(timer);
        timer = setInterval(() => {
            self.postMessage('tick');
        }, e.data.interval || 10000);
    } else if (e.data.action === 'stop') {
        if (timer) clearInterval(timer);
        timer = null;
    }
};
