#!/usr/bin/env node

const { execFileSync } = require("node:child_process");
const { chmodSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } = require("node:fs");
const { tmpdir } = require("node:os");
const path = require("node:path");

const packageRoot = path.resolve(process.argv[2] || path.join(__dirname, ".."));
const packDirectory = mkdtempSync(path.join(tmpdir(), "karnel-package-"));
const stagingRoot = path.join(packDirectory, "source");
const releaseCommitPath = path.join(stagingRoot, "karnel", "RELEASE_COMMIT");
let repositoryHead = "";

// Android shared storage (FUSE) masks permission bits: every file there is
// 0660 and chmod is a silent no-op, so packing straight from a Termux checkout
// would publish an npm tarball where nothing — including bin/karnel — is
// executable. Staging lives on a real filesystem, so normalize there: keep the
// executable bit when the source has one, otherwise force 0644.
function normalizeModes(root) {
  // The git index is the source of truth for "should this file be
  // executable": the working tree cannot answer that question on shared
  // storage, where every mode is masked to 0660.
  const executablePaths = new Set();
  let haveIndex = false;
  try {
    const index = execFileSync("git", ["-C", packageRoot, "ls-files", "-s"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    });
    haveIndex = true;
    for (const line of index.split("\n")) {
      const match = /^100755 [0-9a-f]+ \d+\t(.+)$/.exec(line);
      if (match) executablePaths.add(match[1]);
    }
  } catch {
    // Not a git checkout — fall back to the mode on disk below.
  }

  const stack = [root];
  while (stack.length > 0) {
    const dir = stack.pop();
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === ".git" || entry.name === "node_modules") continue;
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        stack.push(fullPath);
        continue;
      }
      if (!entry.isFile()) continue;
      const current = statSync(fullPath).mode & 0o777;
      const relative = path.relative(root, fullPath).split(path.sep).join("/");
      const isExecutable = haveIndex ? executablePaths.has(relative) : (current & 0o111) !== 0;
      const target = isExecutable ? 0o755 : 0o644;
      if (current !== target) chmodSync(fullPath, target);
    }
  }
}
process.on("exit", () => {
  rmSync(packDirectory, { recursive: true, force: true });
});
try {
  repositoryHead = execFileSync("git", ["-C", packageRoot, "rev-parse", "HEAD"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  }).trim();
} catch {
  // Package fixtures may not be Git repositories and must provide their marker.
}
cpSync(packageRoot, stagingRoot, {
  recursive: true,
  filter: (source) => {
    const relative = path.relative(packageRoot, source);
    return relative === "" || !relative.split(path.sep).some((part) => part === ".git" || part === "node_modules");
  },
});
// Always bind the staged package to the actual repository HEAD. A stale
// committed karnel/RELEASE_COMMIT (left over from an earlier release) must
// never break release validation — the packed commit is what matters, and it
// must equal HEAD. When HEAD is unavailable (e.g. a non-git fixture) we fall
// back to a committed marker that is itself a valid SHA.
let committedCommit = "";
if (existsSync(releaseCommitPath)) {
  committedCommit = readFileSync(releaseCommitPath, "utf8").trim();
}
if (/^[0-9a-f]{40}$/.test(repositoryHead)) {
  writeFileSync(releaseCommitPath, `${repositoryHead}\n`, { mode: 0o600 });
} else if (/^[0-9a-f]{40}$/.test(committedCommit)) {
  writeFileSync(releaseCommitPath, `${committedCommit}\n`, { mode: 0o600 });
} else {
  throw new Error("Required package file is missing: karnel/RELEASE_COMMIT");
}
// Normalize after every staged file exists (RELEASE_COMMIT included).
normalizeModes(stagingRoot);

let output;
try {
  output = execFileSync(
    "npm",
    ["pack", stagingRoot, "--json", "--ignore-scripts", "--pack-destination", packDirectory],
    { encoding: "utf8" },
  );
} catch (error) {
  rmSync(packDirectory, { recursive: true, force: true });
  throw error;
}
const parsed = JSON.parse(output);
// npm < 12 returns an array of reports; npm >= 12 returns an object keyed
// by package name. Normalize both into a single-entry array.
const reports = Array.isArray(parsed) ? parsed : Object.values(parsed);
if (reports.length !== 1) {
  rmSync(packDirectory, { recursive: true, force: true });
  throw new Error("npm pack returned an unexpected report");
}

