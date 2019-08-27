#! perl -w
################################################################################
#
# Copyright (c) 2019 Boxing Beetle All rights reserved.
# 
# ------------------------------------------------------------------------------
#
#        Project: test_wraptree
# Component name: wrappers
#       Filename: wrapper.pl
#   First Author: Hans Spanjers
#  Creation date: 2019-02-26
#
# Description:
# This wrapper will test 'wraptree' in the windows environment.
#
# ------------------------------------------------------------------------------
# 
# Input products:
# WRAPTREE_TESTS_ROOT
# WRAPTREE_EXE
# 
# Output products:
# <none>
#
# ------------------------------------------------------------------------------
#
# Parameters:
# <none>
# 
################################################################################

use strict;
use warnings;
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::ReadBackwards;
use Cwd qw(getcwd);
#use File::Remove qw(remove);

my $old_handle = select(STDOUT);    # "select" STDOUT and save previously selected handle
$| = 1;                             # perform flush after each write to STDOUT
select($old_handle);                # restore previously selected handle

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
print "<none>\n";

# Input products
section_begin("Validating input products");
if ((! defined($::WRAPTREE_TESTS_ROOT)) || ($::WRAPTREE_TESTS_ROOT eq "")) {
    print "ERROR: WRAPTREE_TESTS_ROOT is not specified!\n";
    exit_wrapper("Input parameter check failed");
}
print "WRAPTREE_TESTS_ROOT: $::WRAPTREE_TESTS_ROOT\n";

if ((! defined($::WRAPTREE_EXE)) || ($::WRAPTREE_EXE eq "")) {
    print "ERROR: WRAPTREE_EXE is not specified!\n";
    exit_wrapper("Input parameter check failed");
}
print "WRAPTREE_EXE: $::WRAPTREE_EXE\n";

# Output products
section_begin("Validating output products");
print "<none>\n";

###########################
### - BEGIN MAIN PART - ###
###########################

# Now do something useful
my $wrap_result = "";
my $wrap_summary = "";
my $cmd_line = "";
my $cmd_output = "";
my $cmd_rc = "";
my $success = 0;
my $log = "$::SF_REPORT_ROOT\\Test Log.txt";
my $test_path_abs = "$::SF_PRODUCT_ROOT\\$::WRAPTREE_TESTS_ROOT";
my $test_script = "wraptree-test.ps1";
my $dir = "";
my $last_log_line = "";

# Build foreign command
section_begin("Build and execute foreign command");

# Absolute path to test script
$test_path_abs =~ s{/}{\\}g;
print "Path to test script: $test_path_abs\n";

chdir($test_path_abs);
$dir = getcwd;
print "cd \"$dir\"\n";

# Call the PowerShell test script
$cmd_line = "PowerShell \".\\$test_script \'$::WRAPTREE_EXE\'\" >\"$log\"";
print "$cmd_line\n";
# Execute foreign command
`$cmd_line`;
$cmd_rc = $?;
print "Return code=$cmd_rc\n";

chdir($::SF_REPORT_ROOT);
$dir = getcwd;
print "cd \"$dir\"\n";

# Process results of foreign command
section_begin("Process results");

# Create the SF_RESULTS file

# Take the last line from $log
$last_log_line = LastLine($log);

section_begin("Wrapper Results");
if ($cmd_rc == 0 ) {
    $success = 1;
	$wrap_result  = "ok";
	$wrap_summary = $last_log_line;
} else {
	$wrap_result  = "error";
	$wrap_summary = "Exit code $cmd_rc: $last_log_line";
}

print "result=$wrap_result\n";
print "summary=$wrap_summary\n";

open(RESULT, '>', $::SF_RESULTS) or die "Failed to open the results file '$::SF_RESULTS': $!\n";
print RESULT "result=$wrap_result\n";
print RESULT "summary=$wrap_summary\n";
print RESULT "report=$log\n";
close (RESULT);

# Clean up temporary on success
section_begin("Clean up");
if ($success) {
#   remove("");
#   print "removed '$exe'\n";
} else {
    print "nothing removed\n";
}

# Successfully completion of this wrapper
section_begin("End of Wrapper Information: normal exit");
exit(0);

###########################
### -  END MAIN PART  - ###
###########################

sub section_begin {
    my $sectionName = shift;

    print "\n>>>>>>>>>> $sectionName <<<<<<<<<<\n";
}

sub exit_wrapper {
    my $wrap_summary = shift;

    print "$wrap_summary\n";

    open(RESULT, '>', $::SF_RESULTS) || die "Failed to open the results file '$::SF_RESULTS': $!\n";
    print (RESULT "result=error\n");
    print (RESULT "summary=$wrap_summary\n");
    close (RESULT);

    section_begin("End of Wrapper Information: error exit");
    exit;
}

sub LastLine {
	my $file_path = shift;
	my $log_line = "";
	my $bw;

	$bw = File::ReadBackwards->new($file_path, "\n") or
		die "Can't read $file_path\n";

	while( defined( $log_line = $bw->readline ) ) {
		chomp $log_line;
		return $log_line;
	}

	return "";
}
