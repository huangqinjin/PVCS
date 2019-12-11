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

function global:pcli-git-ensure-inside-work-tree {
    # https://stackoverflow.com/questions/2180270/check-if-current-directory-is-a-git-repository
    if (!$(git rev-parse --is-inside-work-tree 2>$null)) {
        Write-Host 'not a git repository'
        exit
    }
}

function global:pcli-git-ensure-work-tree-root {
    pcli-git-ensure-inside-work-tree
    # https://stackoverflow.com/questions/957928/is-there-a-way-to-get-the-git-root-directory-in-one-command
    $root = Resolve-Path $(git rev-parse --show-toplevel)
    if ($root.Path -ne $PWD.Path) {
        Write-Host 'pwd not work tree root'
        exit
    }
}

function global:pcli-git-ensure-work-tree-clean {
    pcli-git-ensure-inside-work-tree
    # https://unix.stackexchange.com/questions/155046/determine-if-git-working-directory-is-clean-from-a-script
    if (git status --untracked-files=no --porcelain) {
        Write-Host 'working directory not clean'
        exit
    }
}

function global:pcli-git-ensure-master-branch-clean {
    pcli-git-ensure-work-tree-clean
    # https://stackoverflow.com/questions/6245570/how-to-get-the-current-branch-name-in-git
    if ($(git branch --show-current) -ne 'master') {
        Write-Host 'current branch not master'
        exit
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
            if ('-g' -in $args) {
                pcli-git-ensure-inside-work-tree

                $pr = git config --get pcli.pr
                if (!$pr) {
                    Write-Host "git config pcli.pr <project_database>"
                    exit
                }

                $pp = git config --local --get pcli.pp
                if (!$pp) {
                    Write-Host "git config pcli.pp <project_path>"
                    exit
                }

                $id = git config --get pcli.id

            } else {
                $pr = $Env:PCLI_PR
                $pp = $Env:PCLI_PP
                $id = $Env:PCLI_ID
            }

            pcli exit

            # https://stackoverflow.com/questions/8925323/redirection-of-standard-and-error-output-appending-to-the-same-log-file
            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = if ('-d' -in $args) { 'python' } else { 'pcli.exe' }
            $pinfo.RedirectStandardInput = $true
            $pinfo.RedirectStandardOutput = $true
            $pinfo.RedirectStandardError = $false
            $pinfo.UseShellExecute = $false
            $pinfo.Arguments = if ('-d' -in $args) { "`"$PSScriptRoot/run.py`"" } else { "Run -ns -s`"$PSScriptRoot/run.pcli`"" }
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
                pcli use $pr
                pcli cd $pp
                pcli-run "Set -vPCLI_ID `"$id`""
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

        'get' {
            $cmd = 'Get', '-bp"${PCLI_PP}"', '-z', '-w', '-o'
            $loc = $null
            for ($i = 0; $i -lt $args.Length; ++$i) {
                if ($args[$i][0] -ne '-') {
                    continue
                } elseif ($args[$i].StartsWith('-a')) {
                    $loc = $args[$i].Substring(2)
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

            $cmd += "-a`"$loc`""

            pcli-run (($cmd + $args) -join ' ')
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

        'addfiles' {
            $cmd = 'AddFiles', '-t"Archive"', '-z', '-c'
            $msgfile = $null
            $msg = $null
            $loc = $null
            for ($i = 0; $i -lt $args.Length; ++$i) {
                if ($args[$i][0] -ne '-') {
                    continue
                } elseif ($args[$i].StartsWith('-pw')) {
                    $loc = $args[$i].Substring(3)
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

            for ($i = 0; $i -lt $args.Length; ++$i) {
                if ($args[$i]) {
                    # https://github.com/PowerShell/PowerShell/issues/10278
                    # Note that .NET does not have the knowledge of PowerShell $PWD.
                    # The working directory of pcli.exe is where initialization runs,
                    # which may differ from $PWD. So convert file paths to absolute first.
                    $args[$i] = [IO.Path]::Combine($loc, $args[$i])
                    $d = [IO.Path]::GetDirectoryName($args[$i])
                    # Only filename supports globbing
                    $f = [IO.Path]::GetFileName($args[$i])
                    $d = [IO.Path]::GetFullPath($d)
                    $args[$i] = [IO.Path]::Combine($d, $f)
                    $args[$i] = '"' + $args[$i] +'"'
                }
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

            $cmd += "-pw`"$loc`""
            $cmd += "-m`"$msg`""

            pcli-run (($cmd + $args) -join ' ')

            if ($msgfile) {
                Remove-Item -Path $msgfile
            }
        }

        "push" {
            pcli-git-ensure-master-branch-clean

            if ($files = git diff --diff-filter=M --name-only """$($args[0])""..." 2>$null) {
                pcli put -l $files
            }

            # if ($files = git diff --diff-filter=A --name-only """$($args[0])""..." 2>$null) {
            #     pcli addfiles -l -ph $files
            # }

            # if ($files = git diff --diff-filter=D --name-only """$($args[0])""..." 2>$null) {
            #     pcli-run "Delete $files"
            # }
        }

        "pull" {
            pcli-git-ensure-work-tree-root
            pcli-git-ensure-master-branch-clean

            $oldfiles = @()     # files changed in master since base
            $newfiles = @()     # files changed in branch since base
            foreach ($f in $args) {
                if ($files = git diff --name-only """$f""..." 2>$null) {
                    $oldfiles += $files
                }
                if ($files = git diff --name-only "...""$f""" 2>$null) {
                    $newfiles += $files
                } elseif ($LastExitCode) {
                    # if $f is not a valid ref, treat it as a normal file
                    $newfiles += $f
                }
            }

            $oldfiles = $oldfiles | Sort-Object -Unique
            $newfiles = $newfiles | Sort-Object -Unique

            # set difference, such that we do not check out same files again
            $files = Compare-Object -ReferenceObject @($newfiles) -DifferenceObject @($oldfiles) |
                     Where-Object -Property SideIndicator -EQ -Value '<=' |
                     Select-Object -ExpandProperty InputObject

            if ($files) {
                $time = Get-Date -Format "yyyy.MM.dd HH:mm:ss"
                # -y: Yes to 'A writable "*" exists, check out anyway? (y/n)'
                # -l: lock files for update. If one file has already checked out, the second checkout
                # will fail so that it won't overwrite the file which may be already modified locally.
                # Normally it won't happen, since we performed the set difference.
                pcli get -y -l -nb -nm $files
                git add $files
                git commit -am"[partial] $time"
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