const report = reports[0];
const tarball = path.join(packDirectory, report.filename);
const extractDirectory = path.join(packDirectory, "extracted");
mkdirSync(extractDirectory);
const previousUmask = process.umask(0);
try {
  execFileSync("tar", ["-xzf", tarball, "-C", extractDirectory]);
} finally {
  process.umask(previousUmask);
}
const archiveEntries = execFileSync("tar", ["-tzf", tarball], { encoding: "utf8" })
  .trim()
  .split("\n")
  .filter((entry) => entry && !entry.endsWith("/"));
const paths = archiveEntries.map((entry) => entry.replace(/^package\//, ""));
const forbidden = paths.filter((path) =>
  /(^|\/)(__pycache__|\.git|\.github)(\/|$)|(^|\/)\.env(?:\.[^/]*)?$|(^|\/)(?:[^/]*(?:secret|credential|private[-_.]?key|api[-_.]?key|access[-_.]?token)[^/]*)$|\.(?:pyc|pyo|log|pem|key|p12|pfx|jks|keystore)$/i.test(path),
);
if (forbidden.length > 0) {
  throw new Error(`Forbidden package artifacts:\n${forbidden.join("\n")}`);
}

const required = [
  "assets/fonts/font.ttf",
  "karnel/RELEASE_COMMIT",
  "karnel/cli/commands/robin.sh",
  "karnel/modules/osint.sh",
  "karnel/tools/osint/robin/common.sh",
  "karnel/tools/osint/robin/install.sh",
  "karnel/tools/osint/robin/README.md",
  "karnel/tools/osint/robin/requirements-termux.txt",
];
for (const path of required) {
  if (!paths.includes(path)) {
    rmSync(packDirectory, { recursive: true, force: true });
    throw new Error(`Required package file is missing: ${path}`);
  }
}

const releaseCommit = execFileSync(
  "tar",
  ["-xOzf", tarball, "package/karnel/RELEASE_COMMIT"],
  { encoding: "utf8" },
).trim();
if (!/^[0-9a-f]{40}$/.test(releaseCommit)) {
  rmSync(packDirectory, { recursive: true, force: true });
  throw new Error("Packed RELEASE_COMMIT is not a full commit SHA");
}
if (repositoryHead && releaseCommit !== repositoryHead) {
  throw new Error(`Packed RELEASE_COMMIT ${releaseCommit} does not match HEAD ${repositoryHead}`);
}

for (const packedPath of ["assets/fonts/font.ttf", "karnel/tools/ai/gentle-ai/termux-patches.go"]) {
  const mode = statSync(path.join(extractDirectory, "package", packedPath)).mode & 0o777;
  if (mode !== 0o644) {
    throw new Error(`Packed file must use mode 0644: ${packedPath}`);
  }
}

// The CLI entry point must be executable in the tarball, otherwise the
// npm bin symlink fails with EACCES after a global install. Fixtures that do
// not ship the entry point are exempt, but a package that does ship it must
// never drop it to an ignore rule or pack it non-executable.
const entryPoint = "karnel/bin/karnel";
if (existsSync(path.join(packageRoot, entryPoint))) {
  if (!paths.includes(entryPoint)) {
    rmSync(packDirectory, { recursive: true, force: true });
    throw new Error(`Required package file is missing: ${entryPoint}`);
  }
  const mode = statSync(path.join(extractDirectory, "package", entryPoint)).mode & 0o777;
  if ((mode & 0o111) === 0) {
    throw new Error(`Packed file must be executable: ${entryPoint} (mode ${mode.toString(8)})`);
  }
}

const keepTarball = process.env.KARNEL_KEEP_TARBALL;
if (keepTarball) {
  mkdirSync(path.dirname(keepTarball), { recursive: true });
  writeFileSync(keepTarball, readFileSync(tarball));
}

const packageVersion = JSON.parse(readFileSync(path.join(packageRoot, "package.json"), "utf8")).version;
if (report.version !== packageVersion) {
  rmSync(packDirectory, { recursive: true, force: true });
  throw new Error(`Packed version ${report.version} does not match ${packageVersion}`);
}

console.log(
  `Package: ${paths.length} files, ${report.size} bytes, version ${report.version}, commit ${releaseCommit}, no forbidden artifacts`,
);
rmSync(packDirectory, { recursive: true, force: true });
