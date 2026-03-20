# MTProtoMax Metrics Viewer

Beautiful terminal dashboard for MTProtoMax Telegram proxy with Prometheus metrics.

[![Version](https://img.shields.io/badge/version-1.0-blue)](https://github.com/Liafanx/mtproxymax-metrics)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## Features

✨ **Beautiful terminal UI** with colors and tables  
📊 **Real-time metrics** visualization  
👥 **User statistics** - connections, traffic, messages  
🔼 **Upstream monitoring** - connection stats and duration  
🔄 **ME statistics** - multiplexed endpoint monitoring  
⚡ **Live mode** - auto-refresh every 5 seconds  

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/Liafanx/mtproxymax-metrics/main/install.sh | sudo bash
Or with wget:

Bash

wget -qO- https://raw.githubusercontent.com/Liafanx/mtproxymax-metrics/main/install.sh | sudo bash
Requirements
OS: Ubuntu 22.04/24.04 or Debian 11/12
MTProtoMax with Prometheus metrics enabled on port 9090
Python: 3.10+
Access: Root/sudo privileges
Usage
View all metrics (static)
Bash

metrics
Live auto-refresh mode
Bash

metrics-live
Press Ctrl+C to exit live mode.

View specific sections
Bash

metrics --section status     # Status summary only
metrics --section users      # User statistics only
metrics --section upstream   # Upstream statistics
metrics --section me         # ME statistics
metrics --section pool       # Pool management
metrics --section socks      # SOCKS KDF Policy
Screenshots
Status Dashboard
text

================================================
  PROMETHEUS METRICS VIEWER
  MTProtoMax metrics dashboard
================================================

┌─ Summary ──────────────────────────────────┐
│ Status: OK EXCELLENT                       │
│ Uptime: 2d 5h 23m                         │
│                                            │
│ Connections:                               │
│   Total:      24,532                      │
│   Authorized: 4,123 (16.8%)               │
│   Rejected:   20,409 (no secret)          │
│                                            │
│ Upstream:                                  │
│   Attempts: 65,234                        │
│   Success:  64,890                        │
│   Failed:   344                           │
│   Rate:     99.5%                         │
└────────────────────────────────────────────┘

┌─ User Statistics ──────────────────────────┐
│ User    │ Connections │ Active │ RX      │
├─────────┼─────────────┼────────┼─────────┤
│ admin   │ 15,234      │ 12     │ 2.5 GB  │
│ user1   │ 8,456       │ 5      │ 1.2 GB  │
└─────────┴─────────────┴────────┴─────────┘
Live Mode
Auto-refreshes every 5 seconds with real-time updates.

Installation Details
The installer will:

Install Python 3 and required system packages
Create /root/Metrics/ directory
Set up Python virtual environment
Install requests and rich libraries
Download viewer scripts
Create global commands: metrics and metrics-live
Manual Installation
If you prefer manual installation:

Bash

# Clone repository
git clone https://github.com/Liafanx/mtproxymax-metrics.git
cd mtproxymax-metrics

# Run installer
sudo bash install.sh
Configuration
Change metrics URL
Edit these files:

/root/Metrics/metrics_viewer.py (line 11)
/root/Metrics/metrics_live.py (line 10)
Change:

Python

METRICS_URL = "http://localhost:9090/metrics"
Change refresh interval (live mode)
Edit /root/Metrics/metrics_live.py (line 11):

Python

REFRESH_INTERVAL = 5  # seconds
Uninstall
Quick uninstall
Bash

curl -sSL https://raw.githubusercontent.com/Liafanx/mtproxymax-metrics/main/uninstall.sh | sudo bash
Manual uninstall
Bash

sudo rm -rf /root/Metrics
sudo rm -f /usr/local/bin/metrics
sudo rm -f /usr/local/bin/metrics-live
Troubleshooting
Metrics not accessible
Check if MTProtoMax is running:

Bash

systemctl status mtprotomax
Test metrics endpoint:

Bash

curl http://localhost:9090/metrics
Python errors
Reinstall dependencies:

Bash

cd /root/Metrics
source venv/bin/activate
pip install --upgrade requests rich
deactivate
Command not found
Check symlinks:

Bash

ls -la /usr/local/bin/metrics*
Recreate symlinks:

Bash

sudo ln -sf /root/Metrics/metrics /usr/local/bin/metrics
sudo ln -sf /root/Metrics/metrics-live /usr/local/bin/metrics-live
File Structure
text

/root/Metrics/
├── venv/                    # Python virtual environment
├── metrics_viewer.py        # Main viewer script
├── metrics_live.py          # Live viewer script
├── metrics                  # Wrapper script
└── metrics-live             # Live mode wrapper

/usr/local/bin/
├── metrics -> /root/Metrics/metrics
└── metrics-live -> /root/Metrics/metrics-live
Metrics Explained
Metric	Description
telemt_connections_total	Total accepted connections
telemt_connections_bad_total	Rejected connections (no valid secret)
telemt_upstream_connect_attempt_total	Upstream connection attempts
telemt_upstream_connect_success_total	Successful upstream connections
telemt_upstream_connect_fail_total	Failed upstream connections
telemt_me_reconnect_attempts_total	ME reconnection attempts
telemt_me_reconnect_success_total	Successful ME reconnections
telemt_user_connections_total	Per-user connection count
telemt_user_octets_from_client	Bytes received from client
telemt_user_octets_to_client	Bytes sent to client
