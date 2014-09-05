#!/bin/sh

TESTNUM=0

start_test() {
	local config=$1
	local env=$2
	local expected=${3:-success}

	stackname="test-stack-$TESTNUM"
	let TESTNUM++

	echo "*** starting test: stack $config with environment $env"

	time_start=$(date +%s)
	heat stack-create -f $config -e $env $stackname > /dev/null

	if ! heat stack-list | grep -q $stackname; then
		echo "ERROR: failed to create stack $stackname from $config and $env." >&2
		return 1
	fi

	while :; do
		status=$(heat stack-list | awk -vstackname="$stackname" '
		$4 == stackname {print $6}')

		if [ "$status" == "CREATE_COMPLETE" ]; then
			stack_status=complete
			break
		elif [ "$status" == "CREATE_FAILED" ]; then
			stack_status=failed
			break
		elif ! [ "$status" == "CREATE_IN_PROGRESS" ]; then
			stack_status=unknown
			break
		fi
	done
	time_stop=$(date +%s)

	if [ "$expected" = success ] && [ "$stack_status" = complete ]; then
		test_status=OKAY
	elif [ "$expected" = failure ] && [ "$stack_status" = failed ]; then
		test_status=OKAY
	elif [ "$expected" = success ] && [ "$stack_status" = failed ]; then
		test_status=FAILED
	elif [ "$expected" = failure ] && [ "$stack_status" = complete ]; then
		test_status=FAILED
	else
		test_status=FAILED
	fi

	heat stack-delete $stackname > /dev/null

	duration=$(($time_stop - $time_start))
	echo "*** stack $config environment $env: $test_status ($duration s)"
}

start_test wp-naive.yaml local.yaml
start_test wp-naive.yaml fails.yaml failure
start_test wp-simple.yaml local.yaml
start_test wp-scaling.yaml local.yaml

