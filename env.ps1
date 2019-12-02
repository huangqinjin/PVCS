function global:pcli-run($cmd) {
    $global:PCLI.StandardInput.WriteLine($cmd)

    $buf = [Char[]]::new(4096)
    $output = ""
    while ($true) {
        $count = $global:PCLI.StandardOutput.Read($buf, 0, $buf.Length)
        if ($count -eq 0) {
            continue
        }
        $output += [String]::new($buf, 0, $count)
        $lines = $output -split [Environment]::NewLine
        $output = $lines[-1]
        $action = 0  # 0: continue; 1: return;
        if ($output -match "^Error Code: (-?\d+)>$") {
            $global:LastExitCode = $Matches[1]
            $action = 1
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

            Default {}
        }
    }
}

function global:pcli {
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_assignment_operators#assigning-multiple-variables
    $cmd, $args = $args
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_arrays#the-array-sub-expression-operator
    $args = @($args)   # make sure args is array

    switch ($cmd) {
        "" {
            if (!$global:PCLI) {
                pcli init
            }

            while ($global:PCLI) {
                $cmd = Read-Host -Prompt $(pcli pwd)
                $args = -split $cmd
                switch ($args[0]) {
                    "" { continue }
                    "break" { return }
                    Default {
                        # @args: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting
                        pcli @args
                    }
                }
            }
        }

        "init" {
            pcli exit

            # https://stackoverflow.com/questions/8925323/redirection-of-standard-and-error-output-appending-to-the-same-log-file
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = if ($args[0]) { "python" } else { "pcli.exe" }
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
                    Write-Output "pcli.exe error!"
                    return
                }
                $global:PCLI = $p
                pcli use "$Env:PCLI_PR"
                pcli cd "$Env:PCLI_PP"
            } else {
                Write-Output "Start $($pinfo.FileName) fail!"
            }
        }

        "exit" {
            if ($global:PCLI) {
                $global:PCLI.StandardInput.WriteLine("exit")
                $global:PCLI.WaitForExit()
                $global:PCLI = $null
            }
        }

        "login" {
            $u = if ($args[0]) { $args[0] } else { Read-Host -Prompt "Username" }           
            # https://stackoverflow.com/questions/28352141/convert-a-secure-string-to-plain-text
            $p = Read-Host -AsSecureString -Prompt "Password"
            $c = (New-Object PSCredential $u, $p).GetNetworkCredential()
            pcli-run "Set -vPCLI_ID $($c.UserName):$($c.Password)"
        }

        "use" {
            pcli-run "Set -vPCLI_PR `"$($args[0])`""
        }

        "cd" {
            $p = [IO.Path]::Combine("/", $(pcli-run "Echo `${PCLI_PP}"), $args[0])
            $p = [IO.Path]::GetFullPath($p)
            $r = [IO.Path]::GetPathRoot($p)
            $p = $p.Substring($r.Length - 1).Replace('\', '/')
            pcli-run "Set -vPCLI_PP `"$p`""
        }

        "pwd" {
            pcli-run "Echo [`${PCLI_PR}]`${PCLI_PP}"
        }

        Default {
            if ($cmd[0] -eq '!') {
                $cmd = $cmd.Substring(1)
                & $cmd $args
            } elseif ($cmd -match "\.(exe|bat)$") {
                & $cmd $args
            } elseif ($cmd -in "cmd","git") {
                & $cmd $args
            } else {
                # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators
                pcli-run ((,$cmd + $args) -join " ")
            } 
        }
    }
}

pcli init
