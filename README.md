# Linux Performance Profiling Workshop: The Tale of Two Identical Nodes

Welcome to the hands-on Linux Performance Investigation Lab!

---

## 📦 Part 1: Pre-Workshop Preparation (Complete Ahead of Time)

To avoid conference/classroom Wi-Fi bottlenecks during the live session, **please run `./setup.sh` before the workshop begins** to install/initialize LXD, download the pre-configured Ubuntu 24.04 (Noble) VM image (`~797 MB`), and import it into your local LXD image store.

### 1. Clone the Repository & Run `setup.sh`
On a Linux (`x86_64`) host with KVM hardware virtualization enabled, about 8 GB of RAM, and 6 GB of free disk space. `setup.sh` installs LXD for you if it is missing (it needs `snap` and `sudo`).

```bash
git clone https://github.com/taodd/linux_profiling_workshop.git
cd linux_profiling_workshop
chmod +x ./setup.sh
./setup.sh
```

### What `setup.sh` Does Automatically:
1. Verifies your host is **Linux `x86_64`** with **`/dev/kvm`** virtualization enabled.
2. Installs **LXD** (`sudo snap install lxd`) and initializes it (`lxd init --auto`) if not already configured.
3. Downloads **`perf-noble-base.qcow2`** (`~797 MB`) from the [Releases (`v1.1.0`)](https://github.com/taodd/linux_profiling_workshop/releases/tag/v1.1.0) page (if not already downloaded in the repository folder).
4. Imports `perf-noble-base.meta` + `perf-noble-base.qcow2` into LXD under the alias **`perf-noble-base`** (`~1 second`) and verifies `lxc image list perf-noble-base`.

After this, the workshop needs no network: the VMs, tools, and lab files are all on your machine.

---

## 🧪 Part 2: Warm-up Lab — Dedup

Launch the lab VMs (no internet access required), copy the `dedup` folder into `node-alpha`, and log in:

```bash
chmod +x ./setup_lab
./setup_lab
lxc file push -r dedup node-alpha/root/
lxc exec node-alpha -- bash
cd ~/dedup
make
```

---

## 🚨 Part 3: Live Workshop Lab

We are going to launch two VMs based on the same image 
- **`node-alpha`**
- **`node-bravo`**

Both nodes are deployed from the **exact same base image** (`perf-noble-base`) with identical virtual hardware specifications:
- **vCPUs:** 2 vCPUs
- **Memory:** 2 GiB RAM
- **OS / Kernel:** Ubuntu 24.04 LTS (Noble)
- **Storage Subsystem:** In-memory `ramfs` mount at `/mnt/ramfs`
- **Pre-installed Tools:** `fio`, `perf`, `strace`, `sysstat`, `gcc`, `make`, `FlameGraph` (`/root/FlameGraph`), and `libbpf-profiler` (`/usr/local/bin/profile`).

---

## 🛠️ Step 1: Provision the Lab Environment (Run During Workshop)

Run the `setup_lab` binary on your host machine to launch both nodes locally (no internet access required):

```bash
chmod +x ./setup_lab
./setup_lab
```

Once the setup completes, open two terminal windows side-by-side:

```bash
# Terminal 1: Access Node Alpha
lxc exec node-alpha -- bash

# Terminal 2: Access Node Bravo
lxc exec node-bravo -- bash
```

---

## 🔬 Step 2: Reproduce the Issue (Run the Benchmark)

Run the following in-memory storage benchmark command directly inside **both** nodes:

```bash
fio --thread --name=bench --filename=/mnt/ramfs/testfile --size=256M --direct=0 \
    --rw=randread --bs=4k --ioengine=libaio --iodepth=64 \
    --runtime=60s --time_based --group_reporting
```

---

## 📊 Step 3: Compare Baseline Results

Observe and compare the metrics from the `fio` output on both nodes (numbers from my machine):

| Metric | `node-alpha` | `node-bravo` |
| :--- | :--- | :--- |
| **Throughput (IOPS)** | ~1,000,000 IOPS | ~33,000 IOPS |
| **Bandwidth (MB/s)** | ~3,900 MB/s | ~130 MB/s |
| **Average Latency (µs)** | ~60 µs | ~1,850 µs |
| **CPU Utilization (`top`)** | 100% CPU | 100% CPU |

### The Problem:
`node-bravo` is **~30x slower** than `node-alpha`, even though:
- Both virtual machines were launched from the exact same `perf-noble-base` image.
- Both have identical CPU and RAM allocations.
- Both are reading from RAM (`ramfs`).

---

## 🎯 Step 4: Investigation Challenge (15 – 30 Minutes)

Your objective as a performance engineer is to determine why `node-bravo` is collapsing under load.

Use Linux profiling tools to identify the bottleneck on node-bravo and fix the performance issue.

---
