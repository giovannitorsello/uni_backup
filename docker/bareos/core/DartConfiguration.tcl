# This file is configured by CMake automatically as DartConfiguration.tcl
# If you choose not to use CMake, this file may be hand configured, by
# filling in the required variables.


# Configuration directories and files
SourceDirectory: /mnt/storage1/Documenti/Attivita/WIFINETCOM_SRL/SviluppoSoftware/TapeBackup/tapeguard/docker/bareos/bareos/core
BuildDirectory: /mnt/storage1/Documenti/Attivita/WIFINETCOM_SRL/SviluppoSoftware/TapeBackup/tapeguard/docker/bareos/core

# Where to place the cost data store
CostDataFile: 

# Site is something like machine.domain, i.e. pragmatic.crd
Site: Linux-Debian GNU/Linux 13 (trixie)-x86_64

# Build name is osname-revision-compiler, i.e. Linux-2.4.2-2smp-c++
BuildName: 26.0.0~pre370.a2a979d80

# Subprojects
LabelsForSubprojects: 

# Submission information
SubmitURL: https://cdash.bareos.org/submit.php?project=Bareos
SubmitInactivityTimeout: 

# Dashboard start time
NightlyStartTime: 23:00:00 CET

# Commands for the build/test/submit cycle
ConfigureCommand: "/usr/bin/cmake" "/mnt/storage1/Documenti/Attivita/WIFINETCOM_SRL/SviluppoSoftware/TapeBackup/tapeguard/docker/bareos/bareos/core"
MakeCommand: /usr/bin/cmake --build . --config "${CTEST_CONFIGURATION_TYPE}"
DefaultCTestConfigurationType: Release

# version control
UpdateVersionOnly: 

# CVS options
# Default is "-d -P -A"
CVSCommand: 
CVSUpdateOptions: 

# Subversion options
SVNCommand: 
SVNOptions: 
SVNUpdateOptions: 

# Git options
GITCommand: /bin/git
GITInitSubmodules: 
GITUpdateOptions: 
GITUpdateCustom: 

# Perforce options
P4Command: 
P4Client: 
P4Options: 
P4UpdateOptions: 
P4UpdateCustom: 

# Generic update command
UpdateCommand: /bin/git
UpdateOptions: 
UpdateType: git

# Compiler info
Compiler: /bin/c++
CompilerVersion: 14.2.0

# Dynamic analysis (MemCheck)
PurifyCommand: 
ValgrindCommand: 
ValgrindCommandOptions: 
DrMemoryCommand: 
DrMemoryCommandOptions: 
CudaSanitizerCommand: 
CudaSanitizerCommandOptions: 
MemoryCheckType: 
MemoryCheckSanitizerOptions: 
MemoryCheckCommand: /bin/valgrind
MemoryCheckCommandOptions: 
MemoryCheckSuppressionFile: 

# Coverage
CoverageCommand: /bin/gcov
CoverageExtraFlags: -l

# Testing options
# TimeOut is the amount of time in seconds to wait for processes
# to complete during testing.  After TimeOut seconds, the
# process will be summarily terminated.
# Currently set to 25 minutes
TimeOut: 1500

# During parallel testing CTest will not start a new test if doing
# so would cause the system load to exceed this value.
TestLoad: 

TLSVerify: 
TLSVersion: 

UseLaunchers: 
CurlOptions: 
# warning, if you add new options here that have to do with submit,
# you have to update cmCTestSubmitCommand.cxx

# For CTest submissions that timeout, these options
# specify behavior for retrying the submission
CTestSubmitRetryDelay: 5
CTestSubmitRetryCount: 3
