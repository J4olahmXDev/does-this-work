const cues = {
  click: '01-Menu-Click', back: '02-Menu-Back', popup: '03-Popup-Open', pause: '04-Pause', resume: '05-Resume',
  pickup: '06-Piece-Pickup', place: '07-Piece-Place', swap: '08-Piece-Swap', tray: '09-Return-to-Tray',
  blocked: '10-Slot-Blocked', check: '11-Check-Plan', revise: '12-Plan-Needs-Work', passed: '13-Puzzle-Passed',
  nextStaff: '14-Next-Puzzle-Staffing', nextFlow: '15-Next-Puzzle-Bottleneck', nextPlant: '16-Next-Puzzle-Plant',
  nextRoute: '17-Next-Puzzle-Delivery', cleared: '18-Stage-Cleared', unlocked: '19-Stage-Unlocked', game: '20-Game-Complete',
  staffplace: '21-Staffing-Station-Place', flow: '22-Bottleneck-Flow-Updated', plant: '23-Plant-Tile-Place',
  stop: '25-Delivery-Stop-Added', reorder: '26-Delivery-Stop-Reordered',
};

export class GameSound {
  settings;
  context;
  music;
  scene = '';
  quieter = false;
  generation = 0;
  voiceGeneration = 0;
  voiceSource;
  buffers = new Map();

  constructor(settings) { this.settings = settings; }

  activate() {
    if (!this.context) {
      this.context = new AudioContext();
      for (const path of ['Music', ...Object.values(cues)]) this.load(path).catch(() => {});
      this.setScene(this.scene, this.quieter, true);
    }
    if (this.context.state === 'suspended') this.context.resume().catch(() => {});
  }

  load(name) {
    if (!this.buffers.has(name)) {
      const buffer = fetch('./assets/audio/' + name + '.wav').then(response => {
        if (!response.ok) throw new Error(name + '.wav');
        return response.arrayBuffer();
      }).then(bytes => this.context.decodeAudioData(bytes));
      this.buffers.set(name, buffer);
    }
    return this.buffers.get(name);
  }

  update(settings) {
    this.settings = settings;
    this.mix();
  }

  mix() {
    if (!this.music) return;
    const now = this.context.currentTime;
    const gain = this.settings.master * this.settings.music * 0.54;
    const { base, layer, start, stage } = this.music;
    base.gain.setTargetAtTime(this.quieter ? gain * 0.62 : gain, now, 0.055);
    if (layer) {
      layer.gain.cancelScheduledValues(now);
      if (this.quieter) layer.gain.setTargetAtTime(0, now, 0.06);
      else {
        const bar = 240 / [112, 116, 108, 118][stage - 1];
        const position = Math.max(0, now - start);
        const next = start + Math.ceil(position / bar) * bar;
        layer.gain.setTargetAtTime(gain, Math.max(now, next), 0.065);
      }
    }
  }

  async setScene(scene, quieter, force = false) {
    const changed = scene !== this.scene || force;
    this.scene = scene;
    this.quieter = quieter;
    if (!changed) { this.mix(); return; }
    const token = ++this.generation;
    if (this.music) for (const sound of this.music.sources) sound.stop();
    this.music = undefined;
    if (!scene || !this.context) return;
    const stage = Number(scene);
    try {
      const names = stage ? [`Stage-${stage}`, `Stage-${stage}-Layer`] : ['Music'];
      const buffers = await Promise.all(names.map(name => this.load(name)));
      if (token !== this.generation) return;
      const start = this.context.currentTime + .035;
      const channels = buffers.map(buffer => {
        const source = this.context.createBufferSource(), gainNode = this.context.createGain();
        source.buffer = buffer;
        source.loop = true;
        gainNode.gain.value = 0;
        source.connect(gainNode).connect(this.context.destination);
        source.start(start);
        return { source, gain: gainNode.gain };
      });
      this.music = { base: channels[0], layer: channels[1], sources: channels.map(node => node.source), start, stage };
      this.mix();
    } catch (error) {
      console.warn('Music unavailable', error);
    }
  }

  async play(name) {
    if (!this.context || !cues[name] || !this.settings.master || !this.settings.effects) return;
    try { this.playBuffer(await this.load(cues[name]), this.settings.master * this.settings.effects * 0.78); }
    catch (error) { console.warn('Effect unavailable', error); }
  }

  async voice(style) {
    this.stopVoice();
    const token = this.voiceGeneration;
    if (!this.context || !this.settings.master || !this.settings.voices) return;
    try {
      const buffer = await this.load('Voice-' + style.split(':')[0]);
      if (token === this.voiceGeneration) this.voiceSource = this.playBuffer(buffer, this.settings.master * this.settings.voices);
    } catch (error) { console.warn('Voice unavailable', error); }
  }

  stopVoice() {
    this.voiceGeneration += 1;
    this.voiceSource?.stop();
    this.voiceSource = undefined;
  }

  playBuffer(buffer, amount) {
    const source = this.context.createBufferSource(), gain = this.context.createGain();
    source.buffer = buffer;
    gain.gain.value = amount;
    source.connect(gain).connect(this.context.destination);
    source.start();
    return source;
  }
}
