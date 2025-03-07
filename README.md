# PS5 Linux Boot

# Overview
This repository contains a script, ps5_linux_boot.sh, designed to automate the process of booting Linux from a USB thumb drive on a retail PlayStation 5 (PS5) running firmware 2.20. The script prepares a USB drive with a Linux kernel, an initial ramdisk (initramfs), and a payload that uses the PS5's "Native SELF" syscall table to load and execute Linux directly. This project is credited to "Made By Clumsy."

# Note - This script requires a kernel exploit to bypass the PS5's security features (NX bit, SMAP, SMEP, UMIP). As of March 7, 2025, no public exploit exists for firmware 2.20, so the deployment step is manual.

# Features
Automatically detects and prepares a USB thumb drive with a bootable Linux environment.
Compiles Linux kernel 6.7 with PS5-compatible drivers (e.g., AMDGPU for RDNA 2 GPU).
Creates a minimal initramfs using BusyBox.
Generates a payload (boot_linux) that uses PS5 "Native SELF" syscalls to boot Linux directly from USB.
Includes detailed logging in /tmp/ps5_linux_boot.log.

# Prerequisites
A Linux PC to run the script.
A USB thumb drive (at least 1GB recommended).
Root privileges on the Linux PC (sudo).
Required tools - parted, wget, gcc, make, busybox (install with sudo apt install parted wget gcc make busybox on Debian/Ubuntu).
A PS5 on firmware 2.20 with a kernel exploit (not included).

# Usage
Clone the Repository git clone https://github.com/SleepTheGod/PS5_Linux_Boot.git cd PS5_Linux_Boot
Make the Script Executable chmod +x ps5_linux_boot.sh
Run the Script
Insert a USB thumb drive into your Linux PC.
Execute the script with root privileges sudo ./ps5_linux_boot.sh
The script will
Detect the USB drive.
Partition and format it as FAT32.
Download and compile Linux kernel 6.7.
Create an initramfs.
Build and copy the boot_linux payload to the USB.
Insert USB into PS5
After the script completes, safely eject the USB and plug it into your PS5.

# Trigger Exploit
Use a PS5 jailbreak tool or browser exploit for firmware 2.20 (not provided).
Load and execute the payload located at /mnt/usb/boot_linux on the USB.
Example (hypothetical) exploit_tool --load /mnt/usb/boot_linux --exec
Boot Linux
If successful, Linux will boot from the USB, displaying "Linux on PS5 - Made By Clumsy" and dropping to a shell.

# Script Details
File - ps5_linux_boot.sh
Syscalls Used - Based on PS5 kernel 2.20 "Native SELF" table
SYS_OPEN (0x5) - Open files.
SYS_MMAP (0x1dd) - Map files into memory.
SYS_CLOSE (0x6) - Close file descriptors.
SYS_WRITE (0x4) - Write debug messages.
SYS_MOUNT (0x15) - Mount the USB.
SYS_LSEEK (0x1de) - Get file sizes.
Security Bypass - The payload includes a stub (exploit_kernel()) to disable NX, SMAP, SMEP, and UMIP. Replace this with a real exploit for functionality.
Output - Logs are saved to /tmp/ps5_linux_boot.log for troubleshooting.

# Limitations
Exploit Required - The payload won’t run without a kernel exploit for firmware 2.20. Check PS5 homebrew communities (e.g., X posts) for updates.
Untested - Developed without access to a PS5; verify on jailbroken hardware.
Basic Functionality - The kernel supports basic hardware (CPU, USB); GPU and other PS5-specific drivers need further porting.
Risk - Incorrect exploit use may brick your PS5. Proceed with caution.

# Troubleshooting
Script Fails - Check /tmp/ps5_linux_boot.log for errors (e.g., missing tools, USB not detected).
USB Not Recognized - Ensure it’s plugged in before running the script and not mounted elsewhere.
Linux Doesn’t Boot - Verify the exploit loaded boot_linux correctly. Adjust exploit_kernel() with real CR4 offsets if needed.

# Contributing
Feel free to fork this repo, improve the script, or add a working exploit. Submit pull requests or open issues at
https://github.com/SleepTheGod/PS5_Linux_Boot/

# Credits
Made By Clumsy - Original script author.
SleepTheGod - Repository maintainer.

# License
This project is open-source and provided as-is. Use at your own risk.
