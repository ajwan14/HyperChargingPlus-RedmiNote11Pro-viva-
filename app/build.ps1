# Build script for HyperChargeService companion app
param(
    [string]$AndroidJar = "C:\Users\kurnw\AppData\Local\Android\Sdk\platforms\android-35\android.jar",
    [string]$BuildTools = "C:\Users\kurnw\AppData\Local\Android\Sdk\build-tools\36.0.0"
)

$ErrorActionPreference = "Stop"
$appDir = $PSScriptRoot
$aapt2 = "$BuildTools\aapt2.exe"
$d8 = "$BuildTools\d8.bat"
$zipalign = "$BuildTools\zipalign.exe"
$apksigner = "$BuildTools\apksigner.bat"

Write-Host "Compiling HyperChargeService.apk..." -ForegroundColor Cyan

# Prepare directories
$buildDir = "$appDir\build"
$genDir = "$buildDir\gen"
$binDir = "$buildDir\bin"
$dexDir = "$buildDir\dex"
New-Item -ItemType Directory -Path $genDir, $binDir, $dexDir -Force | Out-Null

# 1. Compile resources
& $aapt2 compile --dir "$appDir\res" -o "$buildDir\compiled_res.zip"

# 2. Link resources
& $aapt2 link -I $AndroidJar "$buildDir\compiled_res.zip" --manifest "$appDir\AndroidManifest.xml" --java $genDir -o "$buildDir\base.apk"

# 3. Compile Java sources
$srcFiles = @(Get-ChildItem -Path "$appDir\src" -Filter "*.java" -Recurse | Select-Object -ExpandProperty FullName)
$genFiles = @(Get-ChildItem -Path $genDir -Filter "*.java" -Recurse | Select-Object -ExpandProperty FullName)
& javac --release 17 -cp "$AndroidJar;$genDir" -d $binDir ($srcFiles + $genFiles)

# 4. Convert classes to DEX
$classFiles = @(Get-ChildItem -Path $binDir -Filter "*.class" -Recurse | Select-Object -ExpandProperty FullName)
& cmd.exe /c "$d8 --min-api 29 --output `"$dexDir`"" $classFiles

# 5. Insert classes.dex into base.apk
python -c "
import zipfile
with zipfile.ZipFile('$($buildDir.Replace('\','/'))/base.apk', 'a', compression=zipfile.ZIP_DEFLATED) as z:
    z.write('$($dexDir.Replace('\','/'))/classes.dex', 'classes.dex')
"

# 6. Zipalign
$alignedApk = "$buildDir\HyperChargeService_aligned.apk"
& $zipalign -p -f 4 "$buildDir\base.apk" $alignedApk

# 7. Keystore & Sign
$keystore = "$appDir\release.keystore"
if (-not (Test-Path $keystore)) {
    & keytool -genkeypair -v -keystore $keystore -alias hypercharge -keyalg RSA -keysize 2048 -validity 10000 -storepass hypercharge -keypass hypercharge -dname "CN=HyperCharge, OU=Dev, O=Razal, L=Jakarta, ST=ID, C=ID"
}
$signedApk = "$appDir\HyperChargeService.apk"
& cmd.exe /c "$apksigner sign --min-sdk-version 24 --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --ks `"$keystore`" --ks-pass pass:hypercharge --out `"$signedApk`" `"$alignedApk`""

# Copy to Magisk module destination
$moduleDest = "$appDir\..\system\app\HyperChargingService\HyperChargeService.apk"
Copy-Item $signedApk $moduleDest -Force

Write-Host "Build complete: $moduleDest" -ForegroundColor Green
