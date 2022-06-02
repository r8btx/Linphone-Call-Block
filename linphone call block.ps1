# List format: @('sip:example1@sip.linphone.org','sip:example2@sip.linphone.org','sip:example3@sip.linphone.org')
$whitelist  =  @()
$blacklist  =  @()
$binary_path = 'C:\Program Files\Linphone\bin\linphone.exe'

$block_unknown_caller = $true


Function Timestamp($str) {Write-Output('['+(Get-Date -f "yyyy/MM/dd hh:mm:ss.fff tt")+'] '+$str)}

Timestamp('Linphone Call Block started.')

$linphone_stream = $null
$regex_call_received = 'New incoming call from \[(?<from>sip:.+@.+)\]'
#'Ringing\s{0,2}(.+\s{0,2}){0,2}From: .*<(?<from>sip:\w+@sip\.linphone\.org).*>'
$regex_call_end = '\[.+\]\[Info\]Core:linphone: StreamsGroup::finish\(\) called\.'
$regex_call_magicsearch_friends = '\[Magic Search\] Found (?<num>\d+) results in (?<friends>friends)'
$regex_call_magicsearch_calllogs = '\[Magic Search\] Found (?<num>\d+) results in (?<calllogs>call logs)'
$regex_call_magicsearch_chatrooms = '\[Magic Search\] Found (?<num>\d+) results in (?<chatrooms>chat rooms)'


$global:check_call = $regex_call_received
$global:calling = $false
$global:caller = ''
$global:filtered = $false
$global:checked_friends = $false
$global:checked_calllogs = $false
$global:checked_chatrooms = $false
$global:call_magicsearch_complete = $false;
$global:call_magicsearch_friends = 0  # Check contacts
$global:call_magicsearch_calllogs = 0  # Check previous call records
$global:call_magicsearch_chatrooms = 0  # Check previous chat records


$global:linphone_app = $null
Function Start-Linphone() {
    Get-Job |Stop-Job
    Get-Job |Remove-Job
    $global:linphone_app = Start-Job -ScriptBlock {
        param($binary)
        powershell.exe -Command "& '$binary' --verbose" *>&1
    } -ArgumentList $binary_path
}

Function Watch-LinphoneStatus() {
    $null = Get-Process -Name linphone -EA 0
    If (!$?) {
        Timestamp('***** Linphone app stopped *****')
        Get-Job |Stop-Job
        Get-Job |Remove-Job
        Timestamp('Linphone Call Block ended.')
        Pause
        Exit
    }
}

Function app_call_block() {
    Start-Job -ScriptBlock {
        param($binary, $caller)
        $arg = $caller + '?method=bye'
        & "$binary" $arg
    } -ArgumentList ($binary_path, $caller) |Receive-Job -Wait -AutoRemoveJob
}

Function app_magicsearch($s) {
    Switch -Regex ($s) {
        $regex_call_magicsearch_friends {$global:call_magicsearch_friends=[Int]($matches['num']);$global:checked_friends=$true}
        $regex_call_magicsearch_calllogs {$global:call_magicsearch_calllogs=[Int]($matches['num']);$global:checked_calllogs=$true}
        $regex_call_magicsearch_chatrooms {$global:call_magicsearch_chatrooms=[Int]($matches['num']);$global:checked_chatrooms=$true}
    }
    If ($checked_friends -and $checked_calllogs -and $checked_chatrooms) {
        $global:call_magicsearch_complete = $true
        Timestamp("History: (Call logs: "+$call_magicsearch_calllogs+") (Chat rooms: "+$call_magicsearch_chatrooms+')')
    } Else {
        $global:call_magicsearch_complete = $false
    }
}

Function app_call_filter($c) {
    If ($c -in $blacklist) {
        Timestamp('The call is from a blacklisted caller.')
        app_call_block
    } ElseIf ($c -in $whitelist) {
        Timestamp('The call is from a whitelisted caller.')
    } ElseIf ($call_magicsearch_friends -gt 0) {
        Timestamp('The call is from your contacts.')
    } Else {
        Timestamp('The call is from an unknown caller.')
        If ($block_unknown_caller) {app_call_block}
    }
    $global:filtered = $true
}

Function app_call($m) {
    If ($calling) {
        $global:check_call = $regex_call_received
        $global:calling = $false
        $global:caller = ''
        $global:filtered = $false
        $global:checked_friends = $false
        $global:checked_calllogs = $false
        $global:checked_chatrooms = $false
        $global:call_magicsearch_complete = $false
        Timestamp('Call ended.')
    } else {
        $global:calling = $true
        $global:caller = $m['from']
        $global:check_call = $regex_call_end
        Timestamp('Call received from <'+$caller+'>')
    }
}

Function EvaluateStream($s) {
    If ($s.length -eq 0) {return}
    Switch -Regex ($s|Out-String) {
        $check_call {app_call($matches)}
    }
    If ($calling) {
        If ($call_magicsearch_complete) {
            If (!$filtered) {app_call_filter($caller)}
        } Else {app_magicsearch($s)}
    }
}



# If the process is already running, close
Try{(Get-Process -Name linphone -EA 0).Kill()} Catch {}

# Start Linphone App
Start-Linphone



Timestamp('Waiting for Linphone app...')
While (!(Get-Process -Name linphone -EA 0)) {
    Start-Sleep -Seconds 5
}
Timestamp('Linphone app started.')
Try {
    While ($true) {
        $linphone_stream = $linphone_app | Receive-Job
        EvaluateStream($linphone_stream)
        If (!$calling -or $filtered) {
            Start-Sleep -Milliseconds 500
            Watch-LinphoneStatus
        }
    }
} Catch {
    Timestamp('Linphone Call Block finished.')
}
Get-Job |Stop-Job
Get-Job |Remove-Job
pause