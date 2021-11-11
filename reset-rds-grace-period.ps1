<#
    .SYNOPSIS
        Resets RDS grace period on the RDS host.

    .DESCRIPTION
        This script is intended to be used to reset Terminal Server (RDS) grace licensing period to default value.

    .PARAMETER Force
        Disable interactive action. false is the default.

    .PARAMETER RestartTS
        Restart Terminal Service after resetting grace period. false is the default.

    .INPUTS
        None. You cannot pipe objects to reset-rds-grace-period.ps1.

    .OUTPUTS
        None. reset-rds-grace-period.ps1 does not generate any meaningful output.

    .EXAMPLE
        PS> .\reset-rds-grace-period.ps1

    .EXAMPLE
        PS> .\reset-rds-grace-period.ps1 -Force

    .EXAMPLE
        PS> .\reset-rds-grace-period.ps1 -RestartTS

    .EXAMPLE
        PS> .\reset-rds-grace-period.ps1 -Force -RestartTS

    .LINK
        https://github.com/atollholding/reset-rds-grace-period

    .NOTES
        Important:  Please test reset-rds-grace-period.ps1 in test environment before executing on any production server.
                    Please be careful while changing settings at the Windows registry!
                    Please create a full backup of the registry or affected keys beforehand.
                    Authors is not responsible for any misuse/damage caused by using it.

        You will have to restart following services for the reset to come into effect:
            Remote Desktop Services
            Remote Desktop Configuration Properties (optional)
        As soon as these services are restarted all the active sessions will be disconnected (Not logged off). Wait for a minute and reconnect again.
#>

[CmdletBinding()]
Param(
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $false,
        ValueFromPipelineByPropertyName = $false)]
    [Switch]
    $Force = $false,
    [Switch]
    $RestartTS = $false
)

# Was this script launched by local administrator?
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Only local administrator can launch this script.
if (!($isAdmin)) {
    throw [System.UnauthorizedAccessException]::new("Please launch this script as an Administrator.")
}

# Retreive and show days left to the end of grace period.
$GracePeriod = (Invoke-CimMethod -InputObject (Get-CimInstance -Namespace root/CIMV2/TerminalServices -ClassName Win32_TerminalServiceSetting) -MethodName GetGracePeriodDays).DaysLeft
Write-Host -ForegroundColor Green 'Terminal Server (RDS) grace period days remaining are': $GracePeriod

# If there was no Force argument passed to script, ask the user to confirm grace period reset. Not to reset by default.
if (!$Force) {
    # RestartTS parameter disclaimer.
    if ($RestartTS) {
        Write-Host -ForegroundColor Yellow $("*" * 80)
        Write-Host -ForegroundColor Yellow "You are set parameter to restart Terminal Service."
        Write-Host -ForegroundColor Yellow "As soon as these service are restarted all the active sessions will be"
        Write-Host -ForegroundColor Yellow "disconnected (not logged off). Wait for a short time and reconnect again."
        Write-Host -ForegroundColor Yellow $("*" * 80)
    }

    Write-Host -ForegroundColor Cyan "Do you want to reset Terminal Server (RDS) Grace period to default 120 days? (y/N) " -NoNewline
    $UserChoice = Read-Host
}

# Check user choice.
if (($UserChoice -and $UserChoice.ToLower() -eq "y") -or $Force) {
    # Create .NET class with required function.
    $definition = @"
using System;
using System.Runtime.InteropServices;
namespace Win32Api
{
	public class NtDll
	{
		[DllImport("ntdll.dll", EntryPoint="RtlAdjustPrivilege")]
		public static extern int RtlAdjustPrivilege(ulong Privilege, bool Enable, bool CurrentThread, ref bool Enabled);
	}
}
"@ 

    # Adds a Microsoft .NET class to a PowerShell session.
    Add-Type -TypeDefinition $definition -PassThru | Out-Null

    $Enabled = $false

    # Enable SeTakeOwnershipPrivilege (index 9)
    # https://www.pinvoke.net/default.aspx/ntdll/RtlAdjustPrivilege.html
    [Win32Api.NtDll]::RtlAdjustPrivilege(9, $true, $false, [ref]$Enabled) | Out-Null

    # Rights attributes.
    # $Administrators = [System.Security.Principal.NTAccount]"Administrators"
    $Administrators = [System.Security.Principal.SecurityIdentifier]"S-1-5-32-544"
    #$Administrators = [System.Security.Principal.WellKnownSidType]::AccountAdministratorSid
    $RegRights = [System.Security.AccessControl.RegistryRights]::FullControl
    $AccessControlType = [System.Security.AccessControl.AccessControlType]::Allow

    ## Take ownership on the key
    $RegKey = "SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod"
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($RegKey, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::takeownership)
    $acl = $key.GetAccessControl()
    $acl.SetOwner($Administrators)
    $key.SetAccessControl($acl)

    ## Assign 'Full Controll' permissions to Administrators group on the key.
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule ($Administrators, $RegRights, $AccessControlType)
    $acl.SetAccessRule($rule)
    $key.SetAccessControl($acl)

    ## Delete the key which resets the Grace Period counter to 120 Days.
    Write-Host -ForegroundColor Green 'Resetting grace period. Please Wait....'
    Remove-Item "HKLM:\$RegKey"

    if ($RestartTS) {
        Write-Host -ForegroundColor Green "Restarting Terminal Service..."
        Restart-Service TermService -Force
    }

    # Display remaining grace period again as final status.
    # Display Windows Terminal Server Grace Period Balloon.
    tlsbln.exe
    $GracePeriodPost = (Invoke-CimMethod -InputObject (Get-CimInstance -Namespace root/CIMV2/TerminalServices -ClassName Win32_TerminalServiceSetting) -MethodName GetGracePeriodDays).DaysLeft
    Write-Host -ForegroundColor Green 'Terminal Server (RDS) grace period days remaining are': $GracePeriodPost
}
else {
    Write-Host -ForegroundColor Yellow "You choose not to reset grace period of Terminal Server (RDS)."
}
