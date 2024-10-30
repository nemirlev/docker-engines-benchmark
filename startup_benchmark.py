#!/usr/bin/env python3

import argparse
import json
import os
import subprocess
import time
import statistics
from datetime import datetime
from pathlib import Path
import psutil
from typing import List, Optional, Dict

class ContainerStartBenchmark:
    def __init__(self, results_dir: str = "results", logs_dir: str = "logs",
                 verbose: bool = False, repeat_count: int = 3, cleanup: bool = True):
        self.results_dir = Path(results_dir)
        self.logs_dir = Path(logs_dir)
        self.verbose = verbose
        self.repeat_count = repeat_count
        self.cleanup = cleanup
        
        # Create necessary directories
        self.results_dir.mkdir(exist_ok=True)
        self.logs_dir.mkdir(exist_ok=True)
        
        self.engines = {
            "docker-desktop": "Docker Desktop",
            "podman-desktop": "Podman Desktop",
            "orbstack": "OrbStack",
            "rancher-desktop": "Rancher Desktop",
            "colima": "colima"
        }

    def is_engine_running(self, engine: str) -> bool:
        """Check if the specified container engine is running."""
        if engine == "colima":
            try:
                result = subprocess.run(["colima", "status"], 
                                      capture_output=True, text=True)
                return "Running" in result.stdout
            except FileNotFoundError:
                return False
        else:
            process_name = self.engines[engine]
            return any(process_name.lower() in p.name().lower() 
                      for p in psutil.process_iter(['name']))

    def check_engine_ready(self, engine: str, timeout: int = 300) -> bool:
        """Check if the container engine is fully ready to accept commands."""
        start_time = time.time()
        interval = 1

        while time.time() - start_time < timeout:
            try:
                if engine == "podman-desktop":
                    cmd_prefix = ["podman"]
                else:
                    cmd_prefix = ["docker"]
                
                # Check basic commands
                subprocess.run(cmd_prefix + ["info"], 
                             capture_output=True, check=True)
                subprocess.run(cmd_prefix + ["ps"], 
                             capture_output=True, check=True)
                return True
            except subprocess.CalledProcessError:
                if self.verbose:
                    print(f"Waiting for {engine} to be ready: "
                          f"{int(time.time() - start_time)} seconds...")
                time.sleep(interval)
                
        return False

    def stop_engine(self, engine: str) -> None:
        """Stop the specified container engine."""
        print(f"Stopping {engine}...")
        
        if engine == "colima":
            subprocess.run(["colima", "stop"], capture_output=True)
        else:
            subprocess.run(["osascript", "-e", 
                          f'quit app "{self.engines[engine]}"'])
        
        # Wait for the process to actually terminate
        timeout = 30
        while timeout > 0 and self.is_engine_running(engine):
            time.sleep(1)
            timeout -= 1

    def start_engine(self, engine: str) -> Optional[float]:
        """Start the engine and measure startup time."""
        print(f"Starting {engine}...")
        log_file = self.logs_dir / f"{engine}_startup.log"

        start_time = time.time()

        try:
            if engine == "colima":
                subprocess.run(["colima", "start"], capture_output=True)
            else:
                subprocess.run(["open", "-a", self.engines[engine]], capture_output=True)

            # Retry mechanism
            retries = 3
            for attempt in range(retries):
                if self.check_engine_ready(engine):
                    break
                else:
                    if attempt < retries - 1:
                        print(f"Retrying to start {engine} (attempt {attempt + 2}/{retries})...")
                        time.sleep(2)  # Short delay before retrying
                    else:
                        print(f"Error: {engine} is not ready after {retries} attempts")
                        return None

            end_time = time.time()
            startup_time = end_time - start_time

            # Save additional information to log
            with open(log_file, 'w') as f:
                f.write("=== Startup Information ===\n")
                f.write(f"Startup time: {startup_time} seconds\n")
                f.write("=== System Information ===\n")

                try:
                    if engine == "podman-desktop":
                        info = subprocess.run(["podman", "info"], capture_output=True, text=True)
                    else:
                        info = subprocess.run(["docker", "info"], capture_output=True, text=True)
                    f.write(info.stdout)
                except subprocess.CalledProcessError as e:
                    f.write(f"Error getting system info: {str(e)}\n")

            return startup_time

        except Exception as e:
            print(f"Error starting {engine}: {str(e)}")
            return None

    def test_engine(self, engine: str) -> bool:
        """Test a single container engine."""
        result_file = self.results_dir / f"{engine}_startup.json"
        times: List[float] = []
        
        print(f"Testing {engine}...")
        
        for i in range(1, self.repeat_count + 1):
            print(f"Attempt {i} of {self.repeat_count}")
            
            if self.is_engine_running(engine):
                self.stop_engine(engine)
                time.sleep(5)
            
            startup_time = self.start_engine(engine)
            
            if startup_time is not None:
                times.append(startup_time)
                print(f"Startup time: {startup_time} seconds")
            else:
                print("Error starting engine")
                continue
            
            self.stop_engine(engine)
            time.sleep(5)
        
        if not times:
            print("No successful startup measurements")
            return False
        
        # Generate results
        results = {
            "engine": engine,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "repeat_count": len(times),
            "results": {
                "average": statistics.mean(times),
                "min": min(times),
                "max": max(times),
                "all_times": times
            }
        }
        
        with open(result_file, 'w') as f:
            json.dump(results, f, indent=4)
        
        print(f"Results saved to {result_file}")
        
        if self.verbose:
            print("JSON contents:")
            print(json.dumps(results, indent=4))
        
        return True

def main():
    parser = argparse.ArgumentParser(description="Container Engine Benchmark Tool")
    parser.add_argument("engine", choices=["docker-desktop", "podman-desktop",
                                         "orbstack", "rancher-desktop", 
                                         "colima", "all"],
                       help="Container engine to test")
    parser.add_argument("-v", "--verbose", action="store_true",
                       help="Verbose output")
    parser.add_argument("-o", "--output", default="results",
                       help="Results directory (default: ./results/startup)")
    parser.add_argument("-r", "--repeat", type=int, default=3,
                       help="Number of test repetitions (default: 3)")
    parser.add_argument("--no-cleanup", action="store_true",
                       help="Don't clean up engines after testing")
    
    args = parser.parse_args()
    
    benchmark = ContainerStartBenchmark(
        results_dir=args.output,
        verbose=args.verbose,
        repeat_count=args.repeat,
        cleanup=not args.no_cleanup
    )
    
    if args.engine == "all":
        for engine in benchmark.engines:
            benchmark.test_engine(engine)
    else:
        benchmark.test_engine(args.engine)
    
    print(f"Testing complete. Results in directory {args.output}")

if __name__ == "__main__":
    main()