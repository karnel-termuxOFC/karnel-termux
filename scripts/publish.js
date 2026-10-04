#!/usr/bin/env node

/**
 * Publishes the *validated* tarball produced by scripts/check-package.js.
 *
 * `npm publish` packs straight from the working tree, which is unusable on
 * Android shared storage: FUSE masks every file to 0660, so the published
 * package would contain a non-executable bin/karnel. Publishing the artifact
 * that pack:check already normalized and verified removes that failure mode.
 */

const { execFileSync, spawnSync } = require("node:child_process");
const { existsSync, mkdtempSync, rmSync } = require("node:fs");
const { tmpdir } = require("node:os");
const path = require("node:path");

const packageRoot = path.resolve(process.argv[2] || path.join(__dirname, ".."));
const workDir = mkdtempSync(path.join(tmpdir(), "karnel-release-"));
const tarball = path.join(workDir, "karnel-termux.tgz");

let failure = null;
try {
  execFileSync(process.execPath, [path.join(packageRoot, "scripts", "check-package.js"), packageRoot], {
    stdio: "inherit",
    env: { ...process.env, KARNEL_KEEP_TARBALL: tarball },
  });

  if (!existsSync(tarball)) {
    throw new Error(`check-package did not produce a tarball at ${tarball}`);
  }

  const npm = process.env.npm_execpath;
  const args = ["publish", tarball];
  const result = npm && npm.endsWith(".js")
    ? spawnSync(process.execPath, [npm, ...args], { stdio: "inherit", cwd: packageRoot })
    : spawnSync("npm", args, { stdio: "inherit", cwd: packageRoot });

  if (result.error) throw result.error;
  if (result.status !== 0) process.exitCode = result.status || 1;
} catch (error) {
  failure = error;
} finally {
  rmSync(workDir, { recursive: true, force: true });
}

if (failure) {
  console.error(failure.message || failure);
  process.exit(1);
}
