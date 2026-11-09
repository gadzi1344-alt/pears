# Запусти локально на своем компьютере. Никому не отправляй результат.
function New-PearSecret {
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}
Write-Host 'Сохрани эти значения в надёжном месте и добавь в Vercel. Не отправляй их в чат.'
Write-Host ('PEAR_CODE_SECRET=' + (New-PearSecret))
Write-Host ('TELEGRAM_WEBHOOK_SECRET=' + (New-PearSecret))
Write-Host 'PEAR_CODE_SECRET нельзя терять или менять после регистрации пользователей.'
