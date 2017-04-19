﻿Param (
    $path,
    $files
)
if (-not $path) {$path = "."}
if (-not $files) {$files = "*.log.txt"}
get-item (Join-Path $path $files) | %{
    $file = $_;
    $nodeid = $null
    $port = $null
    $address = $null
    Write-Host "====================="
    Write-Host $file.Name;
    Write-Host 
    sls 'you are not publicly reachable, trying traversal strategies' $file | select -Last 1 | %{Write-Warning ('`'+$_.Line+'`')}
    $upnp = sls 'message":"(.* upnp.*?)"' $file | select -last 1 | % {$_.Matches.Groups[1].Value}
    if (-not $upnp) {
        sls 'message":"(.* public.*?)"' $file | select -last 1 | % {Write-Host $_.Matches.Groups[1].Value}
    } else {
        Write-Warning ('`'+$upnp+'` - *bad*')
        ($address, $port) = sls "upnp: (.*):(.*)" $file | 
            select -last 1 | %{$_.matches.Groups[1].value, $_.Matches.Groups[2].value}
        Write-Host 'Enable UPnP in your router or configure port forwarding.
    - Enable NAT/UPnP in your router settings or disable the NAT firewall of your PC (if you have such firewall)
    - Configure port forwarding (best option), you can watch this tutorial where all previous steps are explained: 
        https://www.youtube.com/watch?v=PjbXpdsMIW4
    Or you can read docs.storj.io/docs/storjshare-troubleshooting-guide in the "port forwarding" section.'
    }
    sls "kfs" $file | select -last 1 | % {Write-Error $_.Line}
    sls "usedspace" $file | select -last 1 | % {Write-Error $_.Line}
    sls "System clock is not syncronized with NTP" $file | select -last 1 | % {Write-Error $_.Line}
    sls "delta: (.*) ms" $file | select -last 1 | % {
        $delta = $_.matches.Groups[1].value.ToDecimal([System.Globalization.CultureInfo]::CurrentCulture);
        if ($delta -ge 500.0 -or $delta -le -500.0) {
            Write-Warning ('clock delta: `' + $delta + '`')
            Write-Host "Your clock is out of sync
            Synchronize your clock
            http://www.pool.ntp.org/en go here find ntp server closest to you physically and also ping it, 
            then download this software http://www.timesynctool.com and use ntp server that you found out in previous step"
        } else {
            write-host clock delta: '`'$delta'` - *ok*'
        }
    }
    $nodeid = sls 'create.*nodeid (.*?)"' $file | select -last 1 | % {$_.Matches.Groups[1].Value}
    if (-not $nodeid) {
        Write-Warning "Please, stop your node, delete the log and start node again. Wait for 10 minutes and upload again."
    } else {
        $contact = (Invoke-WebRequest "https://api.storj.io/contacts/$nodeid").Content;
        ($lastseen, $port, $address) = $contact | sls '"lastseen":"(.*?)","port":(\d*),"address":"(.*?)",' | % {($_.Matches.Groups[1].Value, $_.Matches.Groups[2].Value, $_.Matches.Groups[3].Value)}
        $responsetime = $contact | sls '"responsetime":(.*?),' | % {$_.Matches.Groups[1].Value}
        Write-Host nodeid: '`'$nodeid'`'
        Write-Host "https://api.storj.io/contacts/$nodeid"
        Write-Host '```'$contact'```'
        Write-Host last seen: '`'$lastseen'`'
        Write-Host response time: '`'$responsetime'`'
        Write-Host address: '`'$address'`', port: '`'$port'`'
    }
    if ($address -and $port) {
        Write-Host http://www.yougetsignal.com/tools/open-ports/
        $check = try {
            Invoke-WebRequest ('http://' + $address + ':' + $port)
        } catch [System.Net.WebException] {
            ($_ | sls "get").matches.success
        }
        if ($check) {Write-Host '`'port $port is open on $address'`'} else {Write-Error ('`port' + $port + 'is CLOSED on' + $address +'`')}
    }
    sls 'publish .*timestamp":"(.*)"' $file | select -last 1 | % {write-host "last publish:", $_.matches.Groups[1].value}
    sls 'offer .*timestamp":"(.*)"' $file | select -last 1 | % {write-host "last offer:", $_.matches.Groups[1].value}
    sls 'consign.*timestamp":"(.*)"' $file | select -last 1 | % {write-host "last consign:", $_.matches.Groups[1].value}
    Write-Host "--------------"
    Write-Host 
}