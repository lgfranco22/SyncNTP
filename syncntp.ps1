param(
    [Parameter(Position = 0)]
    [string]$PrimaryServer = "200.160.7.197",

    [Parameter(Position = 1)]
    [string]$FallbackServer = "a.st1.ntp.br"
)

$ErrorActionPreference = "Stop"

$script:EventSource = "SyncNTP"
$script:EventLogName = "Application"


# ============================================================
# REGISTRO DE EVENTOS
# ============================================================

function Write-SyncEvent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [System.Diagnostics.EventLogEntryType]$EntryType,

        [Parameter(Mandatory = $true)]
        [int]$EventId
    )

    # A fonte pode precisar de alguns segundos para ser registrada.
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        try {
            if (-not [System.Diagnostics.EventLog]::SourceExists(
                $script:EventSource
            )) {
                [System.Diagnostics.EventLog]::CreateEventSource(
                    $script:EventSource,
                    $script:EventLogName
                )

                Start-Sleep -Seconds 2
            }

            [System.Diagnostics.EventLog]::WriteEntry(
                $script:EventSource,
                $Message,
                $EntryType,
                $EventId
            )

            return $true
        }
        catch {
            if ($attempt -lt 6) {
                Start-Sleep -Seconds 1
            }
        }
    }

    return $false
}


# ============================================================
# MESSAGEBOX DE ERRO
# ============================================================

