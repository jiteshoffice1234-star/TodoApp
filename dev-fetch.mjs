// Resumable HTTPS downloader for the sandboxed machine.
// Usage:
//   node dev-fetch.mjs <url> <outfile>          -> download (resumes partial files)
//   node dev-fetch.mjs <url> --head             -> print status code + content-length
import https from 'node:https';
import http from 'node:http';
import fs from 'node:fs';

function request(u, headers, timeoutMs = 25000) {
  return new Promise((resolve, reject) => {
    const mod = u.protocol === 'https:' ? https : http;
    const req = mod.get(u, { headers }, (res) => resolve(res));
    req.on('error', reject);
    req.setTimeout(timeoutMs, () => {
      req.destroy(new Error('timeout after ' + timeoutMs + 'ms'));
    });
  });
}

async function head(url) {
  try {
    const res = await request(new URL(url), { method: 'HEAD' });
    console.log(`${res.statusCode}\t${res.headers['content-length'] ?? '?'}\t${url}`);
    res.resume();
  } catch (e) {
    console.log(`ERR\t${e.message}\t${url}`);
  }
}

async function download(url, out) {
  let u = new URL(url);
  let existing = fs.existsSync(out) ? fs.statSync(out).size : 0;
  let headers = existing > 0 ? { Range: `bytes=${existing}-` } : {};

  for (let i = 0; i < 6; i++) {
    const res = await request(u, headers);
    if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
      const next = new URL(res.headers.location, u);
      // Keep the Range header when following redirects.
      if (next.protocol === 'https:' || next.protocol === 'http:') u = next;
      res.resume();
      continue;
    }
    if (res.statusCode === 416) {
      console.log(`DONE ${existing} bytes already complete: ${out}`);
      process.exit(0);
    }
    if (res.statusCode !== 200 && res.statusCode !== 206) {
      console.error(`HTTP ${res.statusCode} for ${u.href}`);
      process.exit(1);
    }
    const total = res.statusCode === 206
      ? Number((res.headers['content-range'] || '').split('/')[1] || 0)
      : Number(res.headers['content-length'] || 0);
    const file = fs.createWriteStream(out, { flags: existing > 0 && res.statusCode === 206 ? 'a' : 'w' });
    if (res.statusCode === 200) existing = 0; // full re-send, truncated file
    let received = existing;
    res.on('data', (d) => { received += d.length; });
    res.pipe(file);
    await new Promise((resolve, reject) => {
      file.on('finish', resolve);
      file.on('error', reject);
      res.on('error', reject);
    });
    console.log(`WROTE ${received} / ${total} bytes -> ${out}${received >= total && total > 0 ? ' [COMPLETE]' : ' [RESUME NEEDED]'}`);
    process.exit(received >= total && total > 0 ? 0 : 2);
  }
  console.error('too many redirects');
  process.exit(1);
}

const [, , arg1, arg2] = process.argv;
if (!arg1) { console.error('usage: node dev-fetch.mjs <url> <out|--head>'); process.exit(1); }
if (arg2 === '--head') { head(arg1); } else { download(arg1, arg2); }
