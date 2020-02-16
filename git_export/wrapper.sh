#!/bin/bash

# This wrapper is used by the Git export of different modules. Per module a
# different set of output products is defined.

# This wrapper consumes the following input products:
#	<none>:

# It uses the following input parameters:
#   GIT_REPO_URL:       for example: https://git.example.com/project.git
#   GIT_PATH_<prod>:    subdirectory to append to <prod>_ROOT locator
#   GIT_REVISION:       specifies branch, tag or commit ID to retrieve
#   PRUNE:              yes: remove sibling directories (single ROOT product)
#                       no: per definition in case of multiple ROOT products

# The wrapper produces (on success) the following output products:
#   <mod>_REVISION:     commit ID of exported module
#   <mod>_ROOT:         root specification of exported module

function exit_with_error() {
    wrap_summary=$1

    echo "$wrap_summary"

    # write to SF_RESULTS file (results.properties)
    echo "result=error" > "$SF_RESULTS"
    echo "summary=$wrap_summary" >> "$SF_RESULTS"

    exit 0
}

function prune_siblings() {
    child="$1"		# Child which siblings should be pruned

    if [ ! -d "$TOP_DIR" ]; then
        exit_with_error "$TOP_DIR is not a directory"
    fi

    if [ ! -d "$child" ]; then
        exit_with_error "$child is not a directory"
    fi

    if [ "$child" != "$TOP_DIR" ]; then
        echo "...siblings of $child"

        parent=`dirname "$child"`
        parent_basename=`basename "$parent"`
        target_basename=`basename "$child"`

        # Prune children of $parent but not "." and $child
        find "$parent" -maxdepth 1 -type d \
                \( ! -name "$parent_basename" \) \
                \( ! -name "$target_basename" \) \
                | sort | while read sibling; do
            echo " >" `basename "$sibling"`
            rm -rf "$sibling"
        done

        # Now prune the siblings of the parent
        next_parent=`realpath "$parent"`
        prune_siblings "$next_parent"
    fi
}

if [ -n "$GIT_REVISION" ]; then
	REVISION_OPT="--branch $GIT_REVISION"
else
	REVISION_OPT=""
fi

if [ -z "$GIT_PRODUCT" ]; then
	GIT_PRODUCT="export"
fi

# default: do not prune
if [ -z "$PRUNE" ] || [ $PRUNE != "yes" ]; then
    PRUNE="no"
fi

# Set PRUNE to 'no' in case of multiple ROOT products
ROOT_CNT=0
for OUTPUT in "$SF_OUTPUTS"; do
    if [ ${OUTPUT: -5} == _ROOT ]; then
        ROOT_CNT=$((ROOT_CNT+1))
    fi
done
if [ $ROOT_CNT -ne 1 ]; then
    if [ $PRUNE == "yes" ]; then
        echo "Pruning not possible due to multiple ROOT products"
    fi
    PRUNE="no"
fi

echo "Exporting from Git: $GIT_REPO_URL"
echo "Prune: $PRUNE"
mkdir -p "$SF_PRODUCT_ROOT"
cd "$SF_PRODUCT_ROOT"
CMD="git clone --depth 1 --recurse-submodules --shallow-submodules $REVISION_OPT -- \"$GIT_REPO_URL\" \"$GIT_PRODUCT\""
echo $CMD
eval $CMD
GIT_RESULT=$?
EXPORTED_REVISION=`cd "$GIT_PRODUCT" && git rev-parse HEAD`

#
# On success and if needed, prune sibling directories; leave files untouched
#
if [ $GIT_RESULT == 0 ] && [ $PRUNE == "yes" ]; then
    echo "Pruning..."

    for OUTPUT in "$SF_OUTPUTS"; do
        if [ ${OUTPUT: -5} == _ROOT ]; then
            eval TARGET='${'"GIT_PATH_${OUTPUT:0:-5}"'}'
        fi
    done

    TOP_DIR=`realpath "$SF_PRODUCT_ROOT/$GIT_PRODUCT"`
    TARGET_DIR=`realpath "$TOP_DIR/$TARGET"`

    prune_siblings "$TARGET_DIR"
fi

#
# Prepare results
#
if [ $GIT_RESULT != 0 ]; then
	RESULT="error"
	SUMMARY="Export failed: Git returned exit code $GIT_RESULT"
else
	if [ -z "$EXPORTED_REVISION" ]; then
		RESULT="error"
		SUMMARY="Could not get revision number from Git export"
	else
		RESULT="ok"
		SUMMARY="Exported revision $EXPORTED_REVISION"
	fi
fi

# write to SF_RESULTS file (results.properties)
echo "result=$RESULT" > "$SF_RESULTS"
echo "summary=$SUMMARY" >> "$SF_RESULTS"

#
# Generate for all required output products the locator in the result file
#
if [ $RESULT == ok ]; then
    for OUTPUT in "$SF_OUTPUTS"; do
        if [ ${OUTPUT: -5} == _ROOT ]; then
            eval GIT_PATH='${'"GIT_PATH_${OUTPUT:0:-5}"'}'
            echo "output.$OUTPUT.locator=$GIT_PRODUCT/$GIT_PATH" >> "$SF_RESULTS"
        elif [ ${OUTPUT: -9} == _REVISION ]; then
            echo "output.$OUTPUT.locator=$EXPORTED_REVISION" >> "$SF_RESULTS"
        fi
    done
    # mid level data
    echo "data.git_revision=$EXPORTED_REVISION" >> "$SF_RESULTS"
else
    # write error message to stdout / wrapper_log.txt
    echo $SUMMARY
fi
