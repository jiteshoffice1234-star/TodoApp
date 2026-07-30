/**
 * Ambient Sounds — Web Audio API generative sound engine
 * No external audio files needed. All sounds synthesized in real-time.
 *
 * Usage:
 *   AmbientSounds.start('rain');     // Start a sound
 *   AmbientSounds.setVolume(0.6);    // Master volume 0–1
 *   AmbientSounds.stop();            // Stop current sound
 *   AmbientSounds.getState();        // { type, playing, volume }
 */

const AmbientSounds = (() => {
  // ---- Core state ----
  let ctx = null;
  let masterGain = null;
  let currentNode = null;       // The active sound's root node (starts/stops this)
  let currentType = null;
  let isPlaying = false;
  let volume = 0.5;             // 0–1
  let cleanupFns = [];

  // ---- AudioContext lazy init ----
  function ensureCtx() {
    if (!ctx) {
      ctx = new (window.AudioContext || window.webkitAudioContext)();
      masterGain = ctx.createGain();
      masterGain.gain.value = volume;
      masterGain.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
  }

  // ---- Utilities ----
  function random(min, max) { return Math.random() * (max - min) + min; }

  // Create a buffer of white noise (2 seconds)
  function noiseBuffer(duration = 2) {
    const sr = ctx.sampleRate;
    const len = sr * duration;
    const buf = ctx.createBuffer(1, len, sr);
    const data = buf.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
    return buf;
  }

  // Create a looping noise source with optional filter
  function loopingNoise(filterOpts = null) {
    const src = ctx.createBufferSource();
    src.buffer = noiseBuffer();
    src.loop = true;
    let node = src;
    if (filterOpts) {
      const filter = ctx.createBiquadFilter();
      filter.type = filterOpts.type || 'lowpass';
      filter.frequency.value = filterOpts.freq || 1000;
      if (filterOpts.Q !== undefined) filter.Q.value = filterOpts.Q;
      if (filterOpts.gain !== undefined) filter.gain.value = filterOpts.gain;
      src.connect(filter);
      node = filter;
    }
    return { source: src, output: node };
  }

  // ---- Sound generators ----
  function createWhiteNoise() {
    const c = ensureCtx();
    const { source, output } = loopingNoise({ type: 'lowpass', freq: 12000 });
    const gain = c.createGain();
    gain.gain.value = 1;
    output.connect(gain);
    source.start();
    cleanupFns.push(() => { try { source.stop(); } catch (_) {} });
    return { output: gain, type: 'white' };
  }

  function createRain() {
    const c = ensureCtx();
    const merge = c.createGain();
    merge.gain.value = 1;

    // Layer 1: Heavy mid rain — bandpass filtered noise
    const l1 = loopingNoise({ type: 'bandpass', freq: 800, Q: 0.8 });
    const g1 = c.createGain(); g1.gain.value = 0.7;
    // Slow amplitude modulation for realistic rain
    const lfo1 = c.createOscillator(); lfo1.type = 'sine'; lfo1.frequency.value = 0.3;
    const lfoGain1 = c.createGain(); lfoGain1.gain.value = 0.25;
    lfo1.connect(lfoGain1); lfoGain1.connect(g1.gain);
    lfo1.start();
    l1.output.connect(g1); g1.connect(merge);
    cleanupFns.push(() => { try { l1.source.stop(); lfo1.stop(); } catch(_) {} });

    // Layer 2: High-pitched patter — highpass filtered noise
    const l2 = loopingNoise({ type: 'highpass', freq: 3000, Q: 0.5 });
    const g2 = c.createGain(); g2.gain.value = 0.3;
    const lfo2 = c.createOscillator(); lfo2.type = 'sine'; lfo2.frequency.value = 0.7;
    const lfoGain2 = c.createGain(); lfoGain2.gain.value = 0.15;
    lfo2.connect(lfoGain2); lfoGain2.connect(g2.gain);
    lfo2.start();
    l2.output.connect(g2); g2.connect(merge);
    cleanupFns.push(() => { try { l2.source.stop(); lfo2.stop(); } catch(_) {} });

    // Layer 3: Deep rumble — lowpass filtered noise
    const l3 = loopingNoise({ type: 'lowpass', freq: 200 });
    const g3 = c.createGain(); g3.gain.value = 0.4;
    l3.output.connect(g3); g3.connect(merge);
    cleanupFns.push(() => { try { l3.source.stop(); } catch(_) {} });

    return { output: merge, type: 'rain' };
  }

  function createOcean() {
    const c = ensureCtx();
    const merge = c.createGain();

    // Main wave: noise through a lowpass filter with LFO on cutoff
    const src = loopingNoise();
    const filter = c.createBiquadFilter();
    filter.type = 'lowpass';
    filter.Q.value = 1.0;
    // LFO slowly sweeps the cutoff between ~80–800 Hz for a wave feel
    const lfo = c.createOscillator(); lfo.type = 'sine'; lfo.frequency.value = 0.12;
    const lfoGain = c.createGain(); lfoGain.gain.value = 360; // sweep range
    const lfoOffset = c.createGain(); lfoOffset.gain.value = 440; // center freq
    lfo.connect(lfoGain); lfoGain.connect(filter.frequency);
    lfoOffset.connect(filter.frequency);
    lfo.start();
    src.source.start();
    src.output.connect(filter);
    const g1 = c.createGain(); g1.gain.value = 0.8;
    filter.connect(g1); g1.connect(merge);
    cleanupFns.push(() => { try { src.source.stop(); lfo.stop(); } catch(_) {} });

    // Secondary: higher noise for surface texture, modulated at a different rate
    const l2 = loopingNoise();
    const f2 = c.createBiquadFilter(); f2.type = 'lowpass'; f2.frequency.value = 1200; f2.Q.value = 0.5;
    const lfo2 = c.createOscillator(); lfo2.type = 'sine'; lfo2.frequency.value = 0.3;
    const lfoG2 = c.createGain(); lfoG2.gain.value = 0.15;
    lfo2.connect(lfoG2); lfoG2.connect(f2.frequency);
    lfo2.start();
    l2.source.start();
    l2.output.connect(f2);
    const g2 = c.createGain(); g2.gain.value = 0.3;
    f2.connect(g2); g2.connect(merge);
    cleanupFns.push(() => { try { l2.source.stop(); lfo2.stop(); } catch(_) {} });

    lfoOffset.gain.setValueAtTime(440, ctx.currentTime);

    return { output: merge, type: 'ocean' };
  }

  function createForest() {
    const c = ensureCtx();
    const merge = c.createGain();
    merge.gain.value = 0.6;

    // Subtle wind layer (quiet filtered noise)
    const wind = loopingNoise({ type: 'bandpass', freq: 300, Q: 2 });
    const wGain = c.createGain(); wGain.gain.value = 0.08;
    wind.output.connect(wGain); wGain.connect(merge);
    wind.source.start();
    cleanupFns.push(() => { try { wind.source.stop(); } catch(_) {} });

    // ---- Bird chirps ----
    // Spawn chirps on random intervals using the audio context scheduler pattern
    let chirpActive = true;

    function scheduleChirp() {
      if (!chirpActive) return;
      const delay = random(0.8, 3.5); // seconds between chirps
      const scheduledTime = ctx.currentTime + delay;

      // Chirp parameters (randomized)
      const baseFreq = random(1800, 4200);
      const bendAmount = random(400, 1800);
      const chirpDur = random(0.08, 0.25);
      const chirpVol = random(0.15, 0.4);

      // Two oscillators for a richer bird sound
      [0, 1].forEach((voice) => {
        const osc = ctx.createOscillator();
        osc.type = voice === 0 ? 'sine' : 'triangle';
        const oscGain = ctx.createGain();
        oscGain.gain.setValueAtTime(0, scheduledTime);
        oscGain.gain.linearRampToValueAtTime(chirpVol, scheduledTime + chirpDur * 0.3);
        oscGain.gain.linearRampToValueAtTime(chirpVol * 0.3, scheduledTime + chirpDur * 0.6);
        oscGain.gain.linearRampToValueAtTime(0, scheduledTime + chirpDur);

        // Frequency sweep up then down (bird chirp shape)
        const peakFreq = baseFreq + (voice === 0 ? 0 : random(-200, 200));
        osc.frequency.setValueAtTime(peakFreq, scheduledTime);
        osc.frequency.linearRampToValueAtTime(peakFreq + bendAmount, scheduledTime + chirpDur * 0.35);
        osc.frequency.linearRampToValueAtTime(peakFreq + bendAmount * 0.3, scheduledTime + chirpDur * 0.7);
        osc.frequency.linearRampToValueAtTime(peakFreq, scheduledTime + chirpDur);

        osc.connect(oscGain);
        oscGain.connect(merge);
        osc.start(scheduledTime);
        osc.stop(scheduledTime + chirpDur + 0.05);
        cleanupFns.push(() => { try { osc.stop(); } catch(_) {} });
      });

      // Add a subtle tick at the start of each chirp (bird beak click)
      const clickOsc = ctx.createOscillator();
      clickOsc.type = 'square';
      clickOsc.frequency.value = 120;
      const clickGain = ctx.createGain();
      clickGain.gain.setValueAtTime(0.03, scheduledTime);
      clickGain.gain.exponentialRampToValueAtTime(0.001, scheduledTime + 0.02);
      clickOsc.connect(clickGain);
      clickGain.connect(merge);
      clickOsc.start(scheduledTime);
      clickOsc.stop(scheduledTime + 0.03);
      cleanupFns.push(() => { try { clickOsc.stop(); } catch(_) {} });

      // Schedule next chirp
      setTimeout(scheduleChirp, delay * 1000);
    }

    // Start a few chirpers in staggered fashion
    scheduleChirp();
    setTimeout(scheduleChirp, random(400, 1200));
    setTimeout(scheduleChirp, random(800, 2000));

    cleanupFns.push(() => { chirpActive = false; });

    return { output: merge, type: 'forest' };
  }

  function createCoffeeShop() {
    const c = ensureCtx();
    const merge = c.createGain();
    merge.gain.value = 0.55;

    // Room tone: lowpass filtered noise (the whoosh of a busy cafe)
    const room = loopingNoise({ type: 'lowpass', freq: 600, Q: 0.3 });
    const rGain = c.createGain(); rGain.gain.value = 0.25;
    room.output.connect(rGain); rGain.connect(merge);
    room.source.start();
    cleanupFns.push(() => { try { room.source.stop(); } catch(_) {} });

    // Clink sounds: short high-frequency metallic clicks
    let clinkActive = true;
    function scheduleClink() {
      if (!clinkActive) return;
      const delay = random(2, 8);
      const t = ctx.currentTime + delay;

      // Clink: filtered noise burst + high sine ping
      const noiseSrc = ctx.createBufferSource();
      noiseSrc.buffer = noiseBuffer(0.05);
      const noiseFilter = ctx.createBiquadFilter();
      noiseFilter.type = 'highpass'; noiseFilter.frequency.value = 5000;
      noiseSrc.connect(noiseFilter);
      const nGain = ctx.createGain();
      nGain.gain.setValueAtTime(random(0.06, 0.15), t);
      nGain.gain.exponentialRampToValueAtTime(0.001, t + 0.08);
      noiseFilter.connect(nGain); nGain.connect(merge);
      noiseSrc.start(t); noiseSrc.stop(t + 0.1);
      cleanupFns.push(() => { try { noiseSrc.stop(); } catch(_) {} });

      // Metallic ring: high sine with fast decay
      const ring = ctx.createOscillator();
      ring.type = 'sine';
      ring.frequency.value = random(3000, 7000);
      const ringGain = ctx.createGain();
      ringGain.gain.setValueAtTime(random(0.04, 0.1), t);
      ringGain.gain.exponentialRampToValueAtTime(0.001, t + 0.06);
      ring.connect(ringGain); ringGain.connect(merge);
      ring.start(t); ring.stop(t + 0.08);
      cleanupFns.push(() => { try { ring.stop(); } catch(_) {} });

      setTimeout(scheduleClink, delay * 1000);
    }
    scheduleClink();
    cleanupFns.push(() => { clinkActive = false; });

    // Occasional chatter burst: brief swell of mid-frequency noise
    let chatterActive = true;
    function scheduleChatter() {
      if (!chatterActive) return;
      const delay = random(10, 25);
      const t = ctx.currentTime + delay;
      const burst = loopingNoise({ type: 'bandpass', freq: 1500, Q: 1.5 });
      const bGain = ctx.createGain();
      bGain.gain.setValueAtTime(0, t);
      bGain.gain.linearRampToValueAtTime(0.12, t + 0.5);
      bGain.gain.linearRampToValueAtTime(0.12, t + 2.5);
      bGain.gain.linearRampToValueAtTime(0, t + 3.5);
      burst.output.connect(bGain); bGain.connect(merge);
      burst.source.start(t); burst.source.stop(t + 4);
      cleanupFns.push(() => { try { burst.source.stop(); } catch(_) {} });

      setTimeout(scheduleChatter, delay * 1000);
    }
    setTimeout(scheduleChatter, 5 * 1000);
    cleanupFns.push(() => { chatterActive = false; });

    return { output: merge, type: 'coffee' };
  }

  // ---- Generators map ----
  const GENERATORS = {
    'white':     createWhiteNoise,
    'rain':      createRain,
    'ocean':     createOcean,
    'forest':    createForest,
    'coffee':    createCoffeeShop,
  };

  // ---- Public API ----
  return {
    /**
     * Start playing a specific sound. Stops any currently playing sound.
     * @param {string} type - 'white' | 'rain' | 'ocean' | 'forest' | 'coffee'
     */
    start(type) {
      const c = ensureCtx();
      if (!GENERATORS[type]) return;
      this.stop(); // stop any existing sound

      currentType = type;
      isPlaying = true;

      // Run cleanup from previous generator
      cleanupFns.forEach(fn => fn());
      cleanupFns = [];

      const sound = GENERATORS[type]();
      currentNode = sound.output;
      sound.output.connect(masterGain);
    },

    /** Stop the currently playing sound */
    stop() {
      if (currentNode) {
        try { currentNode.disconnect(); } catch (_) {}
        currentNode = null;
      }
      cleanupFns.forEach(fn => fn());
      cleanupFns = [];
      currentType = null;
      isPlaying = false;
    },

    /**
     * Set master volume
     * @param {number} v - 0 (silent) to 1 (full)
     */
    setVolume(v) {
      volume = Math.max(0, Math.min(1, v));
      if (masterGain) masterGain.gain.value = volume;
    },

    /** Get current volume 0–1 */
    getVolume() { return volume; },

    /** Get full playback state */
    getState() {
      return {
        type: currentType,
        playing: isPlaying,
        volume: volume,
      };
    },

    /** Clean up all audio resources */
    destroy() {
      this.stop();
      if (ctx) {
        ctx.close().catch(() => {});
        ctx = null;
        masterGain = null;
      }
    },
  };
})();
