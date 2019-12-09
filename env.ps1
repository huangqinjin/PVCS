function global:pcli-run($cmd) {
    $global:PCLI.StandardInput.WriteLine($cmd)

    $buf = [Char[]]::new(4096)
    $output = ''
    while ($true) {
        $count = $global:PCLI.StandardOutput.Read($buf, 0, $buf.Length)
        if ($count -eq 0) {
            continue
        }
        $output += [String]::new($buf, 0, $count)
        $lines = $output -split [Environment]::NewLine
        $output = $lines[-1]
        $action = 0  # 0: continue; 1: return; 2: prompt
        if ($output -match '^Error Code: (-?\d+)>$') {
            $global:LastExitCode = $Matches[1]
            $action = 1
        } elseif ($output.EndsWith(' (y/n) ')) {
            $action = 2
        }

        if ($lines.Length -gt 1) {
            Write-Output $lines[0..($lines.Length - 2)]
        }

        switch ($action) {
            1 {
                if ($global:LastExitCode -ne 0) {
                    Write-Output "Error Code: $global:LastExitCode"
                }
                return 
            }
            
            2 {
                $cmd = Read-Host -Prompt $output
                $global:PCLI.StandardInput.WriteLine($cmd)
                $output = ''
            }

            Default {}
        }
    }
}

function global:pcli {
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_assignment_operators#assigning-multiple-variables
    $cmd, $args = $args
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_arrays#the-array-sub-expression-operator
    # https://stackoverflow.com/questions/711991/flatten-array-in-powershell
    $args = @($args | % { $_ })   # flatten args

    switch ($cmd) {
        '' {
            if (!$global:PCLI) {
                pcli init
            }

            while ($global:PCLI) {
                $cmd = Read-Host -Prompt $(pcli pwd)
                $args = -split $cmd
                switch ($args[0]) {
                    '' { continue }
                    'break' { return }
                    'return' { return }
                    Default {
                        # @args: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting
                        pcli @args
                    }
                }
            }
        }

        'break' {}
        'return' {}
        'continue' {}

        'init' {
            pcli exit

            # https://stackoverflow.com/questions/8925323/redirection-of-standard-and-error-output-appending-to-the-same-log-file
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = if ($args[0]) { 'python' } else { 'pcli.exe' }
            $pinfo.RedirectStandardInput = $true
            $pinfo.RedirectStandardOutput = $true
            $pinfo.RedirectStandardError = $false
            $pinfo.UseShellExecute = $false
            $pinfo.Arguments = if ($args[0]) { "`"$PSScriptRoot/run.py`"" } else { "Run -ns -s`"$PSScriptRoot/run.pcli`"" }
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo = $pinfo
            
            if ($p.Start()) {
                # pcli Readline always output prompt '>' (ASCII 62)
                $s = $p.StandardOutput.Read()
                if ($s -ne 62) {
                    Write-Output 'pcli.exe error!'
                    return
                }
                $global:PCLI = $p
                pcli use "$Env:PCLI_PR"
                pcli cd "$Env:PCLI_PP"
            } else {
                Write-Output "Start $($pinfo.FileName) fail!"
            }
        }

        'exit' {
            if ($global:PCLI) {
                $global:PCLI.StandardInput.WriteLine('Exit')
                $global:PCLI.WaitForExit()
                $global:PCLI = $null
            }
        }

        'login' {
            $u = if ($args[0]) { $args[0] } else { Read-Host -Prompt Username }
            # https://stackoverflow.com/questions/28352141/convert-a-secure-string-to-plain-text
            $p = Read-Host -AsSecureString -Prompt Password
            $c = (New-Object PSCredential $u, $p).GetNetworkCredential()
            pcli-run "Set -vPCLI_ID $($c.UserName):$($c.Password)"
        }

        'use' {
            pcli-run "Set -vPCLI_PR `"$($args[0])`""
        }

        'cd' {
            $p = [IO.Path]::Combine('/', $(pcli-run 'Echo ${PCLI_PP}'), $args[0])
            $p = [IO.Path]::GetFullPath($p)
            $r = [IO.Path]::GetPathRoot($p)
            $p = $p.Substring($r.Length - 1).Replace('\', '/')
            pcli-run "Set -vPCLI_PP `"$p`""
        }

        'pwd' {
            pcli-run 'Echo [${PCLI_PR}]${PCLI_PP}'
        }

        'ls' {
            pcli-run ((,'List' + $args + '*') -join ' ')
        }

        'put' {
            $cmd = 'Put', '-bp"${PCLI_PP}"', '-z', '-ym', '-k', '-o'
            $msgfile = $null
            $msg = $null
            $loc = $null
            for ($i = 0; $i -lt $args.Length; ++$i) {
                if ($args[$i][0] -ne '-') {
                    continue
                } elseif ($args[$i].StartsWith('-a')) {
                    $loc = $args[$i].Substring(2)
                } elseif ($args[$i].StartsWith('-m')) {
                    $msg = $args[$i].Substring(2)
                } elseif ($args[$i] -in '-y','-n') {
                    $cmd = ,$args[$i] + $cmd
                } else {
                    $cmd += $args[$i]
                }
                $args[$i] = ''
            }

            if (!$loc) {
                $loc = $PWD
            }

            if (!$msg) {
                $msgfile = New-TemporaryFile
                # Start-Process -FilePath $msgfile -Verb Edit -Wait
                $editors = Get-Command -Name notepad.exe,vim -CommandType Application -TotalCount 1 -ErrorAction Ignore
                Start-Process -FilePath $editors[0] -ArgumentList $msgfile -Wait -NoNewWindow
                $msg = Get-Content -Path $msgfile -Raw
                if ($msg -and $msg.Trim()) {
                    $msg = "@$msgfile"
                } else {
                    $msg = ''
                }
            }

            $cmd += "-a`"$loc`""
            $cmd += "-m`"$msg`""

            pcli-run (($cmd + $args) -join ' ')

            if ($msgfile) {
                Remove-Item -Path $msgfile
            }
        }

        Default {
            if ($cmd[0] -eq '!') {
                $cmd = $cmd.Substring(1)
                & $cmd $args
            } elseif ($cmd -match '\.(ps1|bat)$') {
                & $cmd $args
            } elseif ($cmd -match '\.(exe)$') {
                Start-Process -FilePath $cmd -ArgumentList $args -Wait -NoNewWindow
            } elseif ($cmd -in 'cmd','git') {
                & $cmd $args
            } else {
                # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators
                pcli-run ((,$cmd + $args) -join ' ')
            } 
        }
    }
}

pcli init $args
