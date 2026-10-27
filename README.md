# Hypersense MAX v10

The most aggressive of the offline Termux builds: Neural Core tuning, predictive ARC+, microboost bursts and FPS smoothing, with idle/active transitions so it is not pushing the CPU while the game sits in a lobby.

Non-root, Android, no server.

## Features

| | |
| --- | --- |
| **Neural Core** | Profile selection based on the device, not a fixed preset |
| **Predictive ARC+** | Pre-emptive cache and scheduler warm-up |
| **Microboost** | Short performance windows during heavy scenes |
| **FPS smoothing** | Reduces frame-time variance, not just the average |
| **VRAM / CPU tuning** | Memory and governor hints within the non-root limits |
| **Idle / active** | Drops the profile when the game is backgrounded |
| **X/Y touch** | Separate real-time touch response per axis |
| **Activation** | Local, time-locked |

## Run

```bash
pkg install -y git
git clone https://github.com/hypersenseindia/Hypersense-MAX-v10
cd Hypersense-MAX-v10
chmod +x hypersense_max.sh
./hypersense_max.sh
```

## Notes

- Free Fire and Free Fire Max are the tuned targets; the script runs against any foreground app.
- Non-root: nothing outside `$HOME` is modified.
- If the phone is already throttling, fix the heat before tuning the software.
---

<p align="center">
  <sub>Built by <b>AG HYDRAXFF</b> &mdash; HYPERSENSEGLOBAL &middot;
  <a href="https://www.instagram.com/hydraxff_yt/">@hydraxff_yt</a></sub>
</p>