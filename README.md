# Docker Engines Benchmark Suite

A comprehensive benchmarking tool for comparing performance characteristics of different Docker-like container engines (Docker Desktop, Podman Desktop, Colima, OrbStack, Rancher Desktop).

## Overview

This benchmark suite measures and visualizes three key aspects of container engine performance:
- 🚀 Startup time
- ⚡ Build performance with different types of containers
- 📊 Resource utilization (CPU, Memory, Power consumption) in idle and load states

## Features

- Automated testing of multiple container engines
- Various test scenarios including simple, Java, and ML container builds
- Real-time resource monitoring
- Interactive dashboard for results visualization
- Configurable test parameters
- JSON-based test results storage

## Test Categories

1. **Startup Performance**
   - Measures engine initialization time
   - Multiple runs for statistical accuracy

2. **Build Performance**
   - Tests different types of container builds
   - Compares build times across engines
   - Supports custom Dockerfile testing

3. **Resource Metrics**
   - CPU usage monitoring
   - Memory consumption tracking
   - Power usage measurement
   - Idle vs Load state comparison

## Getting Started

```bash
# Clone the repository
git clone https://github.com/yourusername/docker-engines-benchmark

# Run the benchmark
./engine-benchmark.sh -v [engine-name]

# Or run all
./engine-benchmark.sh -v all
```

For graphic result open `results/index.html` in your browser.

## Requirements

- Mac OS only
- Python 3.x
- Homebrew

## License

MIT License