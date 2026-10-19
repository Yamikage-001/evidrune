param(
    [Parameter(Mandatory)][string]$MsiPath,
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [Parameter(Mandatory)][string]$SignerThumbprints,
    [string]$OutputPath='windows.json'
)
$ErrorActionPreference='Stop'
$pins=@($SignerThumbprints -split ';'|ForEach-Object {$_.Trim().ToUpperInvariant()}|Where-Object {$_})
if(!$pins.Count -or @($pins|Where-Object {$_ -notmatch '^[A-F0-9]{40}$'}).Count){throw 'Configure approved signer certificate thumbprints.'}
$file=Get-Item -LiteralPath $MsiPath
if($file.Length -lt 1 -or $file.Length -gt 104857600){throw 'Installer must be between 1 byte and 100 MiB.'}
$signature=Get-AuthenticodeSignature -LiteralPath $file.FullName
if($signature.Status -ne 'Valid' -or !$signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -notin $pins){throw 'Installer is unsigned, untrusted, or signed by an unapproved certificate.'}
$engine=New-Object -ComObject WindowsInstaller.Installer
$database=$engine.OpenDatabase($file.FullName,0)
try {
    foreach($name in @('UpgradeCode','ProductVersion')){
        $view=$database.OpenView("SELECT Value FROM Property WHERE Property = '$name'")
        try{
            $view.Execute()|Out-Null;$record=$view.Fetch()
            if(!$record){throw 'MSI product identity is missing.'}
            $value=$record.StringData(1)
            if($name -eq 'UpgradeCode' -and $value -ne '{C1D6E1BD-13F8-4B7A-B6C6-A7226AE96C71}'){throw 'MSI belongs to another product.'}
            if($name -eq 'ProductVersion' -and [version]$value -ne [version]$Version){throw 'Release tag and MSI version do not match.'}
        } finally {$view.Close()|Out-Null;[Runtime.InteropServices.Marshal]::FinalReleaseComObject($view)|Out-Null}
    }
} finally {[Runtime.InteropServices.Marshal]::FinalReleaseComObject($database)|Out-Null;[Runtime.InteropServices.Marshal]::FinalReleaseComObject($engine)|Out-Null}
$json=@{schemaVersion=1;version=$Version;size=$file.Length;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash;signed=$true}|ConvertTo-Json
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath),$json,[Text.UTF8Encoding]::new($false))
Write-Output ('Verified signed Windows OTA manifest: '+$OutputPath)
