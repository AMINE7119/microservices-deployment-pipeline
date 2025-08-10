#!/bin/bash

# Setup script for User Service Python environment using uv

echo "Setting up Python virtual environment for User Service with uv..."

# Install uv if not already installed
if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.cargo/env
fi

# Create virtual environment with uv if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment with uv..."
    uv venv
fi

# Install requirements with uv
echo "Installing requirements with uv..."
uv pip install -r requirements.txt

echo "Setup complete! Virtual environment is ready."
echo "To activate the environment, run: source .venv/bin/activate"