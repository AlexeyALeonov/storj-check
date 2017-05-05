Param (
    $path,
    $files
)
if (-not $path) {$path = "."}
if (-not $files) {$files = "*txt"}
Get-Item (Join-Path $path $files) | %{
    $file = $_;
    Write-Host "====================="
    Write-Host $file.Name;

    sls 'you are not publicly reachable' $file | select -Last 1 | %{Write-Host ('```'+$_.Line+'```')}
    sls 'no public' $file | select -Last 1 | %{Write-Host ('```'+$_.Line+'``` <-- *bad*')}
    sls 'private ' $file | select -Last 1 | %{Write-Host ('```'+$_.Line+'``` <-- *bad*')}

    $upnp = $null
    $address = $null
    $port = $null
    $delta = $null

    $upnp = sls '] (.* upnp.*)' $file | select -last 1 | % {$_.Matches.Groups[1].Value}
    if (-not $upnp) {
        sls '] (.* public.*)' $file | select -last 1 | % {$_.Matches.Groups[1].Value}
    } else {
        if (($upnp | sls 'successful').Matches.Success) {
            Write-Host ('`'+$upnp+'` <-- *not optimal*')
        } else {
            Write-Host ('`'+$upnp+'` <-- *bad*')
        }
        ($address, $port) = sls "upnp: (.*):(.*)" $file | 
            select -last 1 | %{$_.matches.Groups[1].value, $_.Matches.Groups[2].value}
    }

    sls "sharddata.kfs" $file | select -last 1 | % {Write-Host ('```' + $_.Line + '```  <-- *bad*')}
    sls "usedspace" $file | select -last 1 | % {Write-Host ('```' + $_.Line + '```  <-- *bad*')}

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
        Write-Host 
    }

    $nodeid = $null
    $nodeid = sls 'created .* nodeid (.*)' $file | select -last 1 | %{$_.Matches.Groups[1].Value}

    if (-not $nodeid) {
        Write-Host "    Please, stop your node, delete the log and start node again. Wait for 10 minutes and upload again."
    } else {
        $contact = $null
        $contact = (Invoke-WebRequest ("https://api.storj.io/contacts/" + $nodeid) -UseBasicParsing).Content;
        $port = $contact | sls '"port":(\d*),' | % {$_.Matches.Groups[1].Value}
        $address = $contact | sls '"address":"(.*?)",' | % {$_.Matches.Groups[1].Value}

        $isTunneling = $null
        $isTunneling = ($address | sls "storj\.dk").Matches.Success

        if ($contact) {
            Write-Host "https://api.storj.io/contacts/$nodeid"
            Write-Host ('```' + $contact.ToString() + '```')
            Write-Host 
        }

        $address |                                % {Write-Host ('   rpcAddress : `' + $_ + '`')}
        $port |                                   % {Write-Host ('      rpcPort : `' + $_ + '`')}
        $contact | sls '"lastSeen":"(.*?)",' |    % {Write-Host ('    last seen : `' + $_.Matches.Groups[1].Value + '`')}
        $contact | sls '"responseTime":(.*?),' |  % {Write-Host ('response time : `' + $_.Matches.Groups[1].Value + '`')}
        $contact | sls '"lastTimeout":"(.*?)",' | % {Write-Host (' last timeout : `' + $_.Matches.Groups[1].Value + '`')}
        $contact | sls '"timeoutRate":(.*?),' |   % {Write-Host (' timeout rate : `' + $_.Matches.Groups[1].Value + '`')}
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
    sls "\[(.*)\].* publish" $file | select -last 1 | % {
        write-host ('  last publish: `' + $_.matches.Groups[1].value + '` (' + (sls "publish" $file).Matches.Count + ')')
    }
    sls "\[(.*)\].* offer" $file | select -last 1 | % {
        write-host ('    last offer: `' + $_.matches.Groups[1].value + '` (' + (sls "offer" $file).Matches.Count + ')')
    }
    sls "\[(.*)\].* consign" $file | select -last 1 | % {
        write-host ('last consigned: `' + $_.matches.Groups[1].value + '` (' + (sls "consign" $file).Matches.Count + ')')
    }
    sls '\[(.*)\].* download' $file | select -last 1 | % {
        write-host (' last download: `' + $_.matches.groups[1].value + '` (' + (sls 'download' $_.Path).Matches.Count + ')')
    }; 
    sls '\[(.*)\].* upload' $file | select -last 1 | % {
        write-host ('   last upload: `' + $_.matches.groups[1].value + '` (' + (sls 'upload' $_.Path).Matches.Count + ')')
    }

    Write-Host "--------------"
    if ($delta -and ($delta -ge 500.0 -or $delta -le -500.0)) {
        Write-Host ('clock delta: `' + $delta + '` <-- *bad*')
        Write-Host "        Your clock is out of sync
        Synchronize your clock
        http://www.pool.ntp.org/en go here find ntp server closest to you physically and also ping it, 
        then download this software http://www.timesynctool.com and use ntp server that you found out in previous step
        "
    }
    if ($upnp) {
        if (($upnp | sls 'successful').Matches.Success) {
            Write-Host ('`'+$upnp+'` <-- *not optimal*')
        } else {
            Write-Host ('`'+$upnp+'` <-- *bad*')
        }
    }
    if (-not $isPortOpen -and $port -and $address -and -not $isTunneling) {
        Write-Host ('`port ' + $port + ' is CLOSED on ' + $address +'` <-- *bad*')
        Write-Host 'Please, check it:' http://www.yougetsignal.com/tools/open-ports/
        Write-Host
    }
    if ($isTunneling) {
        Write-Host '`You are using tunneling` <-- *not optimal*'
    }
    if (-not $isPortOpen -and $port -and $address -or $upnp -or $isTunneling) {
        Write-Host '        Enable UPnP in your router or configure port forwarding.
        - Enable NAT/UPnP in your router settings or disable the NAT firewall of your PC (if you have such firewall)
        - Configure port forwarding (best option), you can watch this tutorial where all previous steps are explained: 
        https://www.youtube.com/watch?v=PjbXpdsMIW4
        Or you can read docs.storj.io/docs/storjshare-troubleshooting-guide in the "port forwarding" section.
        '
    }
    if (Test-Path (Join-Path $env:TEMP ($file.BaseName + $file.Extension))) {
        rm -Force $file
    }
}