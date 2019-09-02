#! perl -w
################################################################################
#
# Copyright (c) 2019 Boxing Beetle All rights reserved.
# 
# ------------------------------------------------------------------------------
#
#        Project: test_abort_wrapper
# Component name: wrappers
#       Filename: wrapper.pl
#   First Author: Hans Spanjers
#  Creation date: 2019-08-28
#
# Description:
# This wrapper will test the 'Abort Wrapper' feature.
#
# ------------------------------------------------------------------------------
# 
# Input products:
# <none>
# 
# Output products:
# <none>
#
# ------------------------------------------------------------------------------
#
# Parameters:
# MaxTicks:			'wrapper' will run at maximum 'MaxTicks' timer ticks
# 
# ------------------------------------------------------------------------------
#
# Design:
#
# Global:
# - a timer tick will be 10 seconds
# - every tick will be logged in file 'ticks_log'
# - be aware of the effects of 'wraptree' (if used)
# - make use of the task definition setting "time out" feature to let the CC initiate
#   the wrapper abort, so starting the abort wrapper
#
# wrapper:
# - In SoftFab environment
# - Parameters: MaxTicks
# - determine pid of this wrapper ('wrapper'.PID) which will be used by the abort
#   wrapper to kill (SIGKILL) the wrapper as part of the "wrapper abort"
# - Write pid file
# - until 'MaxTicks' ticks write every tick a time stamped line in 'ticks_log' and
#   flush 'ticks_log'
# - if this point is reached the test fails because this wrapper is still alive
# - write SF_RESULTS (results.properties)
#
# abort_wrapper:
# - In SoftFab environment
# - Parameters: MaxTicks
# - verify that 'wrapper'.PID is not running
# - determine number of ticks 'wrapper.PID' was alive by counting the lines in
#   'ticks_log'
# - use SF_TIMEOUT to determine the number of ticks occurred
# - write SF_RESULTS (results-abort.properties)
#
#################################################################################

use strict;
use warnings;
use Time::localtime;

my $old_handle = select(STDOUT);    # "select" STDOUT and save previously selected handle
$| = 1;                             # perform flush after each write to STDOUT
select($old_handle);                # restore previously selected handle

my $MaxTicks;						# wrapper parameter

# TODO Move to execute.pl?
# Reflect hosting OS in wrapper log
print "Hosting Operating System is '$^O'\n";

# SoftFab context
section_begin("SoftFab input parameters");
print "SF_JOB_ID      : $::SF_JOB_ID\n";
print "SF_TASK_ID     : $::SF_TASK_ID\n";
print "SF_WRAPPER_ROOT: $::SF_WRAPPER_ROOT\n";
print "SF_TARGET      : $::SF_TARGET\n";
print "SF_REPORT_ROOT : $::SF_REPORT_ROOT\n";
print "SF_RESULTS     : $::SF_RESULTS\n";
print "SF_PRODUCT_ROOT: $::SF_PRODUCT_ROOT\n";

############################
### -  SANITY CHECKS   - ###
############################

# Parameters
section_begin("Validating input parameters");

# Parameter 'MaxTicks'
if ((! defined($::MaxTicks)) || ($::MaxTicks eq "")) {
    print "ERROR: MaxTicks is not specified!\n";
    exit_wrapper("Input parameter check failed");
}
$MaxTicks = $::MaxTicks;
print "MaxTicks       : $MaxTicks\n";

# Expected combination with SF_TIMEOUT?
#if ( $WrapperRunTicks > $::SF_TIMEOUT ) {
#	print "WARNING: WrapperRunTicks exceed#s MaxTicks\n";
#}

###########################
### - BEGIN MAIN PART - ###
###########################

my $seconds_per_tick = 10;

my $log = "$::SF_REPORT_ROOT\\Ticks Log.txt";
my $pid_file = "$::SF_REPORT_ROOT\\wrapper.pid";
my $tick_cnt = 0;
my $fh;
# Build foreign command
section_begin("Start the test");

# Write PID file
open($fh, '>', $pid_file) or die "Failed to open $pid_file: $!\n";
print $fh "$$\n";
close $fh;

# Create log file
open($fh, '>', $log) or die "Failed to open $log: $!\n";
print $fh "Planning to write $MaxTicks lines\n";
close $fh;

# Let the CC timeout start the abort process while this wrapper write log lines

# Write every tick a line in the log
while ( $tick_cnt < $MaxTicks ) {

	my $tm = localtime;

	print "Tick: $tick_cnt\n";

	open(my $fh, '>>', $log) or die "Failed to open $log: $!\n";
	fprint_with_timestamp($fh, "Tick: $tick_cnt");
	close $fh;

	sleep $seconds_per_tick;
	$tick_cnt++;
}

# NOTE: if the program reaches this point something went wrong since this
# process should have been killed by now.

print "WARNING: It is not expected to reach this point\n";
print "WARNING: Check the task definition timeout and MaxTicks parameter settings\n";

open(RESULT, '>', $::SF_RESULTS) or die "Failed to open the results file '$::SF_RESULTS': $!\n";
print RESULT "result=warning\n";
print RESULT "summary=Wrapper not aborted in test while that is expected\n";
print RESULT "report=$log\n";
close (RESULT);

exit 0;

###########################
### -  END MAIN PART  - ###
###########################

sub fprint_with_timestamp {
    my $fh = shift;
	my $message = shift;
	my $tm = localtime;

	printf $fh "[%04d-%02d-%02d %02d:%02d:%02d] $message\n",
		$tm->year+1900, ($tm->mon)+1, $tm->mday,
		$tm->hour, $tm->min, $tm->sec;
}

sub section_begin {
    my $sectionName = shift;

    print "\n>>>>>>>>>> $sectionName <<<<<<<<<<\n";
}

sub exit_wrapper {
    my $wrap_summary = shift;

    print "$wrap_summary\n";

    open(RESULT, '>', $::SF_RESULTS) or die "Failed to open the results file '$::SF_RESULTS': $!\n";
    print (RESULT "result=error\n");
    print (RESULT "summary=$wrap_summary\n");
    close (RESULT);

    section_begin("End of Wrapper Information: error exit");
    exit;
}
