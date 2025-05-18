# Dependency Downloader Script

I had a computer that was completely offline, so I needed a solution to install apps on said computer without encountering Dependency Hell. In turn, I created **dependency-find** — a cross-distro Bash script that recursively resolves and downloads the dependency packages for a given application package. It works on Debian-based, RHEL-based, Arch-based, and openSUSE-based systems, making it a handy offline package mirror builder or portable installer assistant.

---

## Features

- Detects the system's Linux distribution automatically
- Recursively resolves package dependencies
- Optionally generates a complete dependency list text file
- Supports auto-download mode without prompts
- Allows custom download directory
- Displays a progress bar during downloads
- Supports the following distributions:
  - Debian, Ubuntu, Linux Mint, Pop!_OS
  - Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux
  - Arch Linux
  - openSUSE


## Usage

```bash
./dependency-downloader.sh [options] <package-name>
```
Example:
- Download vlc and its dependencies into a custom folder without confirmation:
```bash
./dependency-downloader.sh -d -o /home/user/package-downloads vlc
```

## Options

| Option       | Description                                                          |
| :----------- | :------------------------------------------------------------------- |
| `-d` or `-y` | Automatically downloads dependencies without asking for confirmation |
| `-o <dir>`   | Set a custom output directory for the downloaded packages            |
| `-n`         | Do **not** generate the dependency list text file                    |
| `-h`         | Display help message and exit                                        |


## Requirements

This script requires the following tools installed on your system:

- Debian/Ubuntu: apt-cache, apt-get

- RHEL/Fedora: dnf, repoquery

- Arch Linux: pacman, pactree

- openSUSE: zypper

## Output

Downloaded packages are saved in:
```bash
/home/<user>/<package-name>-depends/
```
or in the specified **-o** directory

A plain text file listing all resolved packages:
```bash
<package-name>-complete-package-list.txt
```
## Notes
If a dependency cannot be downloaded, a warning is displayed.

The dependency resolution process runs in 8 recursive iterations to capture nested dependencies.

Some meta or virtual package dependencies (e.g., <any> entries) are ignored.

Not designed for systems lacking a package manager or offline systems without cached packages.

## License

This script is provided as-is, without warranty. Feel free to modify and distribute as needed.
