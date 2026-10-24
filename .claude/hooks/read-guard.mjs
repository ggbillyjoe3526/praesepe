// PreToolUse hook on Read: a whole-file read of a text file over 40 KB (spec.md is about 90 KB) is stopped and Claude is
// told to grep for the heading first and read a range. Fails open: any problem lets the read through.
import { readFileSync, statSync } from 'node:fs';

const LIMIT_BYTES = 40 * 1024;
const TEXT = /\.(md|gd|gdshader|tscn|tres|cfg|godot|py|sh|mjs|json|txt|log|yml|yaml)$/i;

try {
  const { tool_input: input } = JSON.parse(readFileSync(0, 'utf8'));
  const path = input?.file_path;
  const ranged = input?.offset !== undefined || input?.limit !== undefined;
  if (path && !ranged && TEXT.test(path)) {
    const bytes = statSync(path).size;
    if (bytes > LIMIT_BYTES) {
      process.stderr.write(
        `${path} is ${Math.round(bytes / 1024)} KB. Grep for the heading or lines you need, then Read with offset and ` +
          'limit (CLAUDE.md, reading big files).\n',
      );
      process.exit(2);
    }
  }
} catch {
  // Unreadable input or a missing file: let the Read tool report it.
}
