# Vibe Hero's Homebrew formula, written for each release by scripts/release/formula.mjs
# (goal #31, step 2.6). Do not edit vibe-hero.rb in the tap by hand: change this template.
#
# The placeholders in double braces are filled from the release: the service's URL for the
# tarball, the sha256 the build wrote beside it, and a `version` line only when Homebrew
# cannot read the version from the URL (it reads `0.0.0-test.1` as 1). The service's
# settings come from server/src/lib/serviceenv.js, the one list the boot check reads too.
class VibeHero < Formula
  desc "Kanban board that runs Claude Code on your cards"
  homepage "https://vibehero.platinumvertical.com"
  url "https://vibehero.platinumvertical.com/v1/releases/2.5.3/vibe-hero-2.5.3.tar.gz"
  sha256 "74d8da51013ce8b17d4cf2f91b1e9b4ab010cacccee4623bceeb306ec25e05a2"
  # Proprietary: the end-user agreement ships in the release as EULA.md.
  license :cannot_represent

  # Apple Silicon only at first: the disclaim and dictation helpers are built for arm64.
  depends_on arch: :arm64
  depends_on :macos
  depends_on "node@24"

  def install
    libexec.install Dir["*"]
    # The add-ons the bundles leave out, from npm as their publishers ship them: the Agent
    # SDK and its Claude Code, better-sqlite3 and @playwright/mcp. better-sqlite3 13 is on
    # Node-API and carries its arm64 binary inside its npm package, so nothing is downloaded
    # or compiled for it here, and no --build-from-source. Its 12.x copies compiled against
    # Node 24.19's headers aborted the board (nodejs/node#65446, #1591); 13 calls no Node
    # internals, so no header pin is needed (#1597). allowScripts still names only
    # better-sqlite3.
    cd libexec do
      system Formula["node@24"].opt_bin/"npm", "install", "--omit=dev",
             *(std_npm_args(prefix: false, ignore_scripts: false) - ["--build-from-source"])
      # Prove the copy it got before the install finishes: it opens a database and frees
      # statements. A failure stops the install and says why.
      system Formula["node@24"].opt_bin/"node", "server/scripts/check-sqlite.mjs"
    end

    # The stable opt paths, never a Cellar one: `brew upgrade` deletes those folders.
    (bin/"vibe-hero").write <<~SH
      #!/bin/bash
      export VK_LOG_DIR="${VK_LOG_DIR:-#{var}/log/vibe-hero}"
      exec "#{Formula["node@24"].opt_bin}/node" "#{opt_libexec}/server/cli/vibe-hero.mjs" "$@"
    SH
    chmod 0755, bin/"vibe-hero"
  end

  def post_install
    (var/"log/vibe-hero").mkpath
  end

  def caveats
    <<~EOS
      Run `vibe-hero setup` to finish.
      Vibe Hero runs on Apple Silicon Macs only.
    EOS
  end

  service do
    run [Formula["node@24"].opt_bin/"node", opt_libexec/"server/src/index.js"]
    keep_alive true
    working_dir opt_libexec
    log_path var/"log/vibe-hero/server.log"
    error_log_path var/"log/vibe-hero/server.err.log"
    path = %W[
      #{Dir.home}/.local/bin
      #{Dir.home}/.claude/local
      #{Formula["node@24"].opt_bin}
      #{HOMEBREW_PREFIX}/bin
      /usr/bin
      /bin
      /usr/sbin
      /sbin
    ]
    environment_variables VK_MANAGED_BY: "launchd",
                          VK_LOG_DIR:    var/"log/vibe-hero",
                          PATH:          path.join(":")
  end

  test do
    assert_match "vibe-hero setup", shell_output("#{bin}/vibe-hero --help")
  end
end
