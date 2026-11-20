#!/bin/bash
set -e

echo "Installing system dependencies..."
sudo apt update -y
sudo apt install -y python3.13 python3.13-venv sshpass

echo "Removing old Python virtual environment..."
rm -rf .venv

echo "Creating Python 3.13 virtual environment..."
python3.13 -m venv .venv

echo "Activating virtual environment..."
source .venv/bin/activate

echo "Upgrading pip..."
python -m pip install --upgrade pip

echo "Installing Python dependencies..."
python -m pip install -r requirements.txt

echo ""
echo "Setup complete"
echo ""
echo "To start working:"
echo "cd $(pwd)"
echo "source .venv/bin/activate"
echo ""
echo "Verify with:"
echo "python --version"
echo "which ansible"
echo "ansible --version"