#!/bin/sh
# BFE and conf-agent dual-process startup script

set -e

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Start conf-agent in background
start_conf_agent() {
    if [ -f "/home/work/conf-agent/conf-agent" ]; then
        log "Starting conf-agent..."
        cd /home/work/conf-agent
        nohup ./conf-agent -c ./conf/conf-agent.toml > /home/work/conf-agent/log/conf-agent.log 2>&1 &
        CONF_AGENT_PID=$!
        log "conf-agent started, PID: $CONF_AGENT_PID"
        cd /home/work
    else
        log "Warning: conf-agent binary not found, skipping startup"
    fi
}

# Start bfe in foreground
start_bfe() {
    log "Starting bfe..."
    cd /home/work/bfe/bin
    exec ./bfe -c ../conf/ -l ../log/ -s
}

# Signal handler
handle_signal() {
    log "Received termination signal, shutting down..."
    
    # Terminate conf-agent
    if [ -n "$CONF_AGENT_PID" ]; then
        log "Stopping conf-agent (PID: $CONF_AGENT_PID)..."
        kill -TERM "$CONF_AGENT_PID" 2>/dev/null || true
        wait "$CONF_AGENT_PID" 2>/dev/null || true
    fi
    
    exit 0
}

# Register signal handlers
trap 'handle_signal' TERM INT

# Main process
log "========================================"
log "BFE Container Startup Script"
log "========================================"

# 1. Start conf-agent if exists
start_conf_agent

# Wait for conf-agent initialization
sleep 2

# 2. Start bfe in foreground
start_bfe
