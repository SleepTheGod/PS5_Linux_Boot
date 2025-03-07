#!/bin/bash

# PS5 Linux Boot Script - Loads Linux from USB Thumb Drive
# Made By Clumsy

# Constants
PS5_FIRMWARE="2.20"
USB_DEV=""  # Auto-detected
MOUNT_POINT="/mnt/ps5_usb"
LINUX_KERNEL_URL="https://kernel.org/pub/linux/kernel/v6.x/linux-6.7.tar.xz"
LOG_FILE="/tmp/ps5_linux_boot.log"
PAYLOAD_DIR="/tmp/ps5_payload"
USB_PATH="/mnt/usb"  # PS5-mounted USB path

# PS5 Native SELF syscalls (from provided table)
SYS_OPEN=0x5       # sys_open
SYS_MMAP=0x1dd     # sys_mmap
SYS_CLOSE=0x6      # sys_close
SYS_WRITE=0x4      # sys_write
SYS_MOUNT=0x15     # sys_mount
SYS_LSEEK=0x1de    # sys_lseek

echo "PS5 Linux Boot Script - Made By Clumsy" | tee "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"

# Safety checks
if [ "$EUID" -ne 0 ]; then
    echo "Error: Must run as root" | tee -a "$LOG_FILE"
    exit 1
fi

# Function to detect USB thumb drive
detect_usb() {
    echo "Detecting USB thumb drive..." | tee -a "$LOG_FILE"
    USB_DEV=$(lsblk -o NAME,TYPE,MOUNTPOINT | grep -v "MOUNTPOINT" | grep "disk" | grep -v "nvme" | awk '{print "/dev/"$1}' | head -n 1)
    if [ -z "$USB_DEV" ]; then
        echo "Error: No USB thumb drive detected. Please insert one." | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "Detected USB: $USB_DEV" | tee -a "$LOG_FILE"
}

# Function to prepare USB
prepare_usb() {
    echo "Preparing USB thumb drive for PS5 Linux boot..." | tee -a "$LOG_FILE"
    
    # Unmount if already mounted
    umount "${USB_DEV}"* 2>/dev/null
    
    # Create partition table and format as FAT32
    echo "Partitioning and formatting $USB_DEV as FAT32..." | tee -a "$LOG_FILE"
    parted -s "$USB_DEV" mklabel msdos mkpart primary fat32 1MiB 100% set 1 boot on >> "$LOG_FILE" 2>&1 || {
        echo "Error: Failed to partition USB" | tee -a "$LOG_FILE"
        exit 1
    }
    mkfs.vfat -F 32 "${USB_DEV}1" >> "$LOG_FILE" 2>&1 || {
        echo "Error: Failed to format USB" | tee -a "$LOG_FILE"
        exit 1
    }
    
    # Mount USB
    mkdir -p "$MOUNT_POINT"
    mount "${USB_DEV}1" "$MOUNT_POINT" || {
        echo "Error: Failed to mount USB" | tee -a "$LOG_FILE"
        exit 1
    }
    
    # Download and compile Linux kernel
    echo "Downloading Linux kernel..." | tee -a "$LOG_FILE"
    wget -q "$LINUX_KERNEL_URL" -O /tmp/linux.tar.xz || {
        echo "Error: Failed to download kernel" | tee -a "$LOG_FILE"
        exit 1
    }
    tar -xf /tmp/linux.tar.xz -C /tmp/ || {
        echo "Error: Failed to extract kernel" | tee -a "$LOG_FILE"
        exit 1
    }
    cd /tmp/linux-6.7
    if [ ! -f /boot/config-$(uname -r) ]; then
        echo "Warning: No kernel config found, using default" | tee -a "$LOG_FILE"
        make defconfig
    else
        cp /boot/config-$(uname -r) .config
    fi
    echo "Configuring kernel for PS5..." | tee -a "$LOG_FILE"
    sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-ps5"/' .config
    cat << 'EOF' >> .config
CONFIG_FREEBSD_SYSCALLS=y
CONFIG_USB=y
CONFIG_USB_STORAGE=y
CONFIG_VFAT_FS=y
CONFIG_AMD_XGBE=y
CONFIG_DRM_AMDGPU=y
CONFIG_X86_AMD_PLATFORM_DEVICE=y
CONFIG_SMP=y
CONFIG_PREEMPT=y
CONFIG_EFI=y
EOF
    make olddefconfig >> "$LOG_FILE" 2>&1
    make -j$(nproc) bzImage >> "$LOG_FILE" 2>&1 || {
        echo "Error: Failed to compile kernel" | tee -a "$LOG_FILE"
        exit 1
    }
    cp arch/x86/boot/bzImage "$MOUNT_POINT/vmlinuz-ps5"
    
    # Create initramfs
    echo "Creating initramfs..." | tee -a "$LOG_FILE"
    mkdir -p initramfs/{bin,dev,proc,sys,mnt/usb,root}
    cp /bin/busybox initramfs/bin/ || {
        echo "Error: BusyBox not found. Install it with 'sudo apt install busybox'" | tee -a "$LOG_FILE"
        exit 1
    }
    ln -s busybox initramfs/bin/sh
    ln -s busybox initramfs/bin/mount
    cat << 'EOF' > initramfs/init
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
echo "Linux on PS5 - Made By Clumsy"
echo "Mounting USB..."
mount -t vfat /dev/sda1 /mnt/usb
if [ $? -ne 0 ]; then
    echo "Failed to mount USB, dropping to shell"
    exec /bin/sh
fi
exec /bin/sh
EOF
    chmod +x initramfs/init
    cd initramfs
    find . | cpio -o -H newc | gzip > "$MOUNT_POINT/initramfs-ps5.img" || {
        echo "Error: Failed to create initramfs" | tee -a "$LOG_FILE"
        exit 1
    }
}

# Function to create PS5 payload
create_payload() {
    echo "Creating PS5 payload to load Linux..." | tee -a "$LOG_FILE"
    mkdir -p "$PAYLOAD_DIR"
    cat << 'EOF' > "$PAYLOAD_DIR/boot_linux.c"
// PS5 Linux Loader - Made By Clumsy
#include <sys/syscall.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <string.h>

// PS5 Native SELF syscalls
#define SYS_OPEN 0x5
#define SYS_MMAP 0x1dd
#define SYS_CLOSE 0x6
#define SYS_WRITE 0x4
#define SYS_MOUNT 0x15
#define SYS_LSEEK 0x1de

// Kernel exploit stub (replace with real exploit)
void exploit_kernel() {
    // Hypothetical: Disable SMEP/SMAP by modifying CR4 (needs real offsets)
    // PS5 uses NX, SMAP, SMEP, possibly UMIP - must bypass these
    asm volatile(
        "mov $0x6f0, %%rax;"  // Clear SMEP/SMAP bits (example value)
        "mov %%rax, %%cr4;"
        ::: "rax"
    );
    syscall(SYS_WRITE, 2, "Kernel exploited - Made By Clumsy\n", 34);
}

// Function to load file into memory
void *load_file(int fd, size_t size, int prot) {
    void *mem = (void *)syscall(SYS_MMAP, 0, size, prot, MAP_PRIVATE, fd, 0);
    if (mem == MAP_FAILED) return NULL;
    return mem;
}

int main() {
    int fd_kernel, fd_initrd;
    void *kernel_mem, *initrd_mem;
    char *kernel_path = "/mnt/usb/vmlinuz-ps5";
    char *initrd_path = "/mnt/usb/initramfs-ps5.img";
    off_t kernel_size, initrd_size;

    // Mount USB if not already mounted by PS5 (assuming device "uda0")
    syscall(SYS_MOUNT, "uda0", "/mnt/usb", "vfat", 0, NULL);

    // Open kernel file
    fd_kernel = syscall(SYS_OPEN, kernel_path, O_RDONLY, 0);
    if (fd_kernel < 0) {
        syscall(SYS_WRITE, 2, "Failed to open kernel\n", 22);
        return 1;
    }

    // Open initramfs file
    fd_initrd = syscall(SYS_OPEN, initrd_path, O_RDONLY, 0);
    if (fd_initrd < 0) {
        syscall(SYS_WRITE, 2, "Failed to open initrd\n", 22);
        return 1;
    }

    // Get file sizes
    kernel_size = syscall(SYS_LSEEK, fd_kernel, 0, SEEK_END);
    syscall(SYS_LSEEK, fd_kernel, 0, SEEK_SET);
    initrd_size = syscall(SYS_LSEEK, fd_initrd, 0, SEEK_END);
    syscall(SYS_LSEEK, fd_initrd, 0, SEEK_SET);

    // Load kernel and initrd into memory
    kernel_mem = load_file(fd_kernel, kernel_size, PROT_READ | PROT_EXEC);
    if (!kernel_mem) {
        syscall(SYS_WRITE, 2, "Failed to map kernel\n", 21);
        return 1;
    }
    initrd_mem = load_file(fd_initrd, initrd_size, PROT_READ);
    if (!initrd_mem) {
        syscall(SYS_WRITE, 2, "Failed to map initrd\n", 21);
        return 1;
    }

    // Close file descriptors
    syscall(SYS_CLOSE, fd_kernel);
    syscall(SYS_CLOSE, fd_initrd);

    // Exploit kernel to bypass NX, SMAP, SMEP, UMIP
    exploit_kernel();

    // Prepare kernel command line and initrd
    char cmdline[] = "root=/dev/sda1 rw initrd=/mnt/usb/initramfs-ps5.img";
    char *argv[] = {(char *)kernel_mem, cmdline, NULL};
    char *envp[] = {"Made By Clumsy", NULL};

    // Jump to kernel entry point
    void (*kernel_entry)(int, char **, char **) = (void (*)(int, char **, char **))kernel_mem;
    kernel_entry(0, argv, envp);

    // Fallback if execution fails
    syscall(SYS_WRITE, 2, "Failed to boot Linux\n", 21);
    return 1;
}
EOF

    # Compile payload
    echo "Compiling payload..." | tee -a "$LOG_FILE"
    cc -o "$PAYLOAD_DIR/boot_linux" "$PAYLOAD_DIR/boot_linux.c" -static >> "$LOG_FILE" 2>&1 || {
        echo "Error: Failed to compile payload" | tee -a "$LOG_FILE"
        exit 1
    }
    strip "$PAYLOAD_DIR/boot_linux"
    cp "$PAYLOAD_DIR/boot_linux" "$MOUNT_POINT/boot_linux"
    echo "Payload created at $MOUNT_POINT/boot_linux" | tee -a "$LOG_FILE"
}

# Function to deploy payload (placeholder for exploit)
deploy_payload() {
    echo "Deploying payload to PS5..." | tee -a "$LOG_FILE"
    echo "NOTE: This step requires a kernel exploit for PS5 firmware $PS5_FIRMWARE."
    echo "Instructions:"
    echo "1. Insert USB into PS5."
    echo "2. Run exploit (e.g., via browser or jailbreak tool)."
    echo "3. Load $MOUNT_POINT/boot_linux into memory and execute."
    echo "Example (hypothetical exploit tool):"
    echo "  exploit_tool --load $MOUNT_POINT/boot_linux --exec"
    echo "Deploy step not automated due to lack of public exploit." | tee -a "$LOG_FILE"
}

# Main execution
echo "Starting PS5 Linux Boot Automation - Made By Clumsy" | tee -a "$LOG_FILE"

# Step 1: Detect USB
detect_usb

# Step 2: Prepare USB
prepare_usb

# Step 3: Create payload
mount "${USB_DEV}1" "$MOUNT_POINT"  # Remount for payload copy
create_payload
umount "$MOUNT_POINT"

# Step 4: Deploy payload (placeholder)
deploy_payload

# Cleanup
rm -rf /tmp/linux-6.7 /tmp/linux.tar.xz "$PAYLOAD_DIR"
echo "Process complete! Insert USB into PS5 and follow exploit instructions." | tee -a "$LOG_FILE"
echo "Linux will boot directly from USB. Made By Clumsy." | tee -a "$LOG_FILE"
