﻿Param (
    $path,
    $files
)
if (-not $path) {$path = "."}
if (-not $files) {$files = "*.txt"}
get-item (Join-Path $path $files) | %{
    $file = $_;
    $nodeid = $null
    $port = $null
    $address = $null
    Write-Host "====================="
    Write-Host $file.Name;
    Write-Host 
    sls 'you are not publicly reachable' $file | select -Last 1 | %{Write-Host ('```'+$_.Line+'```')}
    sls 'no public' $file | select -Last 1 | %{Write-Host ('```'+$_.Line+'``` <-- *bad*')}

    $upnp = ''
    $upnp = sls 'message":"(.* upnp.*?)"' $file | select -last 1 | % {$_.Matches.Groups[1].Value}
    if (-not $upnp) {
        sls 'message":"(.* public.*?)"' $file | select -last 1 | % {Write-Host $_.Matches.Groups[1].Value}
    } else {
        if (($upnp | sls 'successful').Matches.Success) {
            Write-Host ('`'+$upnp+'` <-- *not optimal*')
        } else {
            Write-Host ('`'+$upnp+'` <-- *bad*')
        }
        ($address, $port) = sls "upnp: (.*):(.*)" $file | 
            select -last 1 | %{$_.matches.Groups[1].value, $_.Matches.Groups[2].value}
    }

    sls "kfs" $file | select -last 1 | % {Write-Host $_.Line}
    sls "usedspace" $file | select -last 1 | % {Write-Host $_.Line}
    sls "System clock is not syncronized with NTP" $file | select -last 1 | % {Write-Host '`'$_.Line'` <-- *bad*'}
    sls "Timeout waiting for NTP response." $file | select -last 1 | % {Write-Host '`'$_.Line'` <-- *bad*'}
    sls "delta: (.*) ms" $file | select -last 1 | % {
        $delta = ''
        $delta = $_.matches.Groups[1].value.ToDecimal([System.Globalization.CultureInfo]::CurrentCulture);
        if ($delta -ge 500.0 -or $delta -le -500.0) {
            Write-Host ('clock delta: `' + $delta + '` <-- *bad*')
        } else {
            write-host clock delta: '`'$delta'` <-- *ok*'
        }
    }

    $nodeid = ''
    $nodeid = sls 'create.*nodeid (.*?)"' $file | select -last 1 | % {$_.Matches.Groups[1].Value}

    if (-not $nodeid) {
        Write-Host "Please, stop your node, delete the log and start node again. Wait for 10 minutes and upload again."
    } else {
        $contact = (Invoke-WebRequest ("https://api.storj.io/contacts/" + $nodeid)).Content;
        $port = $contact | sls '"port":(\d*),' | % {$_.Matches.Groups[1].Value}
        $address = $contact | sls '"address":"(.*?)",' | % {$_.Matches.Groups[1].Value}

        Write-Host "https://api.storj.io/contacts/$nodeid"
        Write-Host '```'$contact'```'

        $contact | sls '"lastSeen":"(.*?)",' | % {Write-Host last seen: '`'$_.Matches.Groups[1].Value'`'}
        $contact | sls '"responseTime":(.*?),' | % {Write-Host response time: '`'$_.Matches.Groups[1].Value'`'}
        $contact | sls '"lastTimeout":"(.*?)",' | % {Write-Host last timeout: '`'$_.Matches.Groups[1].Value'`'}
        $contact | sls '"timeoutRate":(.*?),' | % {Write-Host timeout rate: '`'$_.Matches.Groups[1].Value'`'}
        #Write-Host address: '`'$address'`', port: '`'$port'`'
    }

    Write-Host
    $checkPort = ''
    if ($address -and $port) {
        Write-Host http://www.yougetsignal.com/tools/open-ports/
        $checkPort = try {
            Invoke-WebRequest ('http://' + $address + ':' + $port)
        } catch [System.Net.WebException] {
            ($_ | sls "get").matches.success
        }
        if ($checkPort) {
            Write-Host '`'port $port is open on $address'`'
        } else {
            Write-Host '`'port $port is CLOSED on $address'` <-- *bad*'
        }
    }
    Write-Host
    sls 'publish .*timestamp":"(.*)"' $file | select -last 1 | % {write-host "last publish:", $_.matches.Groups[1].value}
    sls 'offer .*timestamp":"(.*)"' $file | select -last 1 | % {write-host "last offer:", $_.matches.Groups[1].value}
    sls 'consign.*timestamp":"(.*)"' $file | select -last 1 | % {write-host "last consign:", $_.matches.Groups[1].value}

    Write-Host "--------------"
    if ($delta -ge 500.0 -or $delta -le -500.0) {
        Write-Host ('clock delta: `' + $delta + '` <-- *bad*')
        Write-Host "
        _Your clock is out of sync
        Synchronize your clock
        http://www.pool.ntp.org/en go here find ntp server closest to you physically and also ping it, 
        then download this software http://www.timesynctool.com and use ntp server that you found out in previous step_
        "
        Write-Host
    }
    if ($upnp) {
        if (($upnp | sls 'successful').Matches.Success) {
            Write-Host ('`'+$upnp+'` <-- *not optimal*')
        } else {
            Write-Host ('`'+$upnp+'` <-- *bad*')
        }
    }
    if (-not $checkPort) {
        Write-Host ('`port ' + $port + ' is CLOSED on ' + $address +'` <-- *bad*')
    }
    if (-not $checkPort -or $upnp) {
        Write-Host '
        _Enable UPnP in your router or configure port forwarding.
        - Enable NAT/UPnP in your router settings or disable the NAT firewall of your PC (if you have such firewall)
        - Configure port forwarding (best option), you can watch this tutorial where all previous steps are explained: 
        https://www.youtube.com/watch?v=PjbXpdsMIW4
        Or you can read docs.storj.io/docs/storjshare-troubleshooting-guide in the "port forwarding" section._
        '
    }
    Write-Host
    if (Test-Path (Join-Path $env:TEMP ($file.BaseName + $file.Extension))) {
        rm -Force $file
    }
}