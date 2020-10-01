param (
    [Parameter(Mandatory=$true)]
    [string]$Dir = $NULL,
    [switch]$MB = $FALSE,
    [switch]$GB = $FALSE,
    [switch]$Auto = $FALSE,
    [switch]$CSV = $FALSE,
    [switch]$OBJECT = $FALSE
)

function Start-ProcessWaitTimeout
{
    <#
    .SYNOPSIS
    Function to start a process and wait until it completes or reaches a specified time limit in seconds
    .DESCRIPTION
    Function to start a process and wait until it completes or reaches a specified time limit in seconds
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Computer,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$CmdLine,
        [Parameter(ValueFromPipelineByPropertyName)]
        [array]$CmdLineArgs,
        [Parameter(Mandatory=$true)]
        [int]$Timeout
    )
    Begin {
        # Initialize list to hold the process objects
        $ProcessList = New-Object System.Collections.Generic.List[PSObject]
        # Establish Functions to Create and Wait for the Process
        function New-Process
        {
            <#
            .SYNOPSIS
            Create a process   
            .DESCRIPTION
            Create a process
            #>
            param (
                [Parameter(Mandatory=$true)]
                [string]$CmdLine,
                [Parameter(Mandatory=$true)]
                $CmdLineArgs
            )
            ## SET THE PROCESS INFO
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $cmdLine
            $processInfo.RedirectStandardError = $true
            $processInfo.RedirectStandardOutput = $true
            $processInfo.UseShellExecute = $false
            ## SET THE PROCESS
            $processInfo.Arguments = $cmdLineArgs
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            # Return the Process
            Return $process
        }
        function Wait-ForProcess
        {
            <#
            .SYNOPSIS
            Wait for a process to complete.
            .DESCRIPTION
            Wait for a process to complete.
            #>
            param (
                [Parameter(Mandatory=$true)]
                [System.Diagnostics.Process]$Process,
                [Parameter(Mandatory=$true)]
                [int]$TimeoutSeconds
            )          
            $ProcessComplete = $Process.WaitForExit($TimeoutSeconds * 1000)
            if ($ProcessComplete -eq $false)
            {              
                $Process.Kill()
                Return -1
            } else {
                Return 0
            }          
        }
    } # End Begin
    Process {
        # Create the Process Object
        $ProcessObj = [PSCustomObject]@{        
            Computer = $computer
            CmdLine = $cmdLine
            CmdLineArgs = $cmdLineArgs
            Timeout = $timeout
            ProcessStartTime = $null
            ProcessEndTime = $null
            ProcessDuration = $null
            ProcessStdOut = $null
            ProcessStdErr = $null
            ProcessExitCode = $null
            ProcessResult = $null
            Result = $null
            ObjTimeStamp = (get-date)
        }
        # Create the process          
        $Process = New-Process -CmdLine $CmdLine -CmdLineArgs $CmdLineArgs
        # START THE PROCESS
        $Process.Start() | Out-Null
        $ProcessObj.ProcessStartTime = $process.StartTime
        # READ STD OUT AND ERROR TO END ASYNC SO BUFFER DOESNT FILL AND HANG PROCESS
        $stdOut = $process.StandardOutput.ReadToEndAsync()
        $stdErr = $process.StandardError.ReadToEndAsync()
        # WAIT for the Process to Complete
        $WaitProcess = Wait-ForProcess $Process $Timeout
        if ($WaitProcess -eq 0) {
            $processObj.ProcessResult = $Process.ProcessExitCode
        }
        if ($WaitProcess -eq -1) {
            $processObj.ProcessResult = "Timeout"
        }
        ## SET THE EXIT CODE STD OUT/ERR, END TIME, DURATION
        $processObj.ProcessExitCode = $process.ExitCode
        $processObj.ProcessStdOut = $stdOut.Result
        $processObj.ProcessStdErr = $stdErr.Result
        $processObj.ProcessEndTime = $process.ExitTime
        $processObj.ProcessDuration = $processObj.ProcessEndTime - $processObj.ProcessStartTime
        ## RETURN THE PROCESS OBJECT
        $ProcessList.Add($processObj)
    }    End {
        # Return the Process List
        Return $ProcessList
    }
}

