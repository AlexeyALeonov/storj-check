# storj-check
Checking Powershell scripts for Storjshare

### For GUI logs
Be careful After checking log at the TEMP folder it's will remove it!

#### *checklog.ps1* usage:
`checklog.ps1` \[`-Path <path_to_logs>`\]\[`-Files <filename or mask>`\]

If no Path specified this would be a current folder.
Files is `*.txt` by default

### For daemon logs
After checking log at the TEMP folder it's will remove it!

#### *checklog-daemon.ps1* usage:
`checklog-daemon.ps1` \[`-Path <path_to_logs>`\]\[`-Files <filename or mask>`\]

If no Path specified this would be a current folder.
Files is `*.txt` by default
