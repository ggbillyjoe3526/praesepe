// SessionStart hook: in a Claude Code cloud session, install the Godot editor this project pins (the GODOT_VERSION in
// .github/workflows/ci.yml) and put `godot` on PATH, so every thread can run the smoke test without spending turns on
// setup. Export templates are left out (CI builds the releases). Does nothing on a local machine.
import { appendFileSync, chmodSync, existsSync, mkdirSync, readFileSync, rmSync, symlinkSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { join } from 'node:path';

if (process.env.CLAUDE_CODE_REMOTE === 'true') {
  const root = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();
  try {
    const ci = readFileSync(join(root, '.github/workflows/ci.yml'), 'utf8');
    const version = ci.match(/GODOT_VERSION:\s*"([^"]+)"/)?.[1];
    const status = ci.match(/GODOT_STATUS:\s*"([^"]+)"/)?.[1] ?? 'stable';
    if (!version) throw new Error('GODOT_VERSION not found in ci.yml');
    const v = `${version}-${status}`;
    const dir = join(homedir(), '.local/share/godot-bin');
    const bin = join(dir, `Godot_v${v}_linux.x86_64`);
    const binDir = join(homedir(), '.local/bin');
    if (!existsSync(bin)) {
      mkdirSync(dir, { recursive: true });
      const zip = join(dir, 'godot.zip');
      const url = `https://github.com/godotengine/godot/releases/download/${v}/Godot_v${v}_linux.x86_64.zip`;
      const dl = spawnSync('curl', ['-fsSL', '--retry', '4', '-o', zip, url], { stdio: 'ignore' });
      if (dl.status !== 0) throw new Error(`download failed: ${url}`);
      const uz = spawnSync('unzip', ['-q', '-o', zip, '-d', dir], { stdio: 'ignore' });
      rmSync(zip, { force: true });
      if (uz.status !== 0) throw new Error('unzip failed');
      chmodSync(bin, 0o755);
    }
    mkdirSync(binDir, { recursive: true });
    rmSync(join(binDir, 'godot'), { force: true });
    symlinkSync(bin, join(binDir, 'godot'));
    if (process.env.CLAUDE_ENV_FILE) appendFileSync(process.env.CLAUDE_ENV_FILE, `export PATH="${binDir}:$PATH"\n`);
    console.log(`Session setup: Godot ${v} installed as \`godot\`.`);
  } catch (err) {
    console.log(`Session setup: could not install Godot (${err.message}); download it by hand.`);
  }
}
