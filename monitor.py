#!/usr/bin/env python3

import psutil
import pandas as pd
import subprocess
import time
import json
import argparse
import signal
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
import subprocess
from datetime import datetime, timedelta

class DockerMonitor:
    def __init__(self, engine: str, duration: int, interval: int, test_type: str, output_dir: str):
        self.engine = engine
        self.duration = duration
        self.interval = interval
        self.test_type = test_type
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.power_process = None
        self.metrics_data = []
        self.running = True
        self.start_energy = 0
        self.end_energy = 0

    def get_energy_metrics(self):
        """Получение энергопотребления через powermetrics"""
        try:
            cmd = "sudo powermetrics -n 1 --samplers cpu_power"
            output = subprocess.check_output(cmd, shell=True, text=True)
            
            total_power = 0
            for line in output.split('\n'):
                if 'CPU Power:' in line:
                    try:
                        # Получаем общее энергопотребление CPU в милливаттах
                        total_power = float(line.split(':')[1].split('mW')[0].strip())
                        
                        # Получаем общую загрузку CPU всей системы
                        system_cpu = psutil.cpu_percent()
                        if system_cpu > 0:
                            # Получаем CPU наших процессов и вычисляем их долю от общей загрузки
                            docker_metrics = self.get_process_metrics()
                            docker_cpu_percent = docker_metrics['cpu']
                            
                            # Вычисляем пропорциональное потребление энергии
                            docker_power = (docker_cpu_percent / system_cpu) * total_power
                            return docker_power
                    except (ValueError, IndexError, ZeroDivisionError):
                        continue
            return 0
        except subprocess.SubprocessError as e:
            print(f"Ошибка при получении метрик энергопотребления: {e}")
            return 0

    def get_process_metrics(self) -> Dict[str, float]:
        """Получение CPU и Memory метрик"""
        search_pattern = {
            "docker-desktop": "Docker",
            "podman-desktop": "Podman",
            "orbstack": "OrbStack",
            "rancher-desktop": "Rancher",
            "colima": "colima"
        }.get(self.engine, "Docker")

        try:
            cmd = f"ps aux | grep {search_pattern} | grep -v grep | awk '{{cpu += $3; mem += $6}} END {{print cpu\",\"mem}}'"
            result = subprocess.check_output(cmd, shell=True, text=True).strip()
            if result:
                cpu, mem = map(float, result.split(','))
                # mem в KB из ps aux, сразу переводим в MB
                return {'cpu': cpu, 'memory': mem / 1024}  # делим на 1024 для перевода KB в MB
        except subprocess.SubprocessError:
            pass
        
        return {'cpu': 0, 'memory': 0}

    def start_power_monitoring(self):
        """Запуск мониторинга power через top"""
        power_file = self.output_dir / f"{self.engine}_power.txt"
        cmd = f"top -stats pid,command,power -o power -l 0 | grep '{self.engine}' | awk '{{gsub(\"H\", \"\", $NF); if ($NF+0 == $NF) print $NF}}'"
        
        self.power_process = subprocess.Popen(
            cmd,
            shell=True,
            stdout=open(power_file, 'w'),
            stderr=subprocess.DEVNULL
        )
        return power_file

    def read_power_value(self, power_file: Path) -> float:
        """Чтение значения power из файла"""
        try:
            if power_file.exists():
                with open(power_file, 'r') as f:
                    lines = f.readlines()
                    if lines:
                        return float(lines[-1].strip())
        except (ValueError, IndexError):
            pass
        return 0.0

    def start_test_environment(self):
        """Start the test environment"""
        if self.test_type == "idle":
            if self.engine == "podman-desktop":
                cmd = ["podman", "compose", "up", "-d"]
            if self.engine == "colima":
                cmd = ["docker-compose", "up", "-d"]
            else:
                cmd = ["docker", "compose", "up", "-d"]
        elif self.test_type == "load":
            if self.engine == "podman-desktop":
                cmd = ["podman", "run", "-d", "--name", "stress-test-podman", "alexeiled/stress-ng", "--cpu", "4", "--vm", "2", "--vm-bytes", "1G", "--timeout", f"{self.duration}s"]
                remove_cmd = ["podman", "rm", "-f", "stress-test-podman"]
            else:
                cmd = ["docker", "run", "-d", "--name", "stress-test", "alexeiled/stress-ng", "--cpu", "4", "--vm", "2", "--vm-bytes", "1G", "--timeout", f"{self.duration}s"]
                remove_cmd = ["docker", "rm", "-f", "stress-test"]

            try:
                # Remove existing container if it exists
                subprocess.run(remove_cmd, check=True)
            except subprocess.CalledProcessError:
                pass  # Ignore error if container does not exist

        try:
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Error starting test environment: {e}")
            # Additional logging for debugging
            if self.engine != "podman-desktop":
                logs = subprocess.run(["docker", "logs", "stress-test"], capture_output=True, text=True)
                print(f"Docker logs:\n{logs.stdout}")
            raise

        time.sleep(10)  # Wait for initialization

    def stop_test_environment(self):
        """Остановка тестового окружения"""
        if self.test_type == "idle":
            if self.engine == "podman-desktop":
                subprocess.run(["podman", "compose", "down", "-v"])
            else:
                subprocess.run(["docker", "compose", "down", "-v"])
        elif self.test_type == "load":
            if self.engine == "podman-desktop":
                subprocess.run(["podman", "stop", "stress-test"])
                subprocess.run(["podman", "rm", "stress-test"])
            else:
                subprocess.run(["docker", "stop", "stress-test"])
                subprocess.run(["docker", "rm", "stress-test"])

    def monitor(self):
        """Основной цикл мониторинга"""
        try:
            self.stop_test_environment()
            self.start_test_environment()
            
            # Ждем стабилизации CPU
            print("Ожидание стабилизации CPU (30 секунд)...")
            time.sleep(30)
            
            # Получаем начальное значение энергопотребления
            start_power = self.get_energy_metrics()
            start_time = datetime.now()
            accumulated_power = 0
            measurements = 0
            
            print(f"Начало мониторинга на {self.duration} секунд...")
            end_time = time.time() + self.duration

            while time.time() < end_time:
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                metrics = self.get_process_metrics()
                
                # Получаем текущее значение энергопотребления
                current_power = self.get_energy_metrics()
                
                # Накапливаем значения для среднего
                accumulated_power += current_power
                measurements += 1
                
                self.metrics_data.append({
                    'timestamp': timestamp,
                    'cpu': metrics['cpu'],
                    'memory_mb': metrics['memory'],  # уже в MB
                    'power_mw': current_power
                })
                
                print(f"[{timestamp}] CPU: {metrics['cpu']:.1f}% MEM: {metrics['memory']:.1f}MB POWER: {current_power:.1f}mW")
                time.sleep(self.interval)

            # Получаем конечное значение энергопотребления
            end_power = self.get_energy_metrics()
            average_power = accumulated_power / measurements if measurements > 0 else 0
            
            print(f"\nНачальная мощность: {start_power:.1f}mW")
            print(f"Конечная мощность: {end_power:.1f}mW")
            print(f"Средняя мощность: {average_power:.1f}mW")

        finally:
            self.stop_test_environment()

        self.save_results()

    def save_results(self):
        """Сохранение результатов в CSV и JSON"""
        if not self.metrics_data:
            return

        df = pd.DataFrame(self.metrics_data)
        
        # Сохраняем CSV
        csv_file = self.output_dir / f"{self.engine}_{self.test_type}_resources.csv"
        df.to_csv(csv_file, index=False)
        
        # Вычисляем средние значения
        results = {
            'engine': self.engine,
            'test_type': self.test_type,
            'duration': self.duration,
            'interval': self.interval,
            'samples': len(df),
            'metrics': {
                'cpu_average': df['cpu'].mean(),
                'memory_average': df['memory_mb'].mean(),
                'power_average_mw': df['power_mw'].mean()
            }
        }
        
        json_file = self.output_dir / f"{self.engine}_{self.test_type}_resources.json"
        with open(json_file, 'w') as f:
            json.dump(results, f, indent=4)

def main():
    parser = argparse.ArgumentParser(description='Мониторинг ресурсов Docker движков')
    parser.add_argument('engine', choices=['docker-desktop', 'podman-desktop', 'orbstack', 
                                         'rancher-desktop', 'colima', 'all'])
    parser.add_argument('-d', '--duration', type=int, default=600)
    parser.add_argument('-i', '--interval', type=int, default=5)
    parser.add_argument('-t', '--test', choices=['idle', 'load'], default='idle')
    parser.add_argument('-o', '--output', default='results/performance')
    
    args = parser.parse_args()
    
    if args.engine == 'all':
        engines = ['docker-desktop', 'podman-desktop', 'orbstack', 
                  'rancher-desktop', 'colima']
        for engine in engines:
            monitor = DockerMonitor(
                engine, args.duration, args.interval, args.test, args.output)
            monitor.monitor()
    else:
        monitor = DockerMonitor(
            args.engine, args.duration, args.interval, args.test, args.output)
        monitor.monitor()

if __name__ == '__main__':
    main()