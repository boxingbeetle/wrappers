#!/bin/bash

exit_with_error() {
    echo "Aborting build because of error: $1"
    echo "result=error" >> "$SF_RESULTS"
    echo "summary=$1" >> "$SF_RESULTS"
    exit 0
}

add_cc_logs() {
    echo "report.10=$DBDIR/cc-log.txt" >> "$SF_RESULTS"
    echo "report.11=cc-out.txt" >> "$SF_RESULTS"
}

cd "$SF_PRODUCT_ROOT/$CC_ROOT" || exit_with_error "Cannot access source dir"

# Patch configuration.
echo "Patching configuration..."
sed -i "/logChanges = /s%False%True%" src/softfab/config.py

# Install/update CC dependencies.
poetry update || exit_with_error "Poetry could not install or update dependencies"

# Start CC in background.
DBDIR="$SF_REPORT_ROOT/db"
echo "Starting Control Center..."
poetry run sh -c 'inv run --port '"$CC_PORT"' --dbdir '"$DBDIR"' &> '"$SF_REPORT_ROOT/cc-out.txt"' & echo $! > '"$SF_REPORT_ROOT/cc.pid" || exit_with_error "Control Center startup failed"
# TODO: Ugly hack to give CC enough time to try and bind a socket.
#       It would be better to let APE sleep + retry a few times
#       on connection refused.
#       https://github.com/boxingbeetle/apetest/issues/21
CC_PID=`cat "$SF_REPORT_ROOT/cc.pid"`
sleep 3
add_cc_logs
test -d "/proc/$CC_PID" || exit_with_error "Control Center not running"

# Run APE.
# APE should produce the results file when it's done, unless it crashes,
# for which case we'll set up a fallback results file prior to starting APE.
echo "result=error" >> "$SF_RESULTS"
echo "summary=APE did not produce a results file" >> "$SF_RESULTS"
echo "Starting APE..."
poetry run inv ape --port "$CC_PORT" --dbdir "$DBDIR" --results "$SF_RESULTS" &> "$SF_REPORT_ROOT/ape-out.txt"
add_cc_logs
echo "report.20=ape-out.txt" >> "$SF_RESULTS"

# Shut down Control Center.
echo "Shutting down Control Center..."
kill "$CC_PID"
for count in $(seq 1 10)
do
    sleep 1
    test -d "/proc/$CC_PID" && break
done
test -d "/proc/$CC_PID" && kill -9 "$CC_PID"

exit 0
