// Quake Screen control add-in
// Receives 320x200 palette indexed frames from AL, draws them on a canvas, plays the sound events and sends input back.
(function quakeScreen() {
    'use strict';
    if (!document.getElementById('controlAddIn')) {
        // not in the DOM yet: start when the page has loaded
        window.addEventListener('load', quakeScreen);
        return;
    }

    var W = 320, H = 200;
    var root = document.getElementById('controlAddIn');
    root.innerHTML =
        '<div class="quake-wrap" id="quakeWrap">' +
        '  <canvas id="quakeCanvas" width="320" height="200" tabindex="0"></canvas>' +
        '  <div class="quake-status" id="quakeStatus">' +
        '    <div id="quakeStatusText">Loading Quake...</div>' +
        '  </div>' +
        '  <div class="quake-fps" id="quakeFps"></div>' +
        '  <div class="quake-info" id="quakeInfo"></div>' +
        '  <div class="quake-toast" id="quakeToast"></div>' +
        '</div>';

    var canvas = document.getElementById('quakeCanvas');
    // WebGL draws the frame at the display resolution through an upscaling filter (End cycles the filters),
    // the 2D canvas (stretched by the browser) is the fallback
    var renderer = doomCreateRenderer(canvas, W, H);
    var ctx = renderer ? null : canvas.getContext('2d');
    var image = ctx ? ctx.createImageData(W, H) : new ImageData(W, H);
    var pixels = new Uint32Array(image.data.buffer);
    var rgba = new Uint8Array(image.data.buffer);
    var toastBox = document.getElementById('quakeToast');
    var toastTimer = 0;
    if (renderer) {
        try {
            var savedFilter = window.localStorage.getItem('quake.filter');
            if (savedFilter !== null) renderer.mode = +savedFilter;
        } catch (e) { }
    }
    var palette = new Uint32Array(256);
    var statusBox = document.getElementById('quakeStatus');
    var statusText = document.getElementById('quakeStatusText');
    var fpsBox = document.getElementById('quakeFps');
    var infoBox = document.getElementById('quakeInfo');
    var showStats = false;                    // performance overlay, toggled with F12
    var wrap = document.getElementById('quakeWrap');

    var running = false;
    var inFlight = 0;           // requests sent and not answered yet
    var maxInFlight = 2;        // 2 = send input right away even while a batch is being rendered
    // send the next request before the answer to the previous one arrives (F8). Off: BC handles one request per
    // session at a time, so in BC the early request waits for the whole round trip of the previous one (measured:
    // the same frames per second, twice the round trip)
    var pipeline = false;
    var serverEstimate = 0;     // ms the server takes per request (average)
    var sendTimer = 0;
    var reqQueue = [];          // latency info per request in flight, in order
    var events = [];
    var lastRequest = 0;
    var mouseDX = 0, mouseDY = 0;
    var frames = 0, fpsStart = performance.now();
    var keysDown = {};
    var indexes = new Uint8Array(W * H);     // current frame as palette indexes
    var queue = [];                           // frames waiting to be shown
    var batchSize = 1;                        // frames rendered per server round trip
    var frameDelay = 100;                     // ms between shown frames (adapts to the server speed)
    var nextShow = 0;
    var lastBatch = 0;
    var serverMs = 0, roundTripMs = 0;
    var pressTime = 0;
    var lagText = 'press a key to measure input lag';

    for (var i = 0; i < 256; i++) palette[i] = 0xff000000;

    // ---------------------------------------------------------------- layout
    function resize() {
        // Quake's 320x200 is displayed with a 4:3 aspect ratio, like on a VGA monitor
        var w = wrap.clientWidth, h = wrap.clientHeight;
        var cw = w, ch = Math.floor(w * 3 / 4);
        if (ch > h) { ch = h; cw = Math.floor(h * 4 / 3); }
        canvas.style.width = cw + 'px';
        canvas.style.height = ch + 'px';
        if (renderer) renderer.resize(cw, ch);
    }

    function showToast(text) {
        toastBox.textContent = text;
        toastBox.style.opacity = '1';
        clearTimeout(toastTimer);
        toastTimer = setTimeout(function () { toastBox.style.opacity = '0'; }, 1500);
    }

    function nextFilter() {
        if (!renderer) {
            showToast('Upscaling filters need WebGL');
            return;
        }
        renderer.mode = renderer.mode + 1;
        showToast('Filter: ' + renderer.modes[renderer.mode] + '  (F11)');
        try { window.localStorage.setItem('quake.filter', String(renderer.mode)); } catch (e) { }
    }
    window.addEventListener('resize', resize);
    resize();

    // ---------------------------------------------------------------- frames
    function setPalette(b64) {
        var p = atob(b64);
        for (var i = 0; i < 256; i++) {
            palette[i] = 0xff000000 | (p.charCodeAt(i * 3 + 2) << 16) | (p.charCodeAt(i * 3 + 1) << 8) | p.charCodeAt(i * 3);
        }
    }

    // a frame is "palette!rows!sounds": the palette when it changed, the changed rows, the sound events
    function applyFrame(frame) {
        var parts = frame.split('!');
        var pal = parts[0];
        var rows = parts[1] || '';
        if (parts[2]) playSounds(parts[2]);
        if (pal) setPalette(pal);
        if (rows) {
            var bin = atob(rows);
            for (var off = 0; off + 321 <= bin.length; off += 321) {
                var base = bin.charCodeAt(off) * W;
                for (var x = 0; x < W; x++) indexes[base + x] = bin.charCodeAt(off + 1 + x);
            }
        }
    }

    function showFrame(entry) {
        applyFrame(entry.data);
        for (var i = 0; i < W * H; i++) pixels[i] = palette[indexes[i]];
        if (renderer) renderer.draw(rgba);
        else ctx.putImageData(image, 0, 0);
        frames++;
        var now = performance.now();
        if (entry.req) {
            var r = entry.req;
            lagText = 'input lag ' + Math.round(now - r.press) + 'ms = waiting to send ' + Math.round(r.sent - r.press) +
                ' + round trip ' + Math.round(r.arrived - r.sent) + ' (server ' + r.server + ') + display ' + Math.round(now - r.arrived);
        }
        if (now - fpsStart > 1000) {
            fpsBox.textContent = (frames * 1000 / (now - fpsStart)).toFixed(1) + ' fps | batch ' + batchSize +
                ' (F9/F10) | pipelining ' + (pipeline ? 'on' : 'off') + ' (F8) | server ' + serverMs + 'ms | round trip ' + Math.round(roundTripMs) + 'ms' +
                (audio && audio.state === 'running' ? '' : ' | sound: press a key') + '\n' + lagText;
            frames = 0;
            fpsStart = now;
        }
    }

    function animate() {
        var now = performance.now();
        if (queue.length && now >= nextShow) {
            // first frame of a batch is shown right away, the rest spread until the next batch is expected
            showFrame(queue.shift());
            nextShow = now + (queue.length > batchSize ? frameDelay / 2 : frameDelay);
        }
        requestAnimationFrame(animate);
    }
    requestAnimationFrame(animate);

    window.DrawFrames = function (batch, ms) {
        var now = performance.now();
        var list = batch ? batch.split(';') : [];
        var req = reqQueue.shift() || null;
        serverMs = ms;
        if (req && req.sent) roundTripMs = now - req.sent;
        if (ms > 0) serverEstimate = serverEstimate ? serverEstimate * 0.8 + ms * 0.2 : ms;
        if (lastBatch && list.length) {
            var interval = now - lastBatch;
            frameDelay = frameDelay * 0.7 + (interval / list.length) * 0.3;
        }
        lastBatch = now;
        // frames of the previous batch that were not shown yet are outdated now: apply them without showing
        while (queue.length) applyFrame(queue.shift().data);
        nextShow = 0;
        inFlight = Math.max(0, inFlight - 1);
        if (req && req.press) {
            req.arrived = now;
            req.server = ms;
        }
        for (var i = 0; i < list.length; i++) queue.push({ data: list[i], req: i === 0 && req && req.press ? req : null });
        if (running && inFlight === 0) requestFrames();   // keep the server busy
        else scheduleNext();
    };

    // ---------------------------------------------------------------- sound
    // Quake only reports what plays on its channels; the WAV files of the PAK are played here.
    var audio = null;
    var wavs = {};          // WAV name (relative to sound/) -> raw bytes
    var buffers = {};       // WAV name -> { buffer, rate }
    var sfxNames = {};      // Quake's sound number -> WAV name
    var channels = {};      // Quake channel -> { src, left, right }

    function initAudio() {
        if (!audio) {
            var AC = window.AudioContext || window.webkitAudioContext;
            if (!AC) return;
            audio = new AC();
        }
        // browsers only allow audio after a user gesture: called again on key presses and clicks
        if (audio.state === 'suspended') audio.resume();
    }

    window.LoadAudio = function (data) {
        wavs = {};
        buffers = {};
        var list = data ? data.split('|') : [];
        for (var i = 0; i < list.length; i++) {
            var colon = list[i].indexOf(':');
            var bin = atob(list[i].substring(colon + 1));
            var bytes = new Uint8Array(bin.length);
            for (var j = 0; j < bin.length; j++) bytes[j] = bin.charCodeAt(j);
            wavs[list[i].substring(0, colon)] = bytes;
        }
        initAudio();
    };

    // PCM WAV (8 bit unsigned or 16 bit signed, mono) -> AudioBuffer
    function wavBuffer(name) {
        if (buffers[name] !== undefined) return buffers[name];
        var b = wavs[name];
        buffers[name] = null;
        if (!b || !audio) return null;
        var dv = new DataView(b.buffer, b.byteOffset, b.byteLength);
        var rate = 11025, width = 1, channelCount = 1, dataPos = -1, dataLen = 0;
        for (var p = 12; p + 8 <= b.length;) {
            var id = String.fromCharCode(b[p], b[p + 1], b[p + 2], b[p + 3]);
            var len = dv.getInt32(p + 4, true);
            if (len < 0 || len > b.length - p - 8) break;
            if (id === 'fmt ') {
                channelCount = dv.getInt16(p + 10, true);
                rate = dv.getInt32(p + 12, true);
                width = dv.getInt16(p + 22, true) / 8;
            } else if (id === 'data') {
                dataPos = p + 8;
                dataLen = len;
            }
            p += 8 + ((len + 1) & ~1);
        }
        if (dataPos < 0 || channelCount !== 1 || (width !== 1 && width !== 2)) return null;
        var count = Math.floor(dataLen / width);
        if (!count) return null;
        var buffer = audio.createBuffer(1, count, rate);
        var out = buffer.getChannelData(0);
        for (var i = 0; i < count; i++)
            out[i] = width === 1 ? (b[dataPos + i] - 128) / 128 : dv.getInt16(dataPos + i * 2, true) / 32768;
        buffers[name] = { buffer: buffer, rate: rate };
        return buffers[name];
    }

    function stopChannel(ch) {
        var c = channels[ch];
        if (!c) return;
        delete channels[ch];
        try { c.src.stop(); } catch (e) { }
    }

    function setVolumes(c, left, right) {
        c.left.gain.value = left / 255;
        c.right.gain.value = right / 255;
    }

    // s,channel,sound,left,right,loopstart = start | u,channel,left,right = volume | x,channel = stop | n,sound,name = WAV of a sound
    function playSounds(list) {
        var evs = list.split('|');
        var sfxOn = audio && audio.state === 'running';
        for (var i = 0; i < evs.length; i++) {
            var e = evs[i].split(',');
            if (e[0] === 'n') {
                sfxNames[e[1]] = e.slice(2).join(',');
                continue;
            }
            if (!sfxOn) continue;
            if (e[0] === 's') {
                stopChannel(e[1]);
                var wav = wavBuffer(sfxNames[e[2]]);
                if (!wav) continue;
                var c = { src: audio.createBufferSource(), left: audio.createGain(), right: audio.createGain() };
                var merger = audio.createChannelMerger(2);
                c.src.buffer = wav.buffer;
                var loopStart = +e[5];
                if (loopStart >= 0) {
                    // Quake's loop start is in samples at 11025 Hz
                    c.src.loop = true;
                    c.src.loopStart = loopStart / 11025;
                    c.src.loopEnd = wav.buffer.duration;
                }
                c.src.connect(c.left);
                c.src.connect(c.right);
                c.left.connect(merger, 0, 0);
                c.right.connect(merger, 0, 1);
                merger.connect(audio.destination);
                setVolumes(c, +e[3], +e[4]);
                (function (ch, entry) {
                    entry.src.onended = function () { if (channels[ch] === entry) delete channels[ch]; };
                })(e[1], c);
                channels[e[1]] = c;
                c.src.start();
            } else if (e[0] === 'u') {
                if (channels[e[1]]) setVolumes(channels[e[1]], +e[2], +e[3]);
            } else if (e[0] === 'x') {
                stopChannel(e[1]);
            }
        }
    }

    window.ShowInfo = function (info) {
        infoBox.textContent = info;
    };

    window.ShowStatus = function (message) {
        statusText.textContent = message;
        statusBox.style.display = message ? 'flex' : 'none';
    };

    // a request that takes long (loading a level runs inside a single frame): say so instead of looking frozen
    var waitShown = false;
    setInterval(function () {
        // the oldest request that has not been answered yet
        var waited = reqQueue.length && reqQueue[0].sent ? performance.now() - reqQueue[0].sent : 0;
        if (running && inFlight > 0 && waited > 2000) {
            ShowStatus('Quake is loading in Business Central... ' + Math.round(waited / 1000) + 's');
            waitShown = true;
        } else if (waitShown) {
            ShowStatus('');
            waitShown = false;
        }
    }, 500);

    window.Start = function () {
        ShowStatus('');
        running = true;
        lastRequest = performance.now();
        canvas.focus();
        requestFrames();
    };

    function requestFrames() {
        if (!running || inFlight >= maxInFlight) return;
        if (mouseDX || mouseDY) {
            events.push([2, mouseDX, mouseDY]);
            mouseDX = 0;
            mouseDY = 0;
        }
        var now = performance.now();
        var elapsed = Math.round(now - lastRequest);
        lastRequest = now;
        var input = JSON.stringify(events);
        events = [];
        reqQueue.push(pressTime ? { press: pressTime, sent: now } : { sent: now });
        pressTime = 0;
        inFlight++;
        // without pipelining, an extra request for immediate input renders a single frame
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('RequestFrames', [input, elapsed, inFlight > 1 && !pipeline ? 1 : batchSize]);
        scheduleNext();
    }

    // Pipelining: the server handles one request at a time, and a round trip costs more than the server's work
    // (network, the BC client). So the next request is sent while one is still in flight, timed to reach the
    // server when it finishes the current one: one server time after the previous request was sent (the network
    // delay is the same for both). Sending it as late as that keeps its input fresh.
    function scheduleNext() {
        if (sendTimer) {
            clearTimeout(sendTimer);
            sendTimer = 0;
        }
        if (!running || !pipeline || inFlight !== 1 || !serverEstimate) return;
        // serverEstimate is the server time of a whole request (all frames of the batch); 10ms early for jitter
        var due = lastRequest + serverEstimate - 10 - performance.now();
        if (due <= 0) requestFrames();
        else sendTimer = setTimeout(function () { sendTimer = 0; requestFrames(); }, due);
    }

    // a key or button was pressed: remember when, and send it right away
    function inputNow() {
        if (!pressTime) pressTime = performance.now();
        if (maxInFlight > 1) requestFrames();
    }

    // ---------------------------------------------------------------- keyboard
    // browser key -> Quake key number (keys.h)
    var KEYMAP = {
        'Tab': 9, 'Enter': 13, 'NumpadEnter': 13, 'Escape': 27, 'Space': 32, 'Backspace': 127,
        'ArrowUp': 128, 'ArrowDown': 129, 'ArrowLeft': 130, 'ArrowRight': 131,
        'AltLeft': 132, 'AltRight': 132, 'ControlLeft': 133, 'ControlRight': 133, 'ShiftLeft': 134, 'ShiftRight': 134,
        'F1': 135, 'F2': 136, 'F3': 137, 'F4': 138, 'F5': 139, 'F6': 140, 'F7': 141, 'F8': 142,
        'Insert': 147, 'Delete': 148, 'PageDown': 149, 'PageUp': 150, 'Home': 151, 'End': 152, 'Pause': 255,
        'Backquote': 96, 'Minus': 45, 'Equal': 61, 'BracketLeft': 91, 'BracketRight': 93, 'Backslash': 92,
        'Semicolon': 59, 'Quote': 39, 'Comma': 44, 'Period': 46, 'Slash': 47
    };

    function quakeKey(e) {
        if (KEYMAP[e.code] !== undefined) return KEYMAP[e.code];
        if (/^Key[A-Z]$/.test(e.code)) return e.code.charCodeAt(3) + 32;   // 'a'..'z'
        if (/^Digit[0-9]$/.test(e.code)) return e.code.charCodeAt(5);       // '0'..'9'
        return -1;
    }

    function setStatsVisible(visible) {
        showStats = visible;
        fpsBox.style.display = visible ? '' : 'none';
        infoBox.style.display = visible ? '' : 'none';
    }
    setStatsVisible(false);

    function keyEvent(k, down) {
        if (down) {
            if (keysDown[k]) return;   // ignore auto repeat
            keysDown[k] = true;
            events.push([0, k]);
            inputNow();
        } else {
            if (!keysDown[k]) return;
            keysDown[k] = false;
            events.push([1, k]);
        }
    }

    canvas.addEventListener('keydown', function (e) {
        initAudio();
        // F9-F12 belong to the add-in: batch size, upscaling filter, statistics
        if (e.code === 'F12') {
            setStatsVisible(!showStats);
            e.preventDefault();
            return;
        }
        if (e.code === 'F11') {
            nextFilter();
            e.preventDefault();
            return;
        }
        if (e.code === 'F8') {
            pipeline = !pipeline;
            showToast('Pipelining ' + (pipeline ? 'on' : 'off'));
            scheduleNext();
            e.preventDefault();
            return;
        }
        if (e.code === 'F9' || e.code === 'F10') {
            batchSize = Math.max(1, Math.min(10, batchSize + (e.code === 'F10' ? 1 : -1)));
            showToast('Frames per request: ' + batchSize);
            e.preventDefault();
            return;
        }
        var k = quakeKey(e);
        if (k < 0) return;
        e.preventDefault();
        keyEvent(k, true);
    });
    canvas.addEventListener('keyup', function (e) {
        var k = quakeKey(e);
        if (k < 0) return;
        e.preventDefault();
        keyEvent(k, false);
    });
    canvas.addEventListener('blur', function () {
        for (var k in keysDown) {
            if (keysDown[k]) events.push([1, parseInt(k, 10)]);
        }
        keysDown = {};
    });

    // ---------------------------------------------------------------- mouse
    canvas.addEventListener('click', function () {
        initAudio();
        canvas.focus();
        if (running && document.pointerLockElement !== canvas && canvas.requestPointerLock) canvas.requestPointerLock();
    });
    document.addEventListener('mousemove', function (e) {
        if (document.pointerLockElement !== canvas) return;
        mouseDX += e.movementX;
        mouseDY += e.movementY;
    });
    // mouse buttons are keys in Quake: K_MOUSE1 200, K_MOUSE2 201, K_MOUSE3 202
    function mouseKey(button) { return button === 2 ? 201 : (button === 1 ? 202 : 200); }
    canvas.addEventListener('mousedown', function (e) {
        if (document.pointerLockElement !== canvas) return;
        keyEvent(mouseKey(e.button), true);
        e.preventDefault();
    });
    canvas.addEventListener('mouseup', function (e) {
        if (document.pointerLockElement !== canvas) return;
        keyEvent(mouseKey(e.button), false);
        e.preventDefault();
    });
    // the wheel: K_MWHEELUP 239, K_MWHEELDOWN 240 (a press and a release)
    canvas.addEventListener('wheel', function (e) {
        if (document.pointerLockElement !== canvas) return;
        var k = e.deltaY < 0 ? 239 : 240;
        events.push([0, k], [1, k]);
        inputNow();
        e.preventDefault();
    });
    canvas.addEventListener('contextmenu', function (e) { e.preventDefault(); });

    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlReady', []);
}());
