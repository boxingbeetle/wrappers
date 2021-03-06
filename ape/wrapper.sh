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

if [ -n "${PYTHON}" ]
then
    poetry env use ${PYTHON} || exit_with_error "Poetry could not select requested Python version"
fi

# Install/update CC dependencies.
poetry update || exit_with_error "Poetry could not install or update dependencies"

# Install/update CC itself.
poetry install || exit_with_error "Poetry could not install or update Control Center"

# Create DB.
DBDIR="$SF_REPORT_ROOT/db"
poetry run sh -c 'softfab -d '"$DBDIR"' init --port '"$CC_PORT" || exit_with_error "Control Center init failed"

# Patch configuration.
echo "Updating configuration..."
echo "logchanges = on" >> "$DBDIR"/softfab.ini || exit_with_error "Control Center config update failed"

# Start CC in background.
echo "Starting Control Center..."
poetry run sh -c 'inv run --dbdir '"$DBDIR"' --coverage APE &> '"$SF_REPORT_ROOT/cc-out.txt"' &' || exit_with_error "Control Center startup failed"
# TODO: Ugly hack to give CC enough time to try and bind a socket.
#       It would be better to let APE sleep + retry a few times
#       on connection refused.
#       https://github.com/boxingbeetle/apetest/issues/21
#       Note that we should still give Invoke the time to write the PID file,
#       but we could simply fetch the PID just before shutdown.
sleep 3
add_cc_logs
CC_PID=`cat "$DBDIR/cc.pid"`
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
    test -d "/proc/$CC_PID" || break
done
if test -d "/proc/$CC_PID"
then
    echo "Graceful shutdown failed."
    kill -s SIGKILL "$CC_PID"
fi

# Output coverage data.
echo "output.COVERAGE.locator=$DBDIR/.coverage" >> "$SF_RESULTS"

exit 0
