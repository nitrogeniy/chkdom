param(
	[Parameter(Mandatory = $false)]
	[System.String]$mail = ""
)
$linux = $($($Env:HOME).Substring(0,1)) -eq "/" ? 1 : 0
$user = Get-Content .\smtpuser -Raw
$pass = Get-Content .\smtpkey -Raw
$smt = $linux ? "./linux/smtp" : ".\smtp.exe"
$smtp = "$smt --server smtp.mail.ru --port 465 --user `"$user`" --password `"$pass`" --fromfiled `"it daemon`" --to $user --tofield `"it dep`" --subject `"Отчёт: проверка доменов`""
$doms = Import-Csv -Delimiter ',' -path .\domains.csv
$res = @()
$dlist = @()
$istime2pay = 0
#$cred = New-Object System.Management.Automation.PSCredential($user, $pass)
$res += "`nРезультат проверки доменов`n"
function sendmail ($text) {
	#4 some weird reasons can't use 2 params (subj+body); bad delim/param def?
	if ($mail) {Invoke-Expression "$smtp --body `"$text`""}
}
ForEach ($dom in $doms) {
	#Write-Output "d: $($dom.dom) d: $($dom.date)"
	#get whois info
	if ($linux) {
		$c = $(whois $dom.dom | grep -i -E 'paid-till|Registry Expiry Date')
	} else {
		$c = $(wsl /bin/bash -c "whois $($dom.dom) | grep -i -E 'paid-till|Registry Expiry Date'")
	}
	#get paid-till
	$c1 = $c -replace '(?msi).*(paid-till|Registry Expiry Date):\s*(\S+).*', '$2'
	$c = $c.Trim()
	$c1 = $c1.Trim()
	Write-Output "d: $($dom.dom)`t$c"
	if ($c.length -eq $c1.length) {
		$res += "data not found for domain $($dom.dom) ($($dom.date))"
		continue
	}
	#compare dates
	$diff = $((Get-Date $c1) - (Get-Date))
	if ($diff.Days -le 30) {
		$istime2pay += 1
		#add to due list
		$dlist += "$($dom.dom) ($($dom.date))"
	}
}
#istime2pay
if ($istime2pay -gt 0) {
	$res += "В ожидании оплаты: $($dlist.length)"
	$res += $dlist -join ", "
}
if ($res.length -gt 1) {
	#there is smth 2 say
	Write-Output $res
	$s = $res -join "`n"
	sendmail($s)
}
