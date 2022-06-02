# Linphone Call Block

**Linphone Call Block** is a PowerShell script designed to block unwanted calls on Linphone App (Windows).   

## Disclaimer

This script cannot intercept calls, meaning that you will likely hear the bell ring before the call is automatically blocked.  

## Features

### Address Blacklist
- Anyone included in this list will be blocked. 
- The blacklist takes priority over everything else. 
- This list is represented as variable `$blacklist`.

### Address Whitelist
- Anyone included in this list will not be blocked. 
- This list is represented as variable `$whitelist`.  

### Contact-based Whitelist
- Anyone who is in your Linphone contact list (address book) will not be blocked. 

### Unknown Caller Allow/Block
- By default, **Linphone Call Block** will block unknown callers. 
- Variable `$block_unknown_caller`, which is either `$true` or `$false`, lets you decide whether to block calls from unknown adresses or not.  

## How it works

### Read Console Window Output

When you execute the Linphone binary with `--verbose` option through Command Prompt or PowerShell, you will be able to see what is going on behind the Linphone app. This stream of outputs normally cannot be piped, but there is a workaround for that. Here is a part of the script that makes the workaround possible:  

```PowerShell
$binary_path = 'C:\Program Files\Linphone\bin\linphone.exe'

$linphone_app = Start-Job -ScriptBlock {
    param($binary)
    powershell.exe -Command "& '$binary' --verbose" *>&1
} -ArgumentList $binary_path

While ($true) {
    $linphone_stream = $linphone_app | Receive-Job
    EvaluateStream($linphone_stream)
    Start-Sleep -Milliseconds 500
}
```
This way, you will be able to "pipe" the console window output.  
However, there is a limitation; since the above reads lines off from the console window, any output longer than the console window width will have a line break.  

You can evaluate and extract meaningful parts from the output stream using regular expressions like the following:  

```PowerShell
Switch -Regex ($s|Out-String) {
    $regex_A {Function_A($matches)}
    $regex_B {Function_B($matches)}
    $regex_C {Function_C($matches)}
}
```
`$matches` is an automatic variable. Read [this](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions) for details.

## Limitations and Possible Improvements  

Currently, **Linphone Call Block** uses [Linphone Command Line](https://wiki.linphone.org/xwiki/wiki/public/view/Linphone/URI%20Handlers%20%28Desktop%20only%29/) to deny calls. Although this method is most straightforward, it takes significant time (>1sec). 

| Considered Method |  Positive Side  | Negative Side |
|:-----------------------------:|:---------:|:--------------:|
| Linphone CLI `bye` | Straightforward | Slow |
| Mute system sound | Quick | Affects sounds that are already playing |
| Pause Process | Quick | Need admin privillege & cannot interact with Linphone while paused |
| Automatically click "End Call" Button | Not tested | Not tested |

The best method would be Linphone app itself having a call block feature.  

## Note

<img src="./assets/Execution policy.PNG" width="1100" alt="Execution Policy Change"/>  
If you happen to encounter the above message, please restart the script.  