function Show-SyncError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    try {
        $process = [System.Diagnostics.Process]::GetCurrentProcess()

        # Nao tentar abrir uma interface em sessoes nao interativas,
        # como tarefas executadas na sessao 0.
        if (
            [System.Environment]::UserInteractive -and
            $process.SessionId -ne 0
        ) {
            Add-Type -AssemblyName System.Windows.Forms

            [void][System.Windows.Forms.MessageBox]::Show(
                $Message,
                "Sincronizador NTP",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
    catch {
        # A notificacao visual nunca deve interromper o registro
        # do erro nem a finalizacao do programa.
    }
}


# ============================================================
# CONSULTA SNTP
# ============================================================

function Get-NtpServerTime {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server
    )

    $udp = $null

    try {
        # Resolver o servidor para um endereco IPv4.
        $addresses = [System.Net.Dns]::GetHostAddresses($Server)
        $serverIp = $null

        foreach ($address in $addresses) {
            if (
                $address.AddressFamily -eq
                [System.Net.Sockets.AddressFamily]::InterNetwork
            ) {
                $serverIp = $address
                break
            }
        }

        if ($null -eq $serverIp) {
            throw "Nenhum endereco IPv4 encontrado para $Server."
        }

        $udp = New-Object System.Net.Sockets.UdpClient
        $udp.Client.ReceiveTimeout = 5000
        $udp.Connect($serverIp, 123)

        # Pacote NTP de 48 bytes: versao 3, modo cliente.
        $request = New-Object byte[] 48
        $request[0] = 0x1B

        [void]$udp.Send($request, $request.Length)

        $endpoint = New-Object System.Net.IPEndPoint(
            [System.Net.IPAddress]::Any,
            0
        )

        $response = $udp.Receive([ref]$endpoint)

        if ($response.Length -lt 48) {
            throw "Resposta NTP incompleta."
        }

        # Validar os campos principais da resposta.
        $leap = ($response[0] -shr 6) -band 3
        $version = ($response[0] -shr 3) -band 7
        $mode = $response[0] -band 7
        $stratum = [int]$response[1]

        if ($mode -ne 4) {
            throw "A resposta recebida nao esta no modo servidor NTP."
        }

        if ($version -lt 3 -or $version -gt 4) {
            throw "Versao NTP de resposta invalida: $version."
        }

        if ($leap -eq 3) {
            throw "O servidor informou que nao esta sincronizado."
        }

        if ($stratum -lt 1 -or $stratum -gt 15) {
            throw "O servidor retornou um estrato invalido: $stratum."
        }

        # Timestamp de transmissao do servidor: bytes 40 a 47.
        [byte[]]$secondsBytes = $response[40..43]
        [byte[]]$fractionBytes = $response[44..47]

        # Converter big-endian para a ordem esperada pelo Windows.
        if ([BitConverter]::IsLittleEndian) {
            [Array]::Reverse($secondsBytes)
            [Array]::Reverse($fractionBytes)
        }

        [uint32]$seconds = [BitConverter]::ToUInt32(
            $secondsBytes,
            0
        )

        [uint32]$fraction = [BitConverter]::ToUInt32(
            $fractionBytes,
            0
        )

        # Epoch NTP explicitamente em UTC.
        $epoch = [DateTime]::SpecifyKind(
            [DateTime]::ParseExact(
                "1900-01-01 00:00:00",
                "yyyy-MM-dd HH:mm:ss",
                [Globalization.CultureInfo]::InvariantCulture
            ),
            [DateTimeKind]::Utc
        )

        $fractionSeconds = [double]$fraction / 4294967296.0

        $utcTime = $epoch.AddSeconds(
            [double]$seconds + $fractionSeconds
        )

        return [PSCustomObject]@{
            UtcTime      = $utcTime
            Stratum      = $stratum
            Version      = $version
            ServerIP     = $serverIp.ToString()
        }
    }
    finally {
        if ($null -ne $udp) {
            $udp.Close()
        }
    }
}


# ============================================================
# AJUSTE DO RELOGIO DO WINDOWS
# ============================================================

$PInvokeCode = @'
using System;
using System.Runtime.InteropServices;

public class Win32TimeSyncNtp {
    [StructLayout(LayoutKind.Sequential)]
    public struct SYSTEMTIME {
        public ushort wYear;
        public ushort wMonth;
        public ushort wDayOfWeek;
        public ushort wDay;
        public ushort wHour;
        public ushort wMinute;
        public ushort wSecond;
        public ushort wMilliseconds;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetSystemTime(ref SYSTEMTIME lpSystemTime);
}
'@


# ============================================================
# EXECUCAO PRINCIPAL
# ============================================================

try {
    if ([string]::IsNullOrWhiteSpace($PrimaryServer)) {
        throw "O servidor NTP principal nao foi informado."
    }

    if ([string]::IsNullOrWhiteSpace($FallbackServer)) {
        throw "O servidor NTP de fallback nao foi informado."
    }

    $PrimaryServer = $PrimaryServer.Trim()
    $FallbackServer = $FallbackServer.Trim()

    # Evitar consultar duas vezes o mesmo servidor.
    $servers = @()

    foreach ($candidate in @($PrimaryServer, $FallbackServer)) {
        if (
            -not [string]::IsNullOrWhiteSpace($candidate) -and
            $servers -notcontains $candidate
        ) {
            $servers += $candidate
        }
    }

    $ntpResult = $null
    $selectedServer = $null
    $attemptErrors = @()

    # Tentar primeiro o servidor principal e depois o fallback.
    foreach ($server in $servers) {
        try {
            $ntpResult = Get-NtpServerTime -Server $server
            $selectedServer = $server
            break
        }
        catch {
            $attemptErrors += (
                "{0}: {1}" -f $server, $_.Exception.Message
            )
        }
    }

    if ($null -eq $ntpResult) {
        throw (
            "Nenhum servidor NTP forneceu um horario valido." +
            "`r`n" +
            ($attemptErrors -join "`r`n")
        )
    }

    # Criar a API Win32 apenas quando houver uma resposta valida.
    if (-not ("Win32TimeSyncNtp" -as [type])) {
        Add-Type -TypeDefinition $PInvokeCode
    }

    $utcTime = $ntpResult.UtcTime

    $systemTime = New-Object Win32TimeSyncNtp+SYSTEMTIME
    $systemTime.wYear = $utcTime.Year
    $systemTime.wMonth = $utcTime.Month
    $systemTime.wDay = $utcTime.Day
    $systemTime.wDayOfWeek = [int]$utcTime.DayOfWeek
    $systemTime.wHour = $utcTime.Hour
    $systemTime.wMinute = $utcTime.Minute
    $systemTime.wSecond = $utcTime.Second
    $systemTime.wMilliseconds = $utcTime.Millisecond

    $success = [Win32TimeSyncNtp]::SetSystemTime(
        [ref]$systemTime
    )

    if (-not $success) {
        $errorCode = (
            [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        )

        throw "SetSystemTime falhou. Codigo Win32: $errorCode."
    }

    # Preparar os dados para o evento.
    $culture = [Globalization.CultureInfo]::InvariantCulture

    $utcText = $utcTime.ToString(
        "yyyy-MM-dd HH:mm:ss.fff",
        $culture
    )

    $localText = $utcTime.ToLocalTime().ToString(
        "yyyy-MM-dd HH:mm:ss.fff",
        $culture
    )

    $eventMessage = (
        "NTP synchronization successful. " +
        "Primary=$PrimaryServer; " +
        "SelectedServer=$selectedServer; " +
        "ServerIP=$($ntpResult.ServerIP); " +
        "Stratum=$($ntpResult.Stratum); " +
        "Version=$($ntpResult.Version); " +
        "UTC=$utcText; Local=$localText."
    )

    # Se o principal falhou, registrar essa informacao no evento
    # de sucesso, pois o fallback concluiu a sincronizacao.
    if ($attemptErrors.Count -gt 0) {
        $eventMessage += (
            " Earlier attempt failed: " +
            ($attemptErrors -join " | ")
        )
    }

    $logged = Write-SyncEvent `
        -Message $eventMessage `
        -EntryType Information `
        -EventId 1000

    if (-not $logged) {
        $logError = (
            "The clock was adjusted successfully, but the " +
            "Information event could not be written to the " +
            "Application log. Run the task with sufficient privileges."
        )

        [void](Write-SyncEvent `
            -Message $logError `
            -EntryType Error `
            -EventId 2001)

        Show-SyncError -Message $logError
    }
}
catch {
    $errorMessage = $_.Exception.Message

    $eventMessage = (
        "NTP synchronization failed. " + $errorMessage
    )

    $logged = Write-SyncEvent `
        -Message $eventMessage `
        -EntryType Error `
        -EventId 2000

    if (-not $logged) {
        $errorMessage += (
            "`r`n`r`nThe error could not be written to " +
            "the Windows Application event log."
        )
    }

    Show-SyncError -Message $errorMessage
}