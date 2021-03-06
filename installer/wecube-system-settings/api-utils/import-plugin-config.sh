#!/bin/bash

set -e

SYS_SETTINGS_ENV_FILE=$1
PLUGIN_CONFIG_FILE=$2

source $SYS_SETTINGS_ENV_FILE

SCRIPT_DIR=$(dirname "$0")
PLUGIN_PKG_COORDS=$(basename $PLUGIN_CONFIG_FILE .xml)

[ -z "$ACCESS_TOKEN" ] && ACCESS_TOKEN=$($SCRIPT_DIR/login.sh $SYS_SETTINGS_ENV_FILE)
http --ignore-stdin --check-status --follow \
	--form --body POST "http://${CORE_HOST}:19090/platform/v1/plugins/packages/import/$PLUGIN_PKG_COORDS" \
	"Authorization:Bearer $ACCESS_TOKEN" \
	xml-file@"$PLUGIN_CONFIG_FILE" \
	| $SCRIPT_DIR/check-status-in-json.sh
