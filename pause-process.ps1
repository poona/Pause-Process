# Pause/unpause a process. Just provide a PID, and optionally a duration
# by Mick Douglas @BetterSafetyNet

# License: Creative Commons Attribution
# https://creativecommons.org/licenses/by/4.0/

# Warning:
# This script will pause (and unpause) running programs.
# Obviously, this can cause system stability issues.
# The author and contributors of this script assume NO liability for the use of this script.
# Users of this script are **stridently** urged to test in a non-production environment first.

# todos:
# Easy
# create better error logics
# make better help messages 

# Mid-level
# add logics to detect if debugger is attached
# add input validation checks
# - is ID an int?

# HARD!!
# - make -Duration to use ScheduledJob instead of sleep

# Credits:
# Shout out to Dave Kennedy for pointing me to this StackOverflow article.
# https://stackoverflow.com/questions/11010165/how-to-suspend-resume-a-process-in-windows

# Reference links:
# calling Windows API from PowerShell
# https://blog.dantup.com/2013/10/easily-calling-windows-apis-from-powershell/
# https://blogs.technet.microsoft.com/heyscriptingguy/2013/06/25/use-powershell-to-interact-with-the-windows-api-part-1/
# https://msdn.microsoft.com/en-us/library/windows/desktop/ms679295(v=vs.85).aspx

# Majorly interesting article on how to use specific methods in a dll in PowerShell
#https://social.technet.microsoft.com/Forums/ie/en-US/660c36b5-205c-47b6-8b98-aaa97d69a582/use-powershell-to-automate-powerpoint-document-repair-message-response?forum=winserverpowershell



<#

.SYNOPSIS
This is a PowerShell script which allows one to issue Pause-Process or 
UnPause-Process cmdlets.

.DESCRIPTION
This script will allow users to pause and unpause running commands.  This is 
accomplished by attaching a debugger to the selected process.  Removing the
debugger allows the program to resume normal operation.  

Note: not all programs can be paused in this manner.

.EXAMPLE
Import-Module .\pause-process.ps1

.EXAMPLE
Pause-Process -ID [PID]

.EXAMPLE
Pause-Process -ID [PID] -Duration [seconds]

.EXAMPLE
UnPause-Process -ID [PID]

.NOTES
This script is under active development.  It has not been scientifically tested.
It likely will cause system stability issues.  Until you are comfortable with 
how this works... DO NOT USE IN PRODUCTION!

.LINK
https://infosecinnovations.com/Alpha-Testing

#>



$script:nativeMethods = @();
function Register-NativeMethod([string]$dll, [string]$methodSignature)
{
    $script:nativeMethods += [PSCustomObject]@{ Dll = $dll; Signature = $methodSignature; }
}

function Add-NativeMethods()
{
    $nativeMethodsCode = $script:nativeMethods | % { "
        [DllImport(`"$($_.Dll)`")]
        public static extern $($_.Signature);
    " }

    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public static class NativeMethods {
            $nativeMethodsCode
        }
"@
}


# Add methods here
Register-NativeMethod "kernel32.dll" "int DebugActiveProcess(int PID)"
Register-NativeMethod "kernel32.dll" "int DebugActiveProcessStop(int PID)"

# This builds the class and registers them (you can only do this one-per-session, as the type cannot be unloaded?)
Add-NativeMethods


function Pause-Process {

[CmdletBinding()]

    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        [int]$ID,
        [int]$Duration
    )


    Begin {
        # Test to see if this is a running process
        # Do checks to see if we can pause this.
        write-verbose ("you entered an ID of: $ID")
    }


    Process {
        $PauseResult = [NativeMethods]::DebugActiveProcess($ID)
    }


    End {
        # report out if user asked it
        if ($PauseResult -eq $False) {
            # An error occurred. Display any errors thrown
            Write-Error ("Unable to pause process: $ID")

        } else {
            Write-Verbose ("Process $ID was paused")
        }

        # This is a hack. The better approach would be to use a ScheduledJob
        # However, I've not been able to get the environment variables right. 
        # This means that the extensions notably UnPause-Process isn't available.
        # Any help in this area would be most welcomed.

        if ($Duration) {
            Sleep $Duration
            UnPause-Process $ID
        } 
    }

}


function UnPause-Process {

[CmdletBinding()]

    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        [int]$ID
    )

    Begin{
        Write-Verbose ("Attempting to unpause PID: $ID")
    }


    Process {
        # Attempt the unpause
        $UnPauseResult = [NativeMethods]::DebugActiveProcessStop($ID)
    }

    End {
        if ($UnPauseResult -eq $False) {
            # An error occurred. Display any errors thrown
            Write-Error ("unable to unpause process $ID. Is it running or gone?")
    
        } else {
            Write-Verbose ("$ID was resumed")
        }
    }
}