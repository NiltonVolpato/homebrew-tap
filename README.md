# niltonvolpato/homebrew-tap

Custom Homebrew formulas

## tmux-macos-net

Fixes the "no route to host" error when accessing local network resources from tmux on macOS Sequoia+.

### The Problem

When using tmux over SSH on macOS:
- tmux inherits the SSH daemon as its "responsible process"
- When SSH disconnects, tmux loses network access
- Local network requests fail with "no route to host"

### The Solution

This formula builds tmux with:
1. **Embedded Info.plist** - Allows tmux to request its own Local Network permission
2. **LaunchAgent service** - Runs tmux as a service so it's self-responsible

### Installation

```bash
# If you have core tmux installed, unlink it first
brew unlink tmux

# Install tmux-macos-net
brew install niltonvolpato/tap/tmux-macos-net

# Start the service
brew services start tmux-macos-net
```

### Usage

From any SSH session, create a new tmux session:
```bash
tmux new
```

Or attach to an existing session:
```bash
tmux attach
```

On first local network access, macOS will prompt for permission. Grant it once, and all future SSH sessions will have local network access.

### Verification

```bash
# Check tmux is self-responsible
sudo launchctl procinfo $$ | grep responsible
# Should show tmux's PID, not sshd

# Test local network access
curl http://192.168.1.1:8080
```

### Updates

This formula is based on [homebrew-core tmux](https://github.com/Homebrew/homebrew-core/blob/master/Formula/t/tmux.rb). When core tmux updates, this formula should be updated to match (copy the new `url`, `sha256`, and any dependency changes).

To check for updates:
```bash
brew update
brew outdated
```

### Uninstall

```bash
brew services stop tmux-macos-net
brew uninstall tmux-macos-net

# Reinstall core tmux if desired
brew install tmux
```

### Credits

Solution discovered by combining:
- Embedded Info.plist (for Local Network Privacy)
- LaunchAgent service (for self-responsibility)

Based on research into macOS TCC and responsibility APIs.
