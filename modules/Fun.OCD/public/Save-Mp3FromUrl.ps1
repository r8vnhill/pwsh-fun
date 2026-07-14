<#
.SYNOPSIS
Downloads a video or audio URL and saves its audio track as an MP3 file using `yt-dlp`.

.DESCRIPTION
`Save-Mp3FromUrl` wraps `yt-dlp` to grab the audio track of one or more URLs (YouTube,
SoundCloud, and anything else `yt-dlp` supports) and save it as an MP3 file. It's a thin
wrapper around:

    yt-dlp.exe -t mp3 -o "<OutputPath>\%(title)s.%(ext)s" <Url>

.PARAMETER Url
One or more URLs to download. Accepts pipeline input.

.PARAMETER OutputPath
Directory where the resulting MP3 files are saved. Defaults to the current directory.
Must already exist.

.PARAMETER YtDlpArguments
Extra arguments passed through to `yt-dlp` as-is (e.g. `-4`, `--cookies-from-browser`, ...).

.EXAMPLE
Save-Mp3FromUrl -Url 'https://youtu.be/dQw4w9WgXcQ'

Downloads the video and saves its audio track as an MP3 in the current directory.

.EXAMPLE
'https://youtu.be/dQw4w9WgXcQ', 'https://youtu.be/oHg5SJYRHA0' | Save-Mp3FromUrl -OutputPath 'D:\Music'

Downloads both URLs and saves the resulting MP3 files under `D:\Music`.

.NOTES
Requires `yt-dlp` to be available on the system PATH.
#>
function Save-Mp3FromUrl {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param (
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('Link', 'Uri')]
        [string[]] $Url,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $OutputPath = (Get-Location).Path,

        [Parameter()]
        [string[]] $YtDlpArguments = @()
    )

    begin {
        if (-not (Get-Command -Name 'yt-dlp.exe' -ErrorAction SilentlyContinue) -and
            -not (Get-Command -Name 'yt-dlp' -ErrorAction SilentlyContinue)) {
            throw "yt-dlp was not found in PATH. Install it from https://github.com/yt-dlp/yt-dlp before using Save-Mp3FromUrl."
        }

        if (-not (Test-Path -LiteralPath $OutputPath)) {
            throw "Output path '$OutputPath' does not exist."
        }
    }

    process {
        foreach ($link in $Url) {
            if ($PSCmdlet.ShouldProcess($link, 'Download audio as MP3 with yt-dlp')) {
                $outputTemplate = Join-Path -Path $OutputPath -ChildPath '%(title)s.%(ext)s'
                $arguments = @('-t', 'mp3', '-o', $outputTemplate) + $YtDlpArguments + @($link)

                Write-Verbose "Invoking: yt-dlp.exe $($arguments -join ' ')"
                & yt-dlp.exe @arguments

                if ($LASTEXITCODE -ne 0) {
                    Write-Error "yt-dlp failed for '$link' with exit code $LASTEXITCODE."
                }
            }
        }
    }
}
