# [PVCS Version Manager PCLI](http://help.serena.com/doc_center/doc_center.html#othpvm) - Project Command Line Interface


## Rules for specifying entity paths

| Entity | Filesystem |
|:-------|:-----------|
| project database | UNC path |
| project/subproject | directory/subdirectory (worklocation) |
| versionedfile | regular file (workfile) |

```shell
entity absolute path = project absolute path / entity relative path
filesystem location = worklocation / (entity absolute path - base project path)
```

- To specify the entire path of a project, the path must start with a forward slash (`/`). For example, `/bridge/server` specifies the `server` subproject of the `bridge` project.
- To specify a subproject of the current project, you need only use the subproject's name. For example, server specifies `/bridge/server`, assuming the current project is `bridge`.
- To specify the current project, you use one period (`.`). For example, `.` specifies `/bridge`, assuming the current project is `bridge`.
- To specify the parent of the current project, you use two periods (`..`). For example, `..` specifies the project database in which the `bridge` project resides, assuming the current project is `bridge`.
- Entity paths that contain spaces must be surrounded by single or double quotation marks. For example, `"/project1/new subproject"`.
- Entity paths can use globbing pattern: `*`, `?`, `[]`, `^`, and the escape character `\`.
- If you surround an entity path with either single or double quotation marks, the wildcard characters are ignored; the entity path is not expanded.


## pcli.exe

```shell
pcli [-nb] <command> [arg...]
```

| Option | Description |
|:-------|:------------|
| `-nb` | Turn off the sign on banner, same as `PVCS_NO_BANNER=1` |


## Run

```shell
Run [option...] <command> [arg...]
Run [option...] -s<script> [arg...]
Run [option...] -e<.exe|.bat> [arg...]
```

| Option | Description |
|:-------|:------------|
| `-y` | Force Yes response to all Yes/No queries |
| `-n` | Force No response to all Yes/No queries |
| `-ns` | Keep quotation marks for arguments except `-s` and `-e` |


## Common Project Command Options

| Option | Description | 
|:-------|:------------| 
| `-pr` | Current project database for this command execution, override `PCLI_PR` variable |
| `-pp` | Current project (entity path relative to) for this command execution, override `PCLI_PP` variable |
| `-id` | `ID[:PASSWORD]` Specify user ID and/or password for project databases and projects, override `PCLI_ID` variable |
    

## AddFiles

```shell
AddFiles [option...] <directory|workfile>...
```

| Option | GUI | Remark |
|:-------|:----|:-------|
| `-c` | Use project's workfile location and copy workfile(s) into it | Skip if already exists |
| `-co` | If workfile already exists at this location: Overwrite | **ALWAYS** use this option |
| `-z` | Include workfiles in subdirectories | **ALWAYS** use this option |
| `-d` | After Check In: Delete workfile | **NEVER** use this option, keep the original workfile unchanged |
| `-l` | After Check In: Keep revision locked | |
| `-t` | Description & Use description for all | Description for all newly added archive files, not useful |
| `-m` | "Initial revision." | **ALWAYS** use this option |
| `-qw` | If Versioned File Exists: Skip | Quietly skip and do not show warning |
| `-pw` | N/A | Specify *workpath* instead of the project's workfile location. *workpath* does not affect `-c[o]` but cooperate with `-ph`. |
| `-ph` | N/A | Create corresponding subprojects if the added directory or workfile is underneath *workpath*. |


**IMPORTANT:**
1. Add Workfiles From `/path/to/folder/*.*` or `/path/to/folder/*` in GUI is exactly the same as CLI `AddFiles /path/to/folder`, i.e. add `folder` itself into current project.
1. Only filename component of directory and workfile path supports globbing.
1. `-pw` does not change the location where workfiles copy into. 
1. `-ph` for directory creates subprojects but not adds any file under the directory.


## Get

```shell
Get [option...] <entity>...
```

| Option | GUI | Remark |
|:-------|:----|:-------|
| `-a` | Copy To / Check Out To | Specify location of workfiles, **ALWAYS** use this option |
| `-bp` | N/A | Specify the base project path mapping to `-a`, **ALWAYS** set to `-pp` to avoid mistake  |
| `-o` | Copy/Check out using project hierarchy instead of workfile locations(s) | **ALWAYS** use this option |
| `-z` | Include files in subprojects | **ALWAYS** use this option |
| `-w` | Make workfile writable | **ALWAYS** use this option |
| `-l` | Check Out | Lock the revision of the files checked out |
| `-u` | Revison newer than "MM/DD/YYYY hh:mm:ss AM" | **NEVER** use this option, since it uses FILETIME rather than check-in time |


## Put

```shell
Put [option...] <entity>...
```

| Option | GUI | Remark |
|:-------|:----|:-------|
| `-a` | Check In From | Specify location of workfiles, **ALWAYS** use this option |
| `-bp` | N/A | Specify the base project path mapping to `-a`, **ALWAYS** set to `-pp` to avoid mistake  |
| `-o` | Check in using project hierarchy instead of workfile locations(s) | **ALWAYS** use this option |
| `-z` | Include files in subprojects | **ALWAYS** use this option |
| `-m` | Description | Specify the change description for the revision, **ALWAYS** use this option |
| `-ym` | Use change description for all | **ALWAYS** use this option |
| `-k` | (WITHOUT) After Check In: Keep read-only workfile | Keep the original workfile unchanged, **ALWAYS** use this option |
| `-l` | After Check In: Kepp revision locked | Performs a Get with lock after the Put operation |


## Lock

```shell
Lock [option...] <entity>...
```

| Option | GUI | Remark |
|:-------|:----|:-------|
| `-z` | Include files in subprojects | |


## Unlock

```shell
Unlock [option...] <entity>...
```

| Option | GUI | Remark |
|:-------|:----|:-------|
| `-z` | Include files in subprojects | |

