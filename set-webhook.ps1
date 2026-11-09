# Запусти на своём компьютере. Эта команда заменяет старый webhook бота.
$site = (Read-Host 'Адрес тестового сайта на Vercel, например https://pear-test.vercel.app').Trim().TrimEnd('/')
$uri = $null
if (-not [Uri]::TryCreate($site, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.AbsolutePath -ne '/' -or $uri.Query -or $uri.Fragment) {
    Write-Host 'Нужен HTTPS-адрес сайта без пути и параметров.'; exit 1
}
Write-Host 'ВНИМАНИЕ: webhook этого бота будет заменён. Для проверки используй отдельного тестового бота.'
if ((Read-Host 'Продолжить? Введи YES') -cne 'YES') { Write-Host 'Отменено.'; exit 0 }
$secureToken = Read-Host 'Токен бота из BotFather' -AsSecureString
$secureSecret = Read-Host 'TELEGRAM_WEBHOOK_SECRET из настроек Vercel' -AsSecureString
$token = (New-Object System.Net.NetworkCredential('', $secureToken)).Password
$secret = (New-Object System.Net.NetworkCredential('', $secureSecret)).Password
if (-not $token -or -not $secret) { Write-Host 'Токен или секрет не указан.'; exit 1 }
$body = @{url="$site/api/pear-bot"; secret_token=$secret; allowed_updates=@('message','callback_query')} | ConvertTo-Json -Compress
try {
    $result = Invoke-RestMethod -Method Post -Uri ('https://api.telegram.org/bot' + $token + '/setWebhook') -ContentType 'application/json' -Body $body -ErrorAction Stop
    if ($result.ok) { Write-Host 'Webhook установлен. Открой тестового бота и отправь /start.' }
    else { Write-Host 'Telegram не подтвердил установку webhook. Проверь токен и адрес.'; exit 1 }
} catch { Write-Host 'Не удалось установить webhook. Проверь токен, секрет и адрес сайта.'; exit 1 }
finally { $token = $null; $secret = $null; $body = $null }
