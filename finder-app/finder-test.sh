#!/bin/sh
#==============================================================================
#                        FINDER-TEST.SH - TEST AUTOMATION SCRIPT
#==============================================================================
# Purpose: Automated testing script for assignment 1 and assignment 2
# Author: Siddhant Jajoo
# 
# This script tests the finder.sh and writer applications by:
# 1. Creating multiple test files with known content
# 2. Running finder.sh to search for that content  
# 3. Verifying the output matches expected results
# 
# Usage: ./finder-test.sh [numfiles] [writestr] [writedir]
#   numfiles - Number of test files to create (default: 10)
#   writestr - String content to write in files (default: AELD_IS_FUN)  
#   writedir - Subdirectory name under /tmp/aeld-data/ (default: none)
#==============================================================================

#------------------------------------------------------------------------------
# 🛡️ SHELL CONFIGURATION - Error Handling & Safety
#------------------------------------------------------------------------------
# set -e: Exit immediately if any command returns non-zero status (fail fast)
# set -u: Treat unset variables as errors (catch typos and undefined vars)
#------------------------------------------------------------------------------
set -e
set -u

#------------------------------------------------------------------------------
# 📋 DEFAULT CONFIGURATION VALUES
#------------------------------------------------------------------------------
# These values are used when command line arguments are not provided
# NUMFILES: Number of test files to create (default: 10)
# WRITESTR: Text content to write in each file (default: AELD_IS_FUN)
# WRITEDIR: Base directory for test files (default: /tmp/aeld-data)
# username: Read from config file, used in test filenames
#------------------------------------------------------------------------------
NUMFILES=10                                     # Default number of files to create
WRITESTR=AELD_IS_FUN                            # Default string content  
WRITEDIR=/tmp/aeld-data                         # Default test directory
username=$(cat /etc/finder-app/conf/username.txt)    # Read username from configuration

#------------------------------------------------------------------------------
# 🔧 COMMAND LINE ARGUMENT PROCESSING
#------------------------------------------------------------------------------
# Flexible argument handling with defaults:
# - 0 args: Use all defaults (10 files, "AELD_IS_FUN", /tmp/aeld-data)
# - 1 arg:  Custom numfiles, default string and directory  
# - 2 args: Custom numfiles and string, default directory
# - 3 args: Custom numfiles, string, and subdirectory
#
# $# = number of arguments passed to script
#------------------------------------------------------------------------------
if [ $# -lt 3 ]  # Less than 3 arguments provided
then
	echo "Using default value ${WRITESTR} for string to write"
	if [ $# -lt 1 ]  # No arguments at all
	then
		echo "Using default value ${NUMFILES} for number of files to write"
		# Keep all defaults: NUMFILES=10, WRITESTR=AELD_IS_FUN, WRITEDIR=/tmp/aeld-data
	else
		# 1 argument provided: use as number of files
		NUMFILES=$1
		# Keep default WRITESTR and WRITEDIR
	fi	
else
	# 3 or more arguments provided: use custom values
	NUMFILES=$1                    # First arg: number of files
	WRITESTR=$2                   # Second arg: string content
	WRITEDIR=/tmp/aeld-data/$3    # Third arg: subdirectory under /tmp/aeld-data/
fi

#------------------------------------------------------------------------------
# 🎯 TEST EXPECTATIONS & SETUP
#------------------------------------------------------------------------------
# MATCHSTR: Expected output from finder.sh script
# Since we create NUMFILES files, each containing WRITESTR once,
# finder.sh should report: NUMFILES files found, NUMFILES matching lines
#------------------------------------------------------------------------------
MATCHSTR="The number of files are ${NUMFILES} and the number of matching lines are ${NUMFILES}"

echo "Writing ${NUMFILES} files containing string ${WRITESTR} to ${WRITEDIR}"

#------------------------------------------------------------------------------
# 🧹 CLEANUP - Remove any existing test directory  
#------------------------------------------------------------------------------
# Remove entire test directory tree to ensure clean test environment
# -r: recursive (remove directories and contents)
# -f: force (don't prompt, ignore non-existent files)
#------------------------------------------------------------------------------
rm -rf "${WRITEDIR}"

#------------------------------------------------------------------------------
# 📁 ASSIGNMENT-SPECIFIC DIRECTORY CREATION
#------------------------------------------------------------------------------
# Different behavior based on assignment type:
# - assignment1: Uses shell scripts, may not need directory creation
# - assignment2+: Uses C applications, needs directory structure
#
# Read assignment type from configuration file
#------------------------------------------------------------------------------
assignment=`cat /etc/finder-app/conf/assignment.txt`

if [ $assignment != 'assignment1' ]
then
	#--------------------------------------------------------------------------
	# 🏗️ CREATE TEST DIRECTORY STRUCTURE
	#--------------------------------------------------------------------------
	# mkdir -p: Create directory and any missing parent directories
	# Quotes around $WRITEDIR are CRITICAL for paths with spaces
	#--------------------------------------------------------------------------
	mkdir -p "$WRITEDIR"

	#--------------------------------------------------------------------------
	# ✅ VERIFY DIRECTORY CREATION SUCCESS
	#--------------------------------------------------------------------------
	# The WRITEDIR is in quotes because if the directory path consists of spaces, then variable substitution will consider it as multiple arguments.
	# The quotes signify that the entire string in WRITEDIR is a single string.
	# This issue can also be resolved by using double square brackets [[ ]]
	# instead of single brackets [ ].
	#--------------------------------------------------------------------------
	if [ -d "$WRITEDIR" ]  # Test if directory exists and is a directory
	then
		echo "$WRITEDIR created"
	else
		echo "ERROR: Failed to create directory $WRITEDIR"
		exit 1  # Exit with error code if directory creation failed
	fi
fi
#------------------------------------------------------------------------------
# 🔨 BUILD PROCESS - Compile Writer Application
#------------------------------------------------------------------------------
# Clean and rebuild the writer C application to ensure we're testing
# the latest version with native compilation (not cross-compiled)
#------------------------------------------------------------------------------
# echo "Removing the old writer utility and compiling as a native application"
# make clean  # Remove old build artifacts (writer executable, .o files)
# make        # Compile writer.c with native gcc (no CROSS_COMPILE)

#------------------------------------------------------------------------------
# 📝 TEST FILE CREATION LOOP  
#------------------------------------------------------------------------------
# Create NUMFILES test files, each containing WRITESTR
# File naming pattern: ${username}1.txt, ${username}2.txt, etc.
# 
# seq 1 $NUMFILES generates: 1 2 3 ... up to $NUMFILES
# Each file gets the same content ($WRITESTR) for consistent testing
#------------------------------------------------------------------------------
for i in $( seq 1 $NUMFILES)  # Loop from 1 to NUMFILES
do
	# Call writer application to create test file
	# Format: writer <filepath> <content>
	# Example: writer /tmp/aeld-data/Karrick39101.txt AELD_IS_FUN
	writer "$WRITEDIR/${username}$i.txt" "$WRITESTR"
done

#------------------------------------------------------------------------------
# 🔍 EXECUTE FINDER SCRIPT AND CAPTURE OUTPUT
#------------------------------------------------------------------------------
# Run finder.sh with test directory and search string
# Capture the entire output for verification
# Expected output format: "The number of files are X and the number of matching lines are Y"
# Write output to /tmp/assignment4-result.txt as required for assignment 4
#------------------------------------------------------------------------------
OUTPUTSTRING=$(finder.sh "$WRITEDIR" "$WRITESTR")
echo "${OUTPUTSTRING}" > /tmp/assignment4-result.txt

#------------------------------------------------------------------------------
# 🧹 CLEANUP - Remove temporary test directories  
#------------------------------------------------------------------------------
# Clean up test files after finder.sh has processed them
# This ensures no test artifacts remain on the system
#------------------------------------------------------------------------------
rm -rf /tmp/aeld-data

#------------------------------------------------------------------------------
# ✅ TEST RESULT VERIFICATION
#------------------------------------------------------------------------------
# Compare finder.sh output against expected result
# set +e: Temporarily disable exit-on-error for result checking
#------------------------------------------------------------------------------
set +e  # Allow grep to fail without exiting script

# Check if finder output contains the expected match string
echo ${OUTPUTSTRING} | grep "${MATCHSTR}"

#------------------------------------------------------------------------------
# 📊 FINAL TEST RESULT EVALUATION  
#------------------------------------------------------------------------------
# $? contains exit code of the last command (grep)
# grep returns 0 if pattern found, 1 if not found
#------------------------------------------------------------------------------
if [ $? -eq 0 ]; then
	# SUCCESS: finder.sh output matches expected format
	echo "success"
	exit 0  # Exit with success code
else
	# FAILURE: finder.sh output doesn't match expected format
	echo "failed: expected  ${MATCHSTR} in ${OUTPUTSTRING} but instead found"
	exit 1  # Exit with error code
fi

#==============================================================================
# 📋 SUMMARY OF TEST PROCESS:
# 1. Parse command line arguments (with defaults)
# 2. Clean any existing test directory  
# 3. Create test directory structure (for assignment2+)
# 4. Build writer application with native compilation
# 5. Create NUMFILES test files using writer application
# 6. Run finder.sh to search for WRITESTR in test files
# 7. Verify finder.sh output matches expected result
# 8. Clean up test files
# 9. Report success/failure and exit with appropriate code
#==============================================================================
