# Reset Terminal Server (RDS) grace period to default value

There are conditions when Terminal Server (Remote Desktop Session Host) required for testing purposes in development environments allowing more than 2 concurrent Remote Desktop Sessions on it. Default grace licensing period is 120 days. And in most cases it's fine. But once grace period expires, the server does not allow even a single Remote Desktop session and all that is possible in this case is logon to the Console of machine using physical or virtual console or IP KVM, or try to get in using `mstsc /admin` or `mstsc /console`, then remove the role completely and restart the terminal server and it starts accepting default two RDP sessions.

We sometimes find ourselves in situation when server is nearing to the end of grace period and we don’t have a TS Licensing server in place and we need the default grace period to be reset/extended to next 120 days for testing purposes.

***Note: You will have to restart following services for the reset to come into effect:***

- Remote Desktop Configuration Properties
- Remote Desktop Services

As soon as these services are restarted all the active sessions will be disconnected (**not logged off**). Wait for a short time and reconnect again.

## How to use

- Interactive reset. Remaining grace period value will be displayed before reset confirmation.

```powershell
.\clean-rds-grace-period.ps1
```

- Reset grace period forcefully w/o confirmation.

```powershell
.\clean-rds-grace-period.ps1 -Force
```

## Credits

Based on work of [Prakash82x](https://github.com/Prakash82x/PowerShell/blob/master/TerminalService/Reset-TSGracePeriod.ps1)