function Get-DirectoryList
{
    <#
    .SYNOPSIS
    Funtion to get a list of directory names using the Get-ChildItem command
    .DESCRIPTION
    Funtion to get a list of directory names using the Get-ChildItem command
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$Directory = $null
    )
    # Create the  Object
    $Obj = [PSCustomObject]@{        
        Directory = $Directory
        DirList = New-Object System.Collections.Generic.List[string]
    }
    # Add a trailing backslash if it is not there
    # This will handle the case of C: and default it to the root
    if ($Directory.EndsWith("\") -eq $false) {
        $Directory = "$($Directory)\"   
    }
    $Directories = Get-ChildItem -Force -Directory "$($Directory)*"
    # Add the Directories to the list
    foreach ($i in $Directories) {
        # Don't want links
        if ($i.Attributes -notmatch "ReparsePoint") {
            $Obj.DirList.Add($i.Name)
        }               
    }
    return $Obj
}

function Get-RobocopyDirectory
{
    <#
    .SYNOPSIS
    Function that utilizes Robocopy to get the size of directories in the directory that is passed to it
    .DESCRIPTION
    Function that utilizes Robocopy to get the size of directories in the directory that is passed to it
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$Directory = $null,
        [switch]$IgnoreSubDirs = $false
    )
    # Create the  Object
    $Obj = [PSCustomObject]@{        
        Directory = $Directory
        DirList = New-Object System.Collections.Generic.List[string]
        Cmd = $null
        Size = $null
        RawSize = $null
    }
    $Directory = $Directory.TrimEnd("\")
    if ($Directory.EndsWith(":") -eq $true) { $Directory = "$($Directory)\\" }
    # Setup the command
    $Cmd = "C:\Windows\System32\robocopy.exe"
    # Setup the arguments
    if ($IgnoreSubDirs -eq $false) { $CmdArgs = @("""$($Directory)""","""NULL""","/l","/e","/njh","/nfl","/xj","/r:0","/w:0","/bytes") }
    elseif ($IgnoreSubDirs -eq $true) { $CmdArgs = @("""$($Directory)""","""NULL""","/l","/njh","/nfl","/xj","/r:0","/w:0","/bytes") }
    $Obj.Cmd = Start-ProcessWaitTimeout -Computer $null -CmdLine $cmd -CmdLineArgs $CmdArgs -Timeout 180
    # Add a trailing backslash to the directory (so it matches Robocopy output)
    if ($Directory.EndsWith("\") -eq $false) { $Directory = "$($Directory)\" }
    # Loop through the StdOut
    foreach ($i in $Obj.Cmd.ProcessStdOut.Split("`n")) {
        # If it is a directory, get the name from the Robocopy output and add it to the list if it isn't there
        if ($i -match ".*\sDir\s+\d+\s+(?<Directory>.*)\s+") {
            if ($Matches.Directory -ne $Directory) {                                
                $RelativeSubDir = $Matches.Directory.Replace($Directory,"")
                $SubDir = $RelativeSubDir.SubString(0,$RelativeSubDir.IndexOf("\"))                             
                if ($Obj.DirList.Contains($SubDir) -eq $false) {                                        
                    $Obj.DirList.Add($SubDir)
                }
            }               
        }
        # Get the size and round to 2 places
        if ($i -match "Bytes\s:\s+(?<Size>\d+)\s.*") {
            $Obj.RawSize = $Matches.Size
            if ($MB -or ($Auto -and ([math]::Round(($Matches.Size / 1MB),2) -lt 1024))) {
                $Obj.Size = [math]::Round(($Matches.Size / 1MB),2).ToString("0.00").PadRight(9," ") + "MB"
            }
            elseif ($GB -or ($Auto -and ([math]::Round(($Matches.Size / 1MB),2) -ge 1024))) {
                $Obj.Size = [math]::Round(($Matches.Size / 1GB),2).ToString("0.00").PadRight(9," ") + "GB"
            }
        }
    }
    # Return the Object
    Return $Obj
}

#################################################
#
# Main
#
#################################################
# Input validation: Only one of the 3 input flags (MB, GB, Auto) can be set at a time
if (([bool]$MB + [bool]$GB + [bool]$Auto) -gt 1) {
    Write-Host "Invalid Options. -MB, -GB, and -Auto cannot be combined with each other" -ForegroundColor Red
    EXIT 2
}
elseif (([bool]$MB + [bool]$GB + [bool]$Auto) -eq 0) { $Auto = $True }

# Just for the root, use Get-ChildItem to get a list of the directories.  It is a lot faster than using Robocopy.
# Matching on IE: (C: or C:\) or IE: (\\computer\c$ or \\computer\c$\)
if ($Dir -match "[A-Z]:\\*\Z" -or $Dir -match "\A\\\\.*\\[A-Z]\$\\*\Z") {
    # Get a list of directories at the root
    $DirObj = Get-DirectoryList -Directory $Dir
} else {
    # Not the root, just size the directory (that will get a list of directories also)
    $DirObj = Get-RobocopyDirectory -Directory "$($Dir)"
}

# Get longest directory name for display purposes
$LongestDir = 0
foreach ($i IN $DirObj.DirList) { IF (("$($Dir.TrimEnd("\"))\$($i)").length -gt $LongestDir) {$LongestDir = ("$($Dir.TrimEnd("\"))\$($i)").length} }
if ($Dir.length -gt $LongestDir) {$LongestDir = $Dir.Length}
$Width = $LongestDir + 5
$Lines = "".PadRight(($Width + 14), "-")
$ToBecomeObject = New-Object System.Collections.Generic.List[object]
# Write visual header if normal mode, and csv header if CSV mode
if ((!($CSV)) -and (!($OBJECT))) {
    Write-Host $Lines
    Write-Host "  SubFolder Size(s):"
    Write-Host $Lines
}
elseif ($OBJECT) { $ToBecomeObject.Add("Directory,Size_MB,Size_GB") }
else { "Directory,Size_MB,Size_GB" }

# Size the directories
$TotalRawSize = 0
foreach ($i in $DirObj.DirList) {
    $RoboObj = Get-RobocopyDirectory -Directory "$($Dir.TrimEnd("\"))\$($i)"
    $TotalRawSize += $RoboObj.RawSize
    if ((!($CSV)) -and (!($OBJECT))) { Write-Host " $($RoboObj.Directory.PadRight($Width," ")) $($RoboObj.Size)" -ForegroundColor Cyan }
    elseif ($OBJECT) { $ToBecomeObject.Add("$($RoboObj.Directory),$([math]::Round(($RoboObj.RawSize / 1MB),2).ToString("0.00")),$([math]::Round(($RoboObj.RawSize / 1GB),2).ToString("0.00"))") }
    else { "$($RoboObj.Directory),$([math]::Round(($RoboObj.RawSize / 1MB),2).ToString("0.00")),$([math]::Round(($RoboObj.RawSize / 1GB),2).ToString("0.00"))" }
}

if ((!($CSV)) -and (!($OBJECT))) {
    Write-Host $Lines
    Write-Host "  Total Size:"
    Write-Host $Lines
}

# Get the final size of the whole $Dir
$WholeDirObj = Get-RobocopyDirectory -Directory "$($Dir)" -IgnoreSubDirs
$TotalRawSize += $WholeDirObj.RawSize

# Format TotalSize based on input switches
if ($MB -or ($Auto -and ([math]::Round(($TotalRawSize / 1MB),2) -lt 1024))) {
    $TotalSize = [math]::Round(($TotalRawSize / 1MB),2).ToString("0.00").PadRight(9," ") + "MB"
}
elseif ($GB -or ($Auto -and ([math]::Round(($TotalRawSize / 1MB),2) -ge 1024))) {
    $TotalSize = [math]::Round(($TotalRawSize / 1GB),2).ToString("0.00").PadRight(9," ") + "GB"
}

if ((!($CSV)) -and (!($OBJECT))) {
    Write-Host " $($WholeDirObj.Directory.PadRight($Width," ")) $($TotalSize)" -ForegroundColor Cyan
    Write-Host $Lines
    Write-Host ""
}
elseif ($OBJECT) {
    $ToBecomeObject.Add("$($WholeDirObj.Directory),$([math]::Round(($TotalRawSize / 1MB),2).ToString("0.00")),$([math]::Round(($TotalRawSize / 1GB),2).ToString("0.00"))") 
    $SizeObj = ConvertFrom-Csv ($ToBecomeObject)
    $SizeObj | % { $_.Size_MB = [double]$_.Size_MB }
    $SizeObj | % { $_.Size_GB = [double]$_.Size_GB }
    $SizeObj
}
else { "$($WholeDirObj.Directory),$([math]::Round(($TotalRawSize / 1MB),2).ToString("0.00")),$([math]::Round(($TotalRawSize / 1GB),2).ToString("0.00"))" }
