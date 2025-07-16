#!/bin/bash

echo "Checking SentinelOne..."
if ! sudo systemctl is-active --quiet sentinelone; then
  echo "SentinelOne agent not running"
  exit 1
fi

echo "Checking Qualys..."
if ! sudo systemctl is-active --quiet qualys-cloud-agent; then
  echo "Qualys agent not running"
  exit 1
fi

echo "All required agents are running"
