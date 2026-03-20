cat > install.sh << 'MAINEOF'
#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  MTProtoMax Metrics Viewer - Installer v1.0${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: Run as root${NC}"
   echo "Usage: sudo bash install.sh"
   exit 1
fi

# Install dependencies
echo -e "${BLUE}Installing dependencies...${NC}"
apt update -qq
apt install -y python3 python3-pip python3-venv curl > /dev/null 2>&1
echo -e "${GREEN}OK: Dependencies installed${NC}"

# Check if directory exists
INSTALL_DIR="/root/Metrics"
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${RED}Directory $INSTALL_DIR already exists${NC}"
    read -p "Remove and reinstall? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
    else
        exit 1
    fi
fi

# Create directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Create virtual environment
echo -e "${BLUE}Creating Python virtual environment...${NC}"
python3 -m venv venv
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet requests rich
deactivate
echo -e "${GREEN}OK: Virtual environment ready${NC}"

# Download Python scripts from GitHub
echo -e "${BLUE}Downloading metrics scripts...${NC}"

curl -sSL https://raw.githubusercontent.com/Liafanx/mtproxymax-metrics/main/src/metrics_viewer.py -o "$INSTALL_DIR/metrics_viewer.py"
curl -sSL https://raw.githubusercontent.com/Liafanx/mtproxymax-metrics/main/src/metrics_live.py -o "$INSTALL_DIR/metrics_live.py"

chmod +x "$INSTALL_DIR/metrics_viewer.py"
chmod +x "$INSTALL_DIR/metrics_live.py"

echo -e "${GREEN}OK: Scripts downloaded${NC}"

# Create wrapper scripts
echo -e "${BLUE}Creating wrapper scripts...${NC}"

cat > "$INSTALL_DIR/metrics" << 'WRAPPER1'
#!/bin/bash
cd /root/Metrics
source venv/bin/activate
python3 metrics_viewer.py "$@"
deactivate
WRAPPER1

chmod +x "$INSTALL_DIR/metrics"

cat > "$INSTALL_DIR/metrics-live" << 'WRAPPER2'
#!/bin/bash
cd /root/Metrics
source venv/bin/activate
python3 metrics_live.py
deactivate
WRAPPER2

chmod +x "$INSTALL_DIR/metrics-live"

# Create symlinks
echo -e "${BLUE}Creating global symlinks...${NC}"
ln -sf "$INSTALL_DIR/metrics" /usr/local/bin/metrics
ln -sf "$INSTALL_DIR/metrics-live" /usr/local/bin/metrics-live

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Installation completed successfully!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Commands:"
echo "  metrics           - View all metrics"
echo "  metrics-live      - Live auto-refresh mode"
echo ""
MAINEOF

chmod +x install.sh
