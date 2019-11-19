function global:pcli-run($cmd) {
    $global:PCLI.StandardInput.WriteLine($cmd)

    # pcli Readline always output prompt '>' (ASCII 62)
    $s = $global:PCLI.StandardOutput.Read()
    if ($s -ne 62) {
        Write-Output "pcli.exe error!"
        return
    }

    while ($true) {
        $line = $global:PCLI.StandardOutput.ReadLine()
        if ($line -match "^Error Code: (-?\d+)$") {
            $ec = $Matches[1]
            if ($ec -ne 0) {
                Write-Output $line
            }
            return
        } else {
            Write-Output $line
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
                $cmd = Read-Host -Prompt "[$Env:PCLI_PR]$Env:PCLI_PP"
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
            $Env:PCLI_PR = $args[0]
            pcli-run "Set -vPCLI_PR `"$Env:PCLI_PR`""
        }

        "cd" {
            $p = [IO.Path]::Combine($Env:PCLI_PP, $args[0])
            $p = [IO.Path]::GetFullPath($p)
            $r = [IO.Path]::GetPathRoot($p)
            $Env:PCLI_PP = $p.Substring($r.Length - 1).Replace('\', '/')
            pcli-run "Set -vPCLI_PP `"$Env:PCLI_PP`""
        }

        "pwd" {
            pcli-run "Echo [`${PCLI_PR}]`${PCLI_PP}"
        }

        Default {
            # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators
            pcli-run ((,$cmd + $args) -join " ")
        }
    }
}

pcli init
