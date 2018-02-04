Param (
    $path,
    $files
)
if (-not $path) {$path = "$env:TEMP"}
if (-not $files) {$files = "*txt"}
Get-Item (Join-Path $path $files) | %{
    $file = $_;
    Write-Host "====================="
    Write-Host $file.Name;
    Write-Host

    $isPrivate = $null
    sls 'you are not publicly reachable' $file | select -Last 1 | %{
        Write-Host ('```')
        Write-Host ($_.Line+'```')
    }
    sls 'no public' $file | select -Last 1 | %{
        Write-Host ('```')
        Write-Host ($_.Line+'``` <-- *bad*')
    }
    $isPrivate = sls 'private ' $file | select -Last 1 | %{('```
'+$_.Line+'``` <-- *bad*')}

    $opcode1 = $null
    $opcode2 = $null
    $opcode3 = $null
    $opcode1 = sls 'subscribing to topic \\"0f01020202\\"' $file | select -Last 1
    $opcode2 = sls 'subscribing to topic \\"0f02020202\\"' $file | select -Last 1
    $opcode3 = sls 'subscribing to topic \\"0f03020202\\"' $file | select -Last 1

    $upnp = $null
    $address = $null
    $port = $null
    $delta = $null

    $upnp = sls 'message":"(.* upnp.*?)"' $file | select -last 1 | % {$_.Line}
    if (-not $upnp) {
        sls 'message":"(.* public.*?)"' $file | select -last 1 | % {$_.Matches.Groups[1].Value}
    } else {
        if (($upnp | sls 'successful').Matches.Success) {
            Write-Host ('```')
            Write-Host ($upnp+'``` <-- *not optimal*')
        } else {
            Write-Host ('```')
            Write-Host ($upnp+'``` <-- *bad*')
        }
        ($address, $port) = sls "upnp: (.*?):(.*?)`"" $file | 
            select -last 1 | %{$_.matches.Groups[1].value, $_.Matches.Groups[2].value}
        Write-Host
    }

    sls "sharddata.kfs" $file | select -last 1 | % {
        [System.Console]::WriteLine('```')
        [System.Console]::WriteLine($_.Line + '```  <-- *bad*')
    }
    sls "usedspace" $file | select -last 1 | % {
        [System.Console]::WriteLine('```')
        [System.Console]::WriteLine($_.Line + '```  <-- *bad*')
    }

    sls "System clock is not syncronized with NTP" $file | select -last 1 | % {Write-Host ('`' + $_.Line + '` <-- *bad*')}
    sls "Timeout waiting for NTP response." $file | select -last 1 | % {Write-Host ('`' + $_.Line + '` <-- *bad*')}
    
    $delta = $null
    sls "delta: (.*) ms" $file | select -last 1 | % {
        $delta = $_.matches.Groups[1].value.ToDecimal([System.Globalization.CultureInfo]::CurrentCulture);
        if ($delta -ge 500.0 -or $delta -le -500.0) {
            Write-Host ('clock delta: `' + $delta + '` <-- *bad*')
        } else {
            write-host ('clock delta: `' + $delta + '` <-- *ok*')
        }
    }

    $nodeid = $null
    $nodeid = sls 'create.*nodeid (.*?)"' $file | select -last 1 | % {$_.Matches.Groups[1].Value}

    if (-not $nodeid) {
        Write-Host "    Please, stop your node, delete the log and start node again. Wait for 10 minutes and upload again."
    } else {
        $contact = $null
        $contact = (Invoke-WebRequest ("https://api.storj.io/contacts/" + $nodeid) -UseBasicParsing).Content;
        $port = $contact | sls '"port":(\d*),' | % {$_.Matches.Groups[1].Value}
        $address = $contact | sls '"address":"(.*?)",' | % {$_.Matches.Groups[1].Value}

        $isTunneling = $false
        $isTunneling = ($address | sls "storj\.dk").Matches.Success

        Write-Host "https://api.storj.io/contacts/$nodeid"
        if ($contact) {
            Write-Host ('```') 
            Write-Host ($contact.ToString() + '```')
        }

        $address |                                % {Write-Host ('   rpcAddress : `' + $_ + '`')}
        $port |                                   % {Write-Host ('      rpcPort : `' + $_ + '`')}
        $contact | sls '"lastSeen":"(.*?)",' |    % {Write-Host ('    last seen : `' + $_.Matches.Groups[1].Value + '`')}
        $contact | sls '"responseTime":(.*?),' |  % {Write-Host ('response time : `' + $_.Matches.Groups[1].Value + '`')}
        $contact | sls '"lastTimeout":"(.*?)",' | % {Write-Host (' last timeout : `' + $_.Matches.Groups[1].Value + '`')}
        $contact | sls '"timeoutRate":(.*?),' |   % {Write-Host (' timeout rate : `' + $_.Matches.Groups[1].Value + '`')}
        $contact | sls '"reputation":(.*?),' |    % {Write-Host ('   reputation : `' + $_.Matches.Groups[1].Value + '`')}
        Write-Host 
    }

    $isPortOpen = $null
    if ($address -and $port -and -not $isTunneling) {
        $isPortOpen = try {
            Invoke-WebRequest ('http://' + $address + ':' + $port) -UseBasicParsing
        } catch [System.Net.WebException] {
            ($_ | sls "get").matches.success
        }
        if ($isPortOpen) {
            Write-Host ('`port ' + $port + ' is open on ' + $address + '`')
        } else {
            Write-Host ('`port ' + $port + ' is CLOSED on ' + $address + '` <-- *bad*')
        }
        Write-Host
    }
    sls 'publish .*timestamp":"(.*)"' $file | select -last 1 | % {
        write-host ('  last publish: `' + $_.matches.Groups[1].value + '` (' + (sls "publish" $file).Matches.Count + ')')
    }
    sls 'shard download completed.*timestamp":"(.*)"' $file | select -last 1 | % {
        $sr = (sls 'shard download completed.*size (\d*)' $file).Matches
        $counter = 0; $sr | ?{$_} | %{$counter += $_.Groups[1].Value}
        write-host ('last download: `' + $_.matches.groups[1].value + '` (' + $sr.Count + '): ' + $counter)
    } 
    sls 'mirror download completed.*timestamp":"(.*)"' $file | select -last 1 | % {
        $sr = (sls 'mirror download completed.*size (\d*)' $file).Matches
        $counter = 0; $sr | ?{$_} | %{$counter += $_.Groups[1].Value}
        write-host ('  last mirror: `' + $_.matches.groups[1].value + '` (' + $sr.Count + '): ' + $counter)
    } 
    sls 'upload.*timestamp":"(.*)"' $file | select -last 1 | % {
        $sr = (sls 'upload completed.*size (\d*)' $file).Matches
        $counter = 0; $sr | ?{$_} | %{$counter += $_.Groups[1].Value}
        write-host ('  last upload: `' + $_.matches.groups[1].value + '` (' + $sr.Count + '): ' + $counter)
    }

    Write-Host "--------------"
    if (-not $opcode1) {Write-Host '`Opcode "0f01020202" not found!`  <-- *bad*'}
    if (-not $opcode2) {Write-Host '`Opcode "0f02020202" not found!`  <-- *bad*'}
    if (-not $opcode3) {Write-Host '`Opcode "0f03020202" not found!`  <-- *bad*'}
    if (-not $opcode1 -or -not $opcode2 -or -not $opcode3) {
        Write-Host 'You should specify only that opcodes:
        "0f01020202"
        "0f02020202"
        "0f03020202"

        Please, check it in your config!'
        Write-Host
    }
    if ($delta -and ($delta -ge 500.0 -or $delta -le -500.0)) {
        Write-Host ('clock delta: `' + $delta + '` <-- *bad*')
        Write-Host "Your clock is out of sync
        https://docs.storj.io/docs/storjshare-troubleshooting-guide#section-4-synchronize-your-clock
        "
    }
    if ($isPrivate) {
        Write-Host $isPrivate
        Write-Host '        Please, check your `"rpcAddress"` option in configuration of node.'
        if ($address) {Write-Host ('        It is should be like this: `"rpcAddress": "' + $address + '",`')}
        Write-Host
    }
    if ($upnp) {
        if (($upnp | sls 'successful').Matches.Success) {
            Write-Host ('```')
            Write-Host ($upnp+'``` <-- *not optimal*')
        } else {
            Write-Host ('```')
            Write-Host ($upnp+'``` <-- *bad*')
        }
    }
    if (-not $isPortOpen -and $port -and $address -and -not $isTunneling) {
        Write-Host ('`port ' + $port + ' is CLOSED on ' + $address +'` <-- *bad*')
        Write-Host 'Please, check it:' http://www.yougetsignal.com/tools/open-ports/
        Write-Host
        Write-Host 'Please, read this manual to fix this:
        GUI:    https://docs.storj.io/docs/storj-share-gui#section-5-storj-share-troubleshooting
        daemon: https://docs.storj.io/docs/storj-share-daemon-cli#section-4-storj-share-troubleshooting
        '
    }
    if ($isTunneling) {
        Write-Host '`You are using tunneling` <-- *not optimal*'
    }
    if ($upnp -or $isTunneling) {
        Write-Host 'Please, read this manual to fix this: 
        GUI:    https://docs.storj.io/docs/storj-share-gui#section-332-advanced-configuration
        daemon: https://docs.storj.io/docs/storj-share-daemon-cli#section-3-2-port-forwarding
        '
    }
    if (Test-Path (Join-Path $env:TEMP ($file.BaseName + $file.Extension))) {
        rm -Force $file
    }
}