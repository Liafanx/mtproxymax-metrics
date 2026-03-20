cat > install.sh << 'INSTALLEOF'
#!/bin/bash

#################################################
# MTProtoMax Metrics Viewer - Auto Installer
# Version: 1.0
# Author: Your Name
#################################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции вывода
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   echo "Please run: sudo bash install.sh"
   exit 1
fi

# Баннер
clear
cat << "EOF"
╔════════════════════════════════════════════════════════╗
║                                                        ║
║     MTProtoMax Metrics Viewer - Installer             ║
║                                                        ║
║     Version: 1.0                                       ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
EOF
echo ""

print_info "Starting installation..."
echo ""

# Проверка ОС
print_info "Checking OS compatibility..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    print_success "Detected: $OS $VER"
else
    print_error "Cannot detect OS"
    exit 1
fi

# Проверка доступности метрик
print_info "Checking if metrics are accessible..."
if curl -s --max-time 5 http://localhost:9090/metrics > /dev/null; then
    print_success "Metrics endpoint is accessible"
else
    print_warning "Cannot reach http://localhost:9090/metrics"
    print_warning "Make sure MTProtoMax is running with metrics enabled"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Установка зависимостей
print_info "Installing system dependencies..."
apt update -qq
apt install -y python3 python3-pip python3-venv curl > /dev/null 2>&1
print_success "Dependencies installed"

# Создание директории
print_info "Creating project directory..."
INSTALL_DIR="/root/Metrics"
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Directory $INSTALL_DIR already exists"
    read -p "Remove and reinstall? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        print_info "Removed old installation"
    else
        print_error "Installation aborted"
        exit 1
    fi
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
print_success "Directory created: $INSTALL_DIR"

# Создание venv
print_info "Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate
print_success "Virtual environment created"

# Установка Python зависимостей
print_info "Installing Python packages (requests, rich)..."
pip install --quiet --upgrade pip
pip install --quiet requests rich
print_success "Python packages installed"

deactivate

# Создание metrics_viewer.py
print_info "Creating metrics_viewer.py..."
cat > "$INSTALL_DIR/metrics_viewer.py" << 'VIEWEREOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import requests
import re
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich import box
from collections import defaultdict
import sys
import argparse

METRICS_URL = "http://localhost:9090/metrics"
console = Console()

def fetch_metrics(url):
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        return response.text
    except requests.RequestException as e:
        console.print(f"[red]Error fetching metrics: {e}[/red]")
        sys.exit(1)

def parse_metrics(text):
    metrics = {}
    help_texts = {}
    types = {}
    for line in text.strip().split('\n'):
        line = line.strip()
        if not line:
            continue
        if line.startswith('# HELP'):
            match = re.match(r'# HELP (\S+) (.+)', line)
            if match:
                help_texts[match.group(1)] = match.group(2)
        elif line.startswith('# TYPE'):
            match = re.match(r'# TYPE (\S+) (\S+)', line)
            if match:
                types[match.group(1)] = match.group(2)
        elif not line.startswith('#'):
            match = re.match(r'(\S+?)\{(.+?)\}\s+(.+)', line)
            if match:
                name, labels, value = match.groups()
                if name not in metrics:
                    metrics[name] = []
                metrics[name].append({'labels': dict(re.findall(r'(\w+)="([^"]*)"', labels)), 'value': value})
            else:
                match = re.match(r'(\S+)\s+(.+)', line)
                if match:
                    name, value = match.groups()
                    if name not in metrics:
                        metrics[name] = []
                    metrics[name].append({'labels': {}, 'value': value})
    return metrics, help_texts, types

def format_value(value):
    try:
        num = float(value)
        if num == int(num):
            return f"{int(num):,}".replace(',', ' ')
        return f"{num:,.2f}".replace(',', ' ')
    except:
        return value

def format_bytes(value):
    try:
        num = float(value)
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if abs(num) < 1024:
                return f"{num:.2f} {unit}"
            num /= 1024
        return f"{num:.2f} PB"
    except:
        return value

def format_uptime(seconds):
    try:
        sec = float(seconds)
        days = int(sec // 86400)
        hours = int((sec % 86400) // 3600)
        mins = int((sec % 3600) // 60)
        secs = int(sec % 60)
        parts = []
        if days > 0:
            parts.append(f"{days}d")
        if hours > 0:
            parts.append(f"{hours}h")
        if mins > 0:
            parts.append(f"{mins}m")
        if secs > 0 or not parts:
            parts.append(f"{secs}s")
        return ' '.join(parts)
    except:
        return seconds

def get_metric_value(metrics, metric_name, default='0'):
    if metric_name in metrics and metrics[metric_name]:
        return metrics[metric_name][0]['value']
    return default

def create_header():
    return Panel.fit("[bold cyan]PROMETHEUS METRICS VIEWER[/bold cyan]\n[dim]MTProtoMax proxy server metrics dashboard[/dim]", border_style="blue", padding=(1, 2))

def create_status_panel(metrics):
    uptime_val = get_metric_value(metrics, 'telemt_uptime_seconds', '0')
    uptime = format_uptime(uptime_val)
    total_conn = int(float(get_metric_value(metrics, 'telemt_connections_total', '0')))
    bad_conn = int(float(get_metric_value(metrics, 'telemt_connections_bad_total', '0')))
    good_conn = total_conn - bad_conn
    upstream_total = int(float(get_metric_value(metrics, 'telemt_upstream_connect_attempt_total', '0')))
    upstream_success = int(float(get_metric_value(metrics, 'telemt_upstream_connect_success_total', '0')))
    upstream_rate = (upstream_success / upstream_total * 100) if upstream_total > 0 else 0
    auth_rate = (good_conn / total_conn * 100) if total_conn > 0 else 0
    if upstream_rate > 95:
        status_emoji = "[green]OK[/green]"
        status_text = "EXCELLENT"
        status_color = "green"
    elif upstream_rate > 80:
        status_emoji = "[yellow]WARN[/yellow]"
        status_text = "WARNING"
        status_color = "yellow"
    else:
        status_emoji = "[red]CRIT[/red]"
        status_text = "CRITICAL"
        status_color = "red"
    content = f"""
[bold]Status:[/bold] {status_emoji} {status_text}
[bold]Uptime:[/bold] [cyan]{uptime}[/cyan]

[bold]Connections:[/bold]
  Total:        {format_value(str(total_conn))}
  Authorized:   [green]{format_value(str(good_conn))}[/green] ({auth_rate:.1f}%)
  Rejected:     [red]{format_value(str(bad_conn))}[/red] (no valid secret)

[bold]Upstream:[/bold]
  Attempts:     {format_value(str(upstream_total))}
  Success:      [green]{format_value(str(upstream_success))}[/green]
  Failed:       [red]{format_value(str(upstream_total - upstream_success))}[/red]
  Success rate: [{status_color}]{upstream_rate:.1f}%[/{status_color}]
"""
    return Panel(content.strip(), title="Summary", border_style=status_color, padding=(1, 2))

def create_users_table(metrics):
    table = Table(title="User Statistics", box=box.ROUNDED, show_header=True, header_style="bold magenta", title_style="bold white")
    table.add_column("User", style="cyan", min_width=15)
    table.add_column("Total Conn", justify="right", style="green", min_width=12)
    table.add_column("Active Now", justify="right", style="yellow", min_width=12)
    table.add_column("Received (RX)", justify="right", style="blue", min_width=15)
    table.add_column("Sent (TX)", justify="right", style="blue", min_width=15)
    users = defaultdict(dict)
    for metric_name in ['telemt_user_connections_total', 'telemt_user_connections_current', 'telemt_user_octets_from_client', 'telemt_user_octets_to_client']:
        if metric_name in metrics:
            for item in metrics[metric_name]:
                user = item['labels'].get('user', 'unknown')
                users[user][metric_name] = item['value']
    sorted_users = sorted(users.items(), key=lambda x: int(float(x[1].get('telemt_user_connections_total', '0'))), reverse=True)
    for user, data in sorted_users:
        table.add_row(user, format_value(data.get('telemt_user_connections_total', '0')), format_value(data.get('telemt_user_connections_current', '0')), format_bytes(data.get('telemt_user_octets_from_client', '0')), format_bytes(data.get('telemt_user_octets_to_client', '0')))
    return table

def main():
    parser = argparse.ArgumentParser(description='Prometheus Metrics Viewer')
    parser.add_argument('--url', default=METRICS_URL, help='Prometheus metrics URL')
    parser.add_argument('--section', choices=['all', 'status', 'users'], default='all', help='Show specific section')
    args = parser.parse_args()
    console.clear()
    console.print("[bold blue]Loading metrics...[/bold blue]")
    raw_metrics = fetch_metrics(args.url)
    metrics, help_texts, types = parse_metrics(raw_metrics)
    console.clear()
    console.print(create_header())
    console.print()
    if args.section in ['all', 'status']:
        console.print(create_status_panel(metrics))
        console.print()
    if args.section in ['all', 'users']:
        console.print(create_users_table(metrics))
        console.print()
    console.print(f"[dim]Source: {args.url}[/dim]")

if __name__ == "__main__":
    main()
VIEWEREOF

chmod +x "$INSTALL_DIR/metrics_viewer.py"
print_success "metrics_viewer.py created"

# Создание metrics_live.py
print_info "Creating metrics_live.py..."
cat > "$INSTALL_DIR/metrics_live.py" << 'LIVEEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import requests
import re
import time
from rich.console import Console
from rich.table import Table
from rich.live import Live
from rich.panel import Panel
from rich.text import Text
from rich import box
from collections import defaultdict
from datetime import datetime

METRICS_URL = "http://localhost:9090/metrics"
REFRESH_INTERVAL = 5
console = Console()

def fetch_metrics(url):
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        return response.text
    except:
        return None

def parse_metrics(text):
    if not text:
        return {}, {}, {}
    metrics = {}
    help_texts = {}
    types = {}
    for line in text.strip().split('\n'):
        line = line.strip()
        if not line:
            continue
        if line.startswith('# HELP'):
            match = re.match(r'# HELP (\S+) (.+)', line)
            if match:
                help_texts[match.group(1)] = match.group(2)
        elif line.startswith('# TYPE'):
            match = re.match(r'# TYPE (\S+) (\S+)', line)
            if match:
                types[match.group(1)] = match.group(2)
        elif not line.startswith('#'):
            match = re.match(r'(\S+?)\{(.+?)\}\s+(.+)', line)
            if match:
                name, labels, value = match.groups()
                if name not in metrics:
                    metrics[name] = []
                metrics[name].append({'labels': dict(re.findall(r'(\w+)="([^"]*)"', labels)), 'value': value})
            else:
                match = re.match(r'(\S+)\s+(.+)', line)
                if match:
                    name, value = match.groups()
                    if name not in metrics:
                        metrics[name] = []
                    metrics[name].append({'labels': {}, 'value': value})
    return metrics, help_texts, types

def format_value(value):
    try:
        num = float(value)
        if num == int(num):
            return f"{int(num):,}".replace(',', ' ')
        return f"{num:,.2f}".replace(',', ' ')
    except:
        return value

def format_uptime(seconds):
    try:
        sec = float(seconds)
        days = int(sec // 86400)
        hours = int((sec % 86400) // 3600)
        mins = int((sec % 3600) // 60)
        return f"{days}d {hours}h {mins}m"
    except:
        return seconds

def get_metric_value(metrics, metric_name, default='0'):
    if metric_name in metrics and metrics[metric_name]:
        return metrics[metric_name][0]['value']
    return default

def generate_dashboard(metrics, help_texts):
    uptime = format_uptime(get_metric_value(metrics, 'telemt_uptime_seconds'))
    total_conn = int(float(get_metric_value(metrics, 'telemt_connections_total')))
    upstream_total = int(float(get_metric_value(metrics, 'telemt_upstream_connect_attempt_total')))
    upstream_success = int(float(get_metric_value(metrics, 'telemt_upstream_connect_success_total')))
    upstream_rate = (upstream_success / upstream_total * 100) if upstream_total > 0 else 0
    status_color = "green" if upstream_rate > 95 else "yellow" if upstream_rate > 80 else "red"
    status_emoji = "[green]OK[/green]" if upstream_rate > 95 else "[yellow]WARN[/yellow]" if upstream_rate > 80 else "[red]CRIT[/red]"
    now = datetime.now().strftime("%H:%M:%S")
    header = Panel(f"[bold white]{status_emoji} MTPROTOMAX METRICS LIVE[/bold white]  |  Uptime: [cyan]{uptime}[/cyan]  |  Upstream: [{status_color}]{upstream_rate:.1f}%[/{status_color}]  |  [dim]{now}[/dim]", box=box.ROUNDED, border_style="blue")
    info = Text(f"Total connections: {format_value(str(total_conn))}\nUpstream success: {upstream_rate:.1f}%\n\nPress Ctrl+C to exit", style="white")
    panel = Panel(info, title="Status", border_style=status_color)
    final = Table.grid(expand=True)
    final.add_row(header)
    final.add_row(panel)
    return final

def main():
    console.print("[bold blue]Starting live metrics viewer...[/bold blue]")
    time.sleep(1)
    with Live(console=console, refresh_per_second=1, screen=True) as live:
        while True:
            try:
                raw = fetch_metrics(METRICS_URL)
                metrics, helps, types = parse_metrics(raw)
                if metrics:
                    dashboard = generate_dashboard(metrics, helps)
                    live.update(dashboard)
                else:
                    live.update(Panel("[red]Cannot fetch metrics[/red]", title="Error"))
                time.sleep(REFRESH_INTERVAL)
            except KeyboardInterrupt:
                console.print("\n[yellow]Exiting...[/yellow]")
                break
            except Exception as e:
                live.update(Panel(f"[red]Error: {e}[/red]"))
                time.sleep(REFRESH_INTERVAL)

if __name__ == "__main__":
    main()
LIVEEOF

chmod +x "$INSTALL_DIR/metrics_live.py"
print_success "metrics_live.py created"

# Создание wrapper скриптов
print_info "Creating wrapper scripts..."

cat > "$INSTALL_DIR/metrics" << 'WRAPEOF'
#!/bin/bash
cd /root/Metrics
source venv/bin/activate
python3 metrics_viewer.py "$@"
deactivate
WRAPEOF
chmod +x "$INSTALL_DIR/metrics"

cat > "$INSTALL_DIR/metrics-live" << 'WRAPLIVEEOF'
#!/bin/bash
cd /root/Metrics
source venv/bin/activate
python3 metrics_live.py
deactivate
WRAPLIVEEOF
chmod +x "$INSTALL_DIR/metrics-live"

print_success "Wrapper scripts created"

# Создание симлинков
print_info "Creating global symlinks..."
ln -sf "$INSTALL_DIR/metrics" /usr/local/bin/metrics
ln -sf "$INSTALL_DIR/metrics-live" /usr/local/bin/metrics-live
print_success "Symlinks created"

# Создание README
print_info "Creating README..."
cat > "$INSTALL_DIR/README.md" << 'READMEEOF'
# MTProtoMax Metrics Viewer

## Usage

### Static view
```bash
metrics
metrics --section status
metrics --section users
