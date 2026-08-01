# qemu-win10-nix

A Nix-packaged wrapper that runs ephemeral [Windows 10 LTSC](https://en.wikipedia.org/wiki/Windows_10_editions#Enterprise_LTSC) virtual machines with QEMU. Each session boots from a read-only base image through a chain of `qcow2` overlays, so the OS and installed apps stay stable while day-to-day usage is throwaway.

## How it works

Images are layered:

```
system.qcow2                   ← base OS install (read-only after setup)
  └─ apps-<name>.qcow2         ← installed applications (one per app set)
       └─ overlay-<ts>.qcow2   ← ephemeral session (auto-created, disposable)
```

A SPICE display is served over a per-VM Unix socket and `remote-viewer` (from `virt-viewer`) opens automatically, so any number of VMs run at once without port conflicts. Drag-and-drop copies files from host to guest; a virtiofs shared folder (see [Sharing files](#sharing-files)) moves them both ways.

## Sharing files

A single host directory (`~/.local/share/qemu-win10/shared` by default, or `--share-dir <dir>`) is exported to the guest over **virtiofs** under the mount tag `hostshare`. This is how you move files **both** directions — in particular, how you get results back out of the guest.

One-time guest setup (do it in an `--apps-rw <name>` session so it persists to the apps image):

1. Install [**WinFsp**](https://winfsp.dev/). It is not on the virtio-win ISO, so either drag the installer into the guest (host→guest drag-and-drop works) or attach it with `--iso`.
2. Install the **viofs** driver from the attached [virtio-win ISO](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.285-1/) (`viofs\w10\amd64\viofs.inf` → right-click → Install), then start its service: `sc start VirtioFsSvc` (set `sc config VirtioFsSvc start=auto` to have it start on boot).

The share then appears as a drive letter (typically `Z:`). Files you drop there in Windows appear in the host directory immediately, and vice versa.

Why not just drag files out? SPICE has **no** guest-to-host file transfer, and its clipboard bridge only carries text and images (not file objects). So host→guest drag-and-drop works, but the shared folder is the way to copy finished files back to the host.

## Installation

Run directly:

```sh
nix run github:michalrus/qemu-win10-nix -- --help
```

Or add to a flake inputs:

```sh
{
  inputs.qemu-win10.url = "github:michalrus/qemu-win10-nix";
}
```

### Requirements

- Linux (x86-64 or AArch64) with KVM enabled
- Nix with flakes
- A Windows 10 LTSC installer ISO (you supply this yourself)

## Usage

All images live under `~/.local/share/qemu-win10/`.

### 1. Install the base OS

```sh
qemu-win10 --install-base --iso ~/Downloads/Win10-LTSC.iso
```

This creates `system.qcow2` and attaches the virtio-win drivers ISO automatically. Install the virtio drivers inside Windows before shutting down.

### 2. Create / update an apps image

```sh
qemu-win10 --apps-rw office --iso ~/Downloads/Office.iso
```

Boots `apps-office.qcow2` read-write (creating it on first use). Install your applications, then shut down.

### 3. Run an ephemeral session

```sh
qemu-win10 --apps office
```

Creates a temporary overlay on top of `apps-office.qcow2`. Anything you do in this session is discarded when the VM shuts down.

### 4. Enable internet access (disabled by default)

```sh
qemu-win10 --apps office --net
```

Adds user-mode (NAT) networking. Only available with `--apps` and `--apps-rw`.

### 5. Housekeeping

```sh
# List available apps images
qemu-win10 --list-apps

# Delete old overlay images
qemu-win10 --prune-overlays
```

### All options

```
qemu-win10 --install-base [--iso <iso> ...]
qemu-win10 --apps <name> [--net] [--iso <iso> ...] [--share-dir <dir>]
qemu-win10 --apps-rw <name> [--net] [--iso <iso> ...] [--share-dir <dir>]
qemu-win10 --prune-overlays
qemu-win10 --list-apps
qemu-win10 --help

-m, --mem <size>    RAM size (default: 4G)
--net               User-mode internet (apps/apps-rw only)
--iso <file>        Attach an ISO image (repeatable)
--share-dir <dir>   Override shared host directory
```

## Configuration

| Variable        | Default          | Description                                |
| --------------- | ---------------- | ------------------------------------------ |
| `XDG_DATA_HOME` | `~/.local/share` | Parent of the `qemu-win10/` data directory |

## License

Apache-2.0
