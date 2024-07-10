#!/bin/bash

DEPLOYMENT_DIR="$DEPLOYMENT_DIR"
source $DEPLOYMENT_DIR/.env --source-only
VERSION="$VERSION"

DC_DIR=${DEPLOYMENT_DIR}/syntho-charts-${VERSION}/docker-compose
echo "DC_DIR=$DC_DIR" >> "$DEPLOYMENT_DIR/.pre.deployment.ops.env"
