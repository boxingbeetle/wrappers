#! perl -w
################################################################################
#
# Copyright (c) 2019 Boxing Beetle All rights reserved.
# 
# ------------------------------------------------------------------------------
#
#        Project: build wraptree
# Component name: wrappers
#       Filename: wrapper.pl
#   First Author: Hans Spanjers
#  Creation date: 2019-02-25
#
# Description:
# This wrapper will build 'wraptree' in the windows environment. 
#
# ------------------------------------------------------------------------------
# 
# Required environment variable:
# PRODUCT_STORAGEPOOL_URL: specifies the URL of the locally served PRODUCTS root
#
# Input product:
# WRAPTREE_ROOT
#
# Output product:
# WRAPTREE_EXE
# WRAPTREE_EXE_URL
#
# ------------------------------------------------------------------------------
#
# Parameters:
# none
# 
################################################################################

use strict;
use warnings;
use File::Copy qw(copy);
use File::Path qw(make_path);
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

if ((! defined($::WRAPTREE_ROOT)) || ($::WRAPTREE_ROOT eq "")) {
    print "ERROR: WRAPTREE_ROOT is not specified!\n";
    exit_wrapper("Input parameter check failed");
}
print "WRAPTREE_ROOT: $::WRAPTREE_ROOT\n";

# Output products
section_begin("Validating output products");
if ((! defined($::SF_OUTPUTS)) || ($::SF_OUTPUTS eq "")) {
	exit_wrapper("Output product incorrect specified: $::SF_OUTPUTS");
}
print "SF_OUTPUTS: $::SF_OUTPUTS\n";

###########################
### - BEGIN MAIN PART - ###
###########################

# Now do something useful
my $wrap_result = "";
my $wrap_summary = "";
my $cmd_line = "";
my $cmd_rc = "";
my $success = 0;
my $exe = "wraptree.exe";
my $exe_src = "Release\\$exe";
my $log = "$::SF_REPORT_ROOT\\build.txt";
my $root = "$::SF_PRODUCT_ROOT/$::WRAPTREE_ROOT";
my $build_script = "build-wraptree.bat";
my $MSVS_env = "C:/Program Files (x86)/Microsoft Visual Studio/2019/Community/Common7/Tools/VsDevCmd.bat";

# Take SF_JOB_ID and make "day/time-token" format by changing first '-' to '/'
my $chunck = "$::SF_JOB_ID";
$chunck =~ s{-}{/};
# Precede by Task Runner parameter
my $url = $ENV{'PRODUCT_STORAGEPOOL_URL'};
# Get rid of the double quotes
$url =~ s/"//g;
my $product_url = "$url/$chunck";

$MSVS_env =~ s{/}{\\}g;
$root =~ s{/}{\\}g;
print "root: $root\n";

# Build foreign command
section_begin("Build and execute foreign command");

# Change dir to build environment
cdp($root);

# Make build script
MakeBuildScript();

# Call build script
$cmd_line = "cmd /c \"$build_script\" > \"$log\"";
print "$cmd_line\n";

# Execute foreign command
`$cmd_line`;
$cmd_rc = $?;
print "Return code=$cmd_rc\n";

# Change dir back
cdp($::SF_REPORT_ROOT);

# Process results of foreign command
section_begin("Process results");

# Create the SF_RESULTS file
section_begin("Wrapper Results");
if ($cmd_rc == 0 ) {
    $success = 1;
	$wrap_result  = "ok";
	$wrap_summary = "$exe built successfully";
} else {
	$wrap_result  = "warning";
	$wrap_summary = "Could not built $exe (exit code: $cmd_rc)";
}

print "result=$wrap_result\n";
print "summary=$wrap_summary\n";

open(RESULT, '>', $::SF_RESULTS) or die "Failed to open the results file '$::SF_RESULTS': $!\n";
print RESULT "result=$wrap_result\n";
print RESULT "summary=$wrap_summary\n";
print RESULT "report=$log\n";

# produce the output product on success only
if ($success) {
	if (! -e "$::SF_PRODUCT_ROOT") {
		make_path($::SF_PRODUCT_ROOT);
	}

	# Copy exe to SF_PRODUCT_ROOT
	if ( copy("$root\\$exe_src", "$::SF_PRODUCT_ROOT") == 1 ) {
		print "$exe produced\n";
	} else {
		exit_wrapper("Could not produce $exe in \"$::SF_PRODUCT_ROOT\": $!");
	}

	my $wrap_product = "output.WRAPTREE_EXE.locator=$::SF_PRODUCT_ROOT\\$exe";
	print "$wrap_product\n";
    print RESULT "$wrap_product\n";

	my $wrap_product_url = "output.WRAPTREE_EXE_URL.locator=$product_url/$exe";
    print "$wrap_product_url\n";
    print RESULT "$wrap_product_url\n";
}

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

sub MakeBuildScript {
	my $script = "$build_script";

	open(SCRIPT, '>', $script) or die "Failed to open the build file '$script': $!\n";
    print(SCRIPT "call \"$MSVS_env\"\n");
    print(SCRIPT "call msbuild /p:Configuration=Release\n");
    close(SCRIPT);
}

# chdir and print new dir
sub cdp {
	my $dir = shift;

	chdir($dir);
#	$dir = getcwd;
	print "cd \"$dir\"\n";
}

sub section_begin {
    my $sectionName = shift;

    print "\n>>>>>>>>>> $sectionName <<<<<<<<<<\n";
}

sub exit_wrapper {
    my $wrap_summary = shift;

    print "$wrap_summary\n";

    open(RESULT, '>', $::SF_RESULTS) || die "Failed to open the results file '$::SF_RESULTS': $!\n";
    print(RESULT "result=error\n");
    print(RESULT "summary=$wrap_summary\n");
    close(RESULT);

    section_begin("End of Wrapper Information: error exit");
    exit;
}
