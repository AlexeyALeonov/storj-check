# storj-check
Checking Powershell scripts for Storjshare

### For GUI logs
After checking log at TEMP folder it's remove the checked log

#### *checklog.ps1* usage:
`checklog.ps1` [`-Path <path_to_logs>`][`-Files <filename or mask>`]

If no Path specifiyed this is would be a current folder.
Files is `*.txt` by default

### For daemon logs
After checking log at TEMP folder it's remove the checked log

#### *checklog-daemon.ps1* usage:
`checklog-daemon.ps1` [`-Path <path_to_logs>`][`-Files <filename or mask>`]

If no Path specifiyed this is would be a current folder
Files is `*.txt` by default
