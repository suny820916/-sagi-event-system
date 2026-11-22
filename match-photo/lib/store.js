'use strict';

const fs = require('fs');
const path = require('path');

class JsonStore {
  constructor(file) {
    this.file = file;
    fs.mkdirSync(path.dirname(file), { recursive: true });
    if (!fs.existsSync(file)) {
      fs.writeFileSync(file, JSON.stringify({ events: [], photos: [], orders: [] }, null, 2));
    }
  }

  read() {
    try {
      return JSON.parse(fs.readFileSync(this.file, 'utf8'));
    } catch {
      return { events: [], photos: [], orders: [] };
    }
  }

  write(data) {
    const tmp = this.file + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(data, null, 2));
    fs.renameSync(tmp, this.file);
    return data;
  }

  update(fn) {
    const data = this.read();
    const next = fn(data) || data;
    return this.write(next);
  }
}

module.exports = { JsonStore };
