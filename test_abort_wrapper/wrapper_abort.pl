#! perl -w
################################################################################
#
# Copyright (c) 2019 Boxing Beetle All rights reserved.
# 
# ------------------------------------------------------------------------------
#
#        Project: test_abort_wrapper
# Component name: wrappers
#       Filename: kill_wrapper
#   First Author: Hans Spanjers
#  Creation date: 2019-08-28
#
# Description:
# This function is part of the 'Abort Wrapper' feature test.
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
# WrapperRunTicks:			'wrapper' was aborted after 'WrapperRunTicks' ticks
# 
# ------------------------------------------------------------------------------
#
# Design:
# - <see wrapper.pl>
#
#################################################################################

use strict;
use warnings;
use Time::localtime;

my $old_handle = select(STDOUT);    # "select" STDOUT and save previously selected handle
$| = 1;                             # perform flush after each write to STDOUT
select($old_handle);                # restore previously selected handle

my $log = "$::SF_REPORT_ROOT\\Ticks Log.txt";
my $pid_file = "$::SF_REPORT_ROOT\\wrapper.pid";

# Correct by -1 for the header
my $ticks = CountLines("$log") - 1;

# Retrieve PID from 'wrapper.pl'
open(my $fh, "<", $pid_file) or die "Failed to open $pid_file: $!\n";
my $pid_wrapper = <$fh>;
close $fh;
chomp $pid_wrapper;

# Kill (SIGKILL) the wrapper
print_with_timestamp("Killing (SIGKILL) wrapper process $pid_wrapper");
my $cnt = kill 'KILL', $pid_wrapper;
print_with_timestamp("Killed $cnt processes\n");

my $SF_RESULTS = "$::SF_REPORT_ROOT\\results.properties";
open(RESULT, '>', $SF_RESULTS) or die "Failed to open the results file '$SF_RESULTS': $!\n";
print RESULT "result=ok\n";
print RESULT "summary=Success: after $ticks ticks the wrapper ($pid_wrapper) was aborted\n";
print RESULT "report.0=$log\n";
#print RESULT "report.1=$wrapperabort_log\n";
close (RESULT);

exit 0;

sub print_with_timestamp {
    my $message = shift;
	my $tm = localtime;

	printf "[%04d-%02d-%02d %02d:%02d:%02d] $message\n",
		$tm->year+1900, ($tm->mon)+1, $tm->mday,
		$tm->hour, $tm->min, $tm->sec;
}

sub CountLines {
	my $file = shift;
	my $count = 0;

	open(my $fh, "< $file") or die "can't open $file: $!";
	$count++ while <$fh>;
	return $count;
}
