$keytoolPath = "C:\Program Files\Java\jdk-17\bin\keytool.exe"
$keystorePath = "$env:USERPROFILE\.android\debug.keystore"

Write-Host "Extracting SHA256 fingerprint from debug keystore..." -ForegroundColor Cyan
Write-Host ""

& $keytoolPath -list -v -keystore $keystorePath -alias androiddebugkey -storepass android -keypass android | Select-String -Pattern "SHA256"

Write-Host ""
Write-Host "Copy the SHA256 value above and add it to your Firebase project:" -ForegroundColor Green
Write-Host "Firebase Console -> Project Settings -> Your apps -> SHA certificate fingerprints" -ForegroundColor Yellow
