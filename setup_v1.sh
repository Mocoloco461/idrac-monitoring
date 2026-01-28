#!/bin/bash
set -e

# This script runs automatically when the InfluxDB container is initialized.
# It sets up v1 compatibility so Grafana can query the bucket using InfluxQL.

# Ensure we have the necessary environment variables
if [ -z "$DOCKER_INFLUXDB_INIT_BUCKET" ] || [ -z "$DOCKER_INFLUXDB_INIT_ADMIN_TOKEN" ]; then
    echo "Required environment variables are missing. Skipping v1 setup."
    exit 0
fi

# Set up the CLI to use the admin token
export INFLUX_TOKEN=${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}
export INFLUX_ORG=${DOCKER_INFLUXDB_INIT_ORG}

echo "Starting InfluxDB v1 compatibility setup..."

# 1. Get the Bucket ID for the configured bucket
BUCKET_ID=$(influx bucket list -n "${DOCKER_INFLUXDB_INIT_BUCKET}" --hide-headers | cut -f 1)

if [ -z "$BUCKET_ID" ]; then
    echo "Error: Bucket '${DOCKER_INFLUXDB_INIT_BUCKET}' not found!"
    exit 1
fi

echo "Found Bucket ID: ${BUCKET_ID}"

# 2. Create DBRP (Database Retention Policy) mapping
# This allows queries to 'idrac' database (v1 style) to resolve to the bucket
echo "Creating DBRP mapping for database '${DOCKER_INFLUXDB_INIT_BUCKET}'..."
influx v1 dbrp create \
  --db "${DOCKER_INFLUXDB_INIT_BUCKET}" \
  --rp autogen \
  --bucket-id "${BUCKET_ID}" \
  --default || echo "DBRP mapping might already exist."

# 3. Create v1 compatible authentication
# This maps the username/password to the bucket permissions
echo "Creating v1 auth user '${DOCKER_INFLUXDB_INIT_USERNAME}'..."
influx v1 auth create \
  --username "${DOCKER_INFLUXDB_INIT_USERNAME}" \
  --password "${DOCKER_INFLUXDB_INIT_PASSWORD}" \
  --write-bucket "${BUCKET_ID}" \
  --read-bucket "${BUCKET_ID}" || echo "User might already exist, skipping."

echo "InfluxDB v1 compatibility setup complete."
