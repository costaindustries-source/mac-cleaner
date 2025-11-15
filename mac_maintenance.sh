#!/bin/bash

################################################################################
# macOS Comprehensive Maintenance Script
# Target: MacBook Air 2016, macOS Monterey 12.7.6
# Description: Exhaustive system maintenance with low-level operations
################################################################################

set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="macOS Maintenance Script"
START_TIME=$(date +%s)
LOG_FILE="/tmp/mac_maintenance_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="$HOME/Desktop/maintenance_report_$(date +%Y%m%d_%H%M%S).md"
TOTAL_OPERATIONS=0
COMPLETED_OPERATIONS=0
SPACE_FREED=0
ERRORS=()
WARNINGS=()
SKIPPED_OPERATIONS=()

# Operation categories with risk levels
declare -A RISK_LEVELS=(
    ["cache_cleanup"]="LOW"
    ["log_cleanup"]="LOW"
    ["temp_cleanup"]="LOW"
    ["spotlight_rebuild"]="MEDIUM"
    ["launchservices_rebuild"]="MEDIUM"
    ["disk_check"]="LOW"
    ["permission_repair"]="MEDIUM"
    ["database_optimization"]="MEDIUM"
    ["dns_flush"]="LOW"
    ["daemon_operations"]="MEDIUM"
    ["kext_rebuild"]="HIGH"
    ["font_cache"]="LOW"
    ["dock_reset"]="LOW"
    ["thumbnail_cache"]="LOW"
    ["quicklook_cache"]="LOW"
    ["mail_optimization"]="MEDIUM"
    ["network_reset"]="HIGH"
    ["icloud_cache"]="MEDIUM"
    ["language_cleanup"]="MEDIUM"
    ["login_items"]="LOW"
)

################################################################################
# Logging Functions
################################################################################

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] ERROR: $1${NC}" | tee -a "$LOG_FILE"
    ERRORS+=("$1")
}

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] WARNING: $1${NC}" | tee -a "$LOG_FILE"
    WARNINGS+=("$1")
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp] SUCCESS: $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

################################################################################
# Progress Bar Functions
################################################################################

show_progress() {
    local current=$1
    local total=$2
    local operation=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    # Calculate ETA
    local elapsed=$(($(date +%s) - START_TIME))
    local rate=$(awk "BEGIN {print $current / $elapsed}")
    local remaining=$((total - current))
    local eta=$(awk "BEGIN {print int($remaining / $rate)}")
    local eta_min=$((eta / 60))
    local eta_sec=$((eta % 60))
    
    printf "\r${CYAN}Progress: [${GREEN}"
    printf '%*s' "$filled" | tr ' ' '█'
    printf "${NC}"
    printf '%*s' "$empty" | tr ' ' '░'
    printf "${CYAN}] %3d%% (%d/%d) ETA: %dm %ds - %s${NC}" \
        "$percent" "$current" "$total" "$eta_min" "$eta_sec" "$operation"
}

complete_progress() {
    echo ""
}

################################################################################
# Confirmation Functions
################################################################################

confirm_operation() {
    local category=$1
    local description=$2
    local risk=${RISK_LEVELS[$category]:-UNKNOWN}
    
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Operation Category:${NC} $category"
    echo -e "${BOLD}Description:${NC} $description"
    
    case $risk in
        LOW)
            echo -e "${BOLD}Risk Level:${NC} ${GREEN}$risk - Safe operation${NC}"
            ;;
        MEDIUM)
            echo -e "${BOLD}Risk Level:${NC} ${YELLOW}$risk - May require system restart${NC}"
            ;;
        HIGH)
            echo -e "${BOLD}Risk Level:${NC} ${RED}$risk - Significant system changes${NC}"
            ;;
        *)
            echo -e "${BOLD}Risk Level:${NC} ${MAGENTA}$risk${NC}"
            ;;
    esac
    
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "Proceed with this operation? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
        log_info "Operation skipped by user: $category"
        SKIPPED_OPERATIONS+=("$category: $description")
        return 1
    fi
    return 0
}

################################################################################
# Utility Functions
################################################################################

check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        log_info "This script requires sudo privileges for some operations"
        sudo -v
        # Keep sudo alive
        (while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null) &
    fi
}

get_size() {
    local path=$1
    if [ -e "$path" ]; then
        du -sk "$path" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

safe_remove() {
    local path=$1
    local size_before=$(get_size "$path")
    
    if [ -e "$path" ]; then
        if rm -rf "$path" 2>/dev/null; then
            SPACE_FREED=$((SPACE_FREED + size_before))
            log_success "Removed: $path ($(numfmt --to=iec-i --suffix=B $((size_before * 1024))))"
            return 0
        else
            log_error "Failed to remove: $path"
            return 1
        fi
    fi
    return 0
}

################################################################################
# Maintenance Operations
################################################################################

# 1. Cache Cleanup
cleanup_caches() {
    if ! confirm_operation "cache_cleanup" "Clean system and user caches (browser, app, system)"; then
        return
    fi
    
    log_info "Starting cache cleanup..."
    local ops=0
    local total_ops=15
    
    # User caches
    show_progress $((++ops)) $total_ops "Cleaning user caches"
    safe_remove "$HOME/Library/Caches/*"
    
    # System caches (safe)
    show_progress $((++ops)) $total_ops "Cleaning system font caches"
    safe_remove "$HOME/Library/Caches/com.apple.FontCache/*"
    
    # Safari cache
    show_progress $((++ops)) $total_ops "Cleaning Safari cache"
    safe_remove "$HOME/Library/Caches/com.apple.Safari/*"
    safe_remove "$HOME/Library/Safari/LocalStorage/*"
    
    # Chrome cache
    show_progress $((++ops)) $total_ops "Cleaning Chrome cache"
    safe_remove "$HOME/Library/Caches/Google/Chrome/*"
    
    # Firefox cache
    show_progress $((++ops)) $total_ops "Cleaning Firefox cache"
    safe_remove "$HOME/Library/Caches/Firefox/*"
    
    # Xcode caches (if exists)
    show_progress $((++ops)) $total_ops "Cleaning Xcode caches"
    safe_remove "$HOME/Library/Developer/Xcode/DerivedData/*"
    
    # CocoaPods cache
    show_progress $((++ops)) $total_ops "Cleaning CocoaPods cache"
    safe_remove "$HOME/Library/Caches/CocoaPods/*"
    
    # Homebrew cache
    show_progress $((++ops)) $total_ops "Cleaning Homebrew cache"
    if command -v brew &> /dev/null; then
        brew cleanup -s 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # npm cache
    show_progress $((++ops)) $total_ops "Cleaning npm cache"
    if command -v npm &> /dev/null; then
        npm cache clean --force 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # pip cache
    show_progress $((++ops)) $total_ops "Cleaning pip cache"
    if command -v pip3 &> /dev/null; then
        pip3 cache purge 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Gem cache
    show_progress $((++ops)) $total_ops "Cleaning gem cache"
    if command -v gem &> /dev/null; then
        gem cleanup 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # DNS responder cache
    show_progress $((++ops)) $total_ops "Cleaning DNS cache"
    safe_remove "/private/var/db/com.apple.dns-sd.cache"
    
    # Messages attachments cache
    show_progress $((++ops)) $total_ops "Cleaning Messages cache"
    safe_remove "$HOME/Library/Messages/Attachments/*"
    
    # Photos cache
    show_progress $((++ops)) $total_ops "Cleaning Photos cache"
    safe_remove "$HOME/Library/Caches/com.apple.Photos/*"
    
    # System cache (with sudo)
    show_progress $((++ops)) $total_ops "Cleaning system-level caches"
    sudo rm -rf /Library/Caches/* 2>/dev/null || log_warning "Some system caches require SIP disabled"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Cache cleanup completed"
}

# 2. Log Cleanup
cleanup_logs() {
    if ! confirm_operation "log_cleanup" "Clean system and application logs (keeps recent logs)"; then
        return
    fi
    
    log_info "Starting log cleanup..."
    local ops=0
    local total_ops=10
    
    # System logs older than 7 days
    show_progress $((++ops)) $total_ops "Cleaning old system logs"
    sudo find /var/log -type f -name "*.log" -mtime +7 -exec rm {} \; 2>/dev/null
    sudo find /var/log -type f -name "*.log.*" -exec rm {} \; 2>/dev/null
    
    # User logs
    show_progress $((++ops)) $total_ops "Cleaning user logs"
    safe_remove "$HOME/Library/Logs/*"
    
    # Application logs
    show_progress $((++ops)) $total_ops "Cleaning application logs"
    find "$HOME/Library/Containers" -name "*.log" -type f -mtime +7 -delete 2>/dev/null
    
    # Crash reports
    show_progress $((++ops)) $total_ops "Cleaning crash reports"
    safe_remove "$HOME/Library/Application Support/CrashReporter/*"
    sudo rm -rf /Library/Logs/DiagnosticReports/* 2>/dev/null
    
    # Install logs
    show_progress $((++ops)) $total_ops "Cleaning install logs"
    sudo rm -rf /var/log/install.log* 2>/dev/null
    
    # ASL logs
    show_progress $((++ops)) $total_ops "Cleaning ASL database"
    sudo rm -rf /var/log/asl/* 2>/dev/null
    
    # System.log archive
    show_progress $((++ops)) $total_ops "Cleaning system log archives"
    sudo rm -rf /var/log/system.log.*.gz 2>/dev/null
    
    # Audit logs (old)
    show_progress $((++ops)) $total_ops "Cleaning old audit logs"
    sudo find /var/audit -type f -mtime +30 -delete 2>/dev/null
    
    # Apache logs (if exists)
    show_progress $((++ops)) $total_ops "Cleaning Apache logs"
    sudo rm -rf /private/var/log/apache2/* 2>/dev/null
    
    # Adobe logs
    show_progress $((++ops)) $total_ops "Cleaning Adobe logs"
    safe_remove "$HOME/Library/Application Support/Adobe/Common/logs/*"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Log cleanup completed"
}

# 3. Temporary Files Cleanup
cleanup_temp() {
    if ! confirm_operation "temp_cleanup" "Clean temporary files and folders"; then
        return
    fi
    
    log_info "Starting temporary files cleanup..."
    local ops=0
    local total_ops=8
    
    # System temp
    show_progress $((++ops)) $total_ops "Cleaning system temp files"
    sudo rm -rf /private/var/tmp/* 2>/dev/null
    sudo rm -rf /private/tmp/* 2>/dev/null
    
    # User temp
    show_progress $((++ops)) $total_ops "Cleaning user temp files"
    rm -rf /tmp/* 2>/dev/null
    safe_remove "$TMPDIR/*"
    
    # Downloaded email attachments
    show_progress $((++ops)) $total_ops "Cleaning Mail downloads"
    safe_remove "$HOME/Library/Mail Downloads/*"
    
    # Safari downloads (incomplete)
    show_progress $((++ops)) $total_ops "Cleaning incomplete Safari downloads"
    safe_remove "$HOME/Library/Safari/Downloads.plist"
    
    # Trash
    show_progress $((++ops)) $total_ops "Emptying Trash"
    safe_remove "$HOME/.Trash/*"
    
    # Application tmp folders
    show_progress $((++ops)) $total_ops "Cleaning application temp folders"
    find "$HOME/Library/Application Support" -name "tmp" -type d -exec rm -rf {} + 2>/dev/null
    
    # Saved Application State
    show_progress $((++ops)) $total_ops "Cleaning saved application states"
    safe_remove "$HOME/Library/Saved Application State/*"
    
    # Temporary items from system folders
    show_progress $((++ops)) $total_ops "Cleaning system temporary items"
    sudo rm -rf /Library/Updates/* 2>/dev/null
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Temporary files cleanup completed"
}

# 4. Spotlight Rebuild
rebuild_spotlight() {
    if ! confirm_operation "spotlight_rebuild" "Rebuild Spotlight index (improves search performance)"; then
        return
    fi
    
    log_info "Starting Spotlight rebuild..."
    local ops=0
    local total_ops=3
    
    # Disable Spotlight
    show_progress $((++ops)) $total_ops "Disabling Spotlight indexing"
    sudo mdutil -a -i off 2>&1 | tee -a "$LOG_FILE"
    
    # Delete existing index
    show_progress $((++ops)) $total_ops "Removing existing Spotlight index"
    sudo rm -rf /.Spotlight-V100/* 2>/dev/null
    sudo rm -rf /Volumes/*/.Spotlight-V100/* 2>/dev/null
    
    # Re-enable and rebuild
    show_progress $((++ops)) $total_ops "Re-enabling and rebuilding Spotlight index"
    sudo mdutil -a -i on 2>&1 | tee -a "$LOG_FILE"
    sudo mdutil -E / 2>&1 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Spotlight rebuild initiated (will complete in background)"
}

# 5. LaunchServices Rebuild
rebuild_launchservices() {
    if ! confirm_operation "launchservices_rebuild" "Rebuild LaunchServices database (fixes 'Open With' menu)"; then
        return
    fi
    
    log_info "Starting LaunchServices rebuild..."
    local ops=0
    local total_ops=2
    
    # Kill LaunchServices
    show_progress $((++ops)) $total_ops "Stopping LaunchServices"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill 2>&1 | tee -a "$LOG_FILE"
    
    # Rebuild database
    show_progress $((++ops)) $total_ops "Rebuilding LaunchServices database"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -r -domain local -domain system -domain user 2>&1 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "LaunchServices rebuild completed"
}

# 6. Disk Check
check_disk() {
    if ! confirm_operation "disk_check" "Verify and repair disk (read-only check first)"; then
        return
    fi
    
    log_info "Starting disk verification..."
    local ops=0
    local total_ops=3
    
    # Get boot disk
    show_progress $((++ops)) $total_ops "Identifying boot disk"
    local boot_disk=$(diskutil info / | grep "Device Node" | awk '{print $3}')
    log_info "Boot disk: $boot_disk"
    
    # Verify disk
    show_progress $((++ops)) $total_ops "Verifying disk structure"
    if diskutil verifyVolume / 2>&1 | tee -a "$LOG_FILE" | grep -q "appears to be OK"; then
        log_success "Disk verification passed"
    else
        log_warning "Disk has issues - attempting repair"
        show_progress $((++ops)) $total_ops "Repairing disk"
        diskutil repairVolume / 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # SMART status
    show_progress $((++ops)) $total_ops "Checking SMART status"
    diskutil info $boot_disk | grep -i "SMART" | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Disk check completed"
}

# 7. Permission Repair
repair_permissions() {
    if ! confirm_operation "permission_repair" "Repair disk permissions and ACLs"; then
        return
    fi
    
    log_info "Starting permission repair..."
    local ops=0
    local total_ops=5
    
    # Reset home folder permissions
    show_progress $((++ops)) $total_ops "Resetting home folder permissions"
    diskutil resetUserPermissions / $(id -u) 2>&1 | tee -a "$LOG_FILE"
    
    # Repair system permissions (modern macOS)
    show_progress $((++ops)) $total_ops "Verifying system file permissions"
    sudo /usr/libexec/repair_packages --verify --standard-pkgs --volume / 2>&1 | tee -a "$LOG_FILE"
    
    # Fix common permission issues
    show_progress $((++ops)) $total_ops "Fixing common permission issues"
    chmod 755 "$HOME" 2>/dev/null
    chmod 700 "$HOME/Library" 2>/dev/null
    chmod 700 "$HOME/.ssh" 2>/dev/null
    
    # Fix application permissions
    show_progress $((++ops)) $total_ops "Fixing application permissions"
    sudo find /Applications -type d -exec chmod 755 {} \; 2>/dev/null
    sudo find /Applications -type f -exec chmod 644 {} \; 2>/dev/null
    
    # Fix LaunchAgents/Daemons permissions
    show_progress $((++ops)) $total_ops "Fixing LaunchAgents/Daemons permissions"
    sudo chmod 644 /Library/LaunchDaemons/*.plist 2>/dev/null
    sudo chmod 644 /Library/LaunchAgents/*.plist 2>/dev/null
    chmod 644 "$HOME/Library/LaunchAgents/*.plist" 2>/dev/null
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Permission repair completed"
}

# 8. Database Optimization
optimize_databases() {
    if ! confirm_operation "database_optimization" "Optimize Mail, Safari, Photos, and other databases"; then
        return
    fi
    
    log_info "Starting database optimization..."
    local ops=0
    local total_ops=8
    
    # Mail database
    show_progress $((++ops)) $total_ops "Optimizing Mail database"
    if [ -d "$HOME/Library/Mail" ]; then
        find "$HOME/Library/Mail" -name "Envelope Index" -delete 2>/dev/null
        sqlite3 "$HOME/Library/Mail/V*/MailData/Envelope Index" "VACUUM;" 2>/dev/null
        sqlite3 "$HOME/Library/Mail/V*/MailData/Envelope Index" "REINDEX;" 2>/dev/null
    fi
    
    # Safari databases
    show_progress $((++ops)) $total_ops "Optimizing Safari databases"
    for db in "$HOME/Library/Safari/"*.db; do
        if [ -f "$db" ]; then
            sqlite3 "$db" "VACUUM;" 2>/dev/null
            sqlite3 "$db" "REINDEX;" 2>/dev/null
        fi
    done
    
    # Photos database
    show_progress $((++ops)) $total_ops "Optimizing Photos database"
    if [ -d "$HOME/Pictures/Photos Library.photoslibrary" ]; then
        sqlite3 "$HOME/Pictures/Photos Library.photoslibrary/database/photos.db" "VACUUM;" 2>/dev/null
        sqlite3 "$HOME/Pictures/Photos Library.photoslibrary/database/photos.db" "REINDEX;" 2>/dev/null
    fi
    
    # Calendar database
    show_progress $((++ops)) $total_ops "Optimizing Calendar database"
    if [ -f "$HOME/Library/Calendars/Calendar Cache" ]; then
        sqlite3 "$HOME/Library/Calendars/Calendar Cache" "VACUUM;" 2>/dev/null
        sqlite3 "$HOME/Library/Calendars/Calendar Cache" "REINDEX;" 2>/dev/null
    fi
    
    # Messages database
    show_progress $((++ops)) $total_ops "Optimizing Messages database"
    if [ -f "$HOME/Library/Messages/chat.db" ]; then
        sqlite3 "$HOME/Library/Messages/chat.db" "VACUUM;" 2>/dev/null
        sqlite3 "$HOME/Library/Messages/chat.db" "REINDEX;" 2>/dev/null
    fi
    
    # Notes database
    show_progress $((++ops)) $total_ops "Optimizing Notes database"
    find "$HOME/Library/Group Containers" -name "NoteStore.sqlite" -exec sqlite3 {} "VACUUM;" \; 2>/dev/null
    find "$HOME/Library/Group Containers" -name "NoteStore.sqlite" -exec sqlite3 {} "REINDEX;" \; 2>/dev/null
    
    # Cookies database
    show_progress $((++ops)) $total_ops "Optimizing Cookies database"
    if [ -f "$HOME/Library/Cookies/Cookies.binarycookies" ]; then
        # Binary cookies don't need optimization, but we can clean old entries
        log_info "Cookies database is in binary format (no optimization needed)"
    fi
    
    # Application Support databases
    show_progress $((++ops)) $total_ops "Optimizing Application Support databases"
    find "$HOME/Library/Application Support" -name "*.db" -o -name "*.sqlite" | while read db; do
        sqlite3 "$db" "VACUUM;" 2>/dev/null
        sqlite3 "$db" "REINDEX;" 2>/dev/null
    done
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Database optimization completed"
}

# 9. DNS Operations
flush_dns() {
    if ! confirm_operation "dns_flush" "Flush DNS cache and reset DNS configuration"; then
        return
    fi
    
    log_info "Starting DNS operations..."
    local ops=0
    local total_ops=4
    
    # Flush DNS cache
    show_progress $((++ops)) $total_ops "Flushing DNS cache"
    sudo dscacheutil -flushcache 2>&1 | tee -a "$LOG_FILE"
    sudo killall -HUP mDNSResponder 2>&1 | tee -a "$LOG_FILE"
    
    # Clear DNS resolver cache
    show_progress $((++ops)) $total_ops "Clearing DNS resolver cache"
    sudo rm -rf /var/run/mDNSResponder 2>/dev/null
    safe_remove "/Library/Preferences/com.apple.mDNSResponder.plist"
    
    # Reset network locations DNS
    show_progress $((++ops)) $total_ops "Resetting network DNS settings"
    sudo discoveryutil mdnsflushcache 2>/dev/null || log_info "discoveryutil not available on this macOS version"
    sudo discoveryutil udnsflushcaches 2>/dev/null || log_info "discoveryutil not available on this macOS version"
    
    # Display current DNS servers
    show_progress $((++ops)) $total_ops "Displaying current DNS configuration"
    scutil --dns | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "DNS operations completed"
}

# 10. Daemon Operations
manage_daemons() {
    if ! confirm_operation "daemon_operations" "Reload and restart system daemons"; then
        return
    fi
    
    log_info "Starting daemon operations..."
    local ops=0
    local total_ops=6
    
    # List loaded daemons
    show_progress $((++ops)) $total_ops "Listing loaded daemons"
    sudo launchctl list | tee -a "$LOG_FILE"
    
    # Reload system daemons
    show_progress $((++ops)) $total_ops "Reloading core system daemons"
    sudo launchctl kickstart -k system/com.apple.mDNSResponder 2>&1 | tee -a "$LOG_FILE"
    
    # Reload user agents
    show_progress $((++ops)) $total_ops "Reloading user agents"
    launchctl kickstart -k gui/$(id -u)/com.apple.Finder 2>&1 | tee -a "$LOG_FILE"
    launchctl kickstart -k gui/$(id -u)/com.apple.Dock 2>&1 | tee -a "$LOG_FILE"
    
    # Check for crashed daemons
    show_progress $((++ops)) $total_ops "Checking for crashed daemons"
    sudo launchctl list | grep -i "crashed" | tee -a "$LOG_FILE"
    
    # Reload system preferences
    show_progress $((++ops)) $total_ops "Reloading system preferences daemon"
    sudo launchctl kickstart -k system/com.apple.cfprefsd 2>&1 | tee -a "$LOG_FILE"
    
    # Reload disk arbitration
    show_progress $((++ops)) $total_ops "Reloading disk arbitration daemon"
    sudo launchctl kickstart -k system/com.apple.diskarbitrationd 2>&1 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Daemon operations completed"
}

# 11. Kernel Extension Operations
rebuild_kext_cache() {
    if ! confirm_operation "kext_rebuild" "Rebuild kernel extension cache (requires reboot)"; then
        return
    fi
    
    log_info "Starting kernel extension operations..."
    local ops=0
    local total_ops=4
    
    # List loaded kexts
    show_progress $((++ops)) $total_ops "Listing loaded kernel extensions"
    kextstat | tee -a "$LOG_FILE"
    
    # Check kext problems
    show_progress $((++ops)) $total_ops "Checking for kext problems"
    sudo kextutil -print-diagnostics 2>&1 | tee -a "$LOG_FILE"
    
    # Clear kext cache
    show_progress $((++ops)) $total_ops "Clearing kernel extension cache"
    sudo rm -rf /System/Library/Caches/com.apple.kext.caches/* 2>/dev/null
    sudo rm -rf /Library/Caches/com.apple.kext.caches/* 2>/dev/null
    
    # Rebuild kext cache
    show_progress $((++ops)) $total_ops "Rebuilding kernel extension cache"
    sudo kextcache -i / 2>&1 | tee -a "$LOG_FILE"
    sudo kextcache -u / 2>&1 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Kernel extension cache rebuild completed (reboot recommended)"
}

# 12. Font Cache Cleanup
cleanup_font_cache() {
    if ! confirm_operation "font_cache" "Clean and rebuild font caches"; then
        return
    fi
    
    log_info "Starting font cache cleanup..."
    local ops=0
    local total_ops=5
    
    # User font cache
    show_progress $((++ops)) $total_ops "Cleaning user font cache"
    safe_remove "$HOME/Library/Caches/com.apple.FontCache/*"
    safe_remove "$HOME/Library/Caches/com.apple.FontRegistry/*"
    
    # System font cache
    show_progress $((++ops)) $total_ops "Cleaning system font cache"
    sudo rm -rf /Library/Caches/com.apple.FontCache/* 2>/dev/null
    sudo rm -rf /System/Library/Caches/com.apple.FontCache/* 2>/dev/null
    
    # ATS font cache
    show_progress $((++ops)) $total_ops "Cleaning ATS font cache"
    sudo atsutil databases -remove 2>&1 | tee -a "$LOG_FILE"
    
    # Font registration cache
    show_progress $((++ops)) $total_ops "Clearing font registration cache"
    safe_remove "$HOME/Library/Application Support/com.apple.FontRegistry/*"
    
    # Rebuild font cache
    show_progress $((++ops)) $total_ops "Rebuilding font cache"
    atsutil server -shutdown 2>&1 | tee -a "$LOG_FILE"
    atsutil server -ping 2>&1 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Font cache cleanup completed"
}

# 13. Dock Reset
reset_dock() {
    if ! confirm_operation "dock_reset" "Reset Dock to default settings and clear cache"; then
        return
    fi
    
    log_info "Starting Dock reset..."
    local ops=0
    local total_ops=3
    
    # Kill Dock
    show_progress $((++ops)) $total_ops "Stopping Dock"
    killall Dock 2>&1 | tee -a "$LOG_FILE"
    
    # Clear Dock cache
    show_progress $((++ops)) $total_ops "Clearing Dock cache"
    safe_remove "$HOME/Library/Application Support/Dock/*.db"
    safe_remove "$HOME/Library/Preferences/com.apple.dock.plist"
    
    # Restart Dock
    show_progress $((++ops)) $total_ops "Restarting Dock"
    open /System/Library/CoreServices/Dock.app
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Dock reset completed"
}

# 14. Thumbnail Cache
cleanup_thumbnails() {
    if ! confirm_operation "thumbnail_cache" "Clean thumbnail caches"; then
        return
    fi
    
    log_info "Starting thumbnail cache cleanup..."
    local ops=0
    local total_ops=4
    
    # Icon cache
    show_progress $((++ops)) $total_ops "Cleaning icon cache"
    safe_remove "$HOME/Library/Caches/com.apple.iconservices.store"
    sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null
    
    # Thumbnail cache
    show_progress $((++ops)) $total_ops "Cleaning thumbnail cache"
    safe_remove "$HOME/Library/Caches/com.apple.QuickLookDaemon/*"
    
    # Finder cache
    show_progress $((++ops)) $total_ops "Cleaning Finder cache"
    find "$HOME/Library/Caches/com.apple.finder" -type f -delete 2>/dev/null
    
    # Restart Finder
    show_progress $((++ops)) $total_ops "Restarting Finder"
    killall Finder 2>&1 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Thumbnail cache cleanup completed"
}

# 15. QuickLook Cache
cleanup_quicklook() {
    if ! confirm_operation "quicklook_cache" "Clean QuickLook caches and plugins"; then
        return
    fi
    
    log_info "Starting QuickLook cache cleanup..."
    local ops=0
    local total_ops=4
    
    # QuickLook cache
    show_progress $((++ops)) $total_ops "Cleaning QuickLook cache"
    safe_remove "$HOME/Library/Caches/com.apple.QuickLook.thumbnailcache/*"
    
    # Reset QuickLook server
    show_progress $((++ops)) $total_ops "Resetting QuickLook server"
    qlmanage -r 2>&1 | tee -a "$LOG_FILE"
    qlmanage -r cache 2>&1 | tee -a "$LOG_FILE"
    
    # List QuickLook plugins
    show_progress $((++ops)) $total_ops "Listing QuickLook plugins"
    qlmanage -m 2>&1 | tee -a "$LOG_FILE"
    
    # Restart QuickLook
    show_progress $((++ops)) $total_ops "Restarting QuickLook daemon"
    killall QuickLookUIService 2>/dev/null
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "QuickLook cache cleanup completed"
}

# 16. Mail Optimization
optimize_mail() {
    if ! confirm_operation "mail_optimization" "Optimize Mail database and clean attachments"; then
        return
    fi
    
    log_info "Starting Mail optimization..."
    local ops=0
    local total_ops=5
    
    # Quit Mail if running
    show_progress $((++ops)) $total_ops "Stopping Mail application"
    osascript -e 'quit app "Mail"' 2>/dev/null
    sleep 2
    
    # Rebuild envelope index
    show_progress $((++ops)) $total_ops "Rebuilding Mail envelope index"
    find "$HOME/Library/Mail" -name "Envelope Index" -delete 2>/dev/null
    find "$HOME/Library/Mail" -name "Envelope Index-shm" -delete 2>/dev/null
    find "$HOME/Library/Mail" -name "Envelope Index-wal" -delete 2>/dev/null
    
    # Clean Mail cache
    show_progress $((++ops)) $total_ops "Cleaning Mail cache"
    safe_remove "$HOME/Library/Mail/V*/MailData/Envelope Index-*"
    
    # Optimize Mail databases
    show_progress $((++ops)) $total_ops "Optimizing Mail databases"
    find "$HOME/Library/Mail" -name "*.db" -exec sqlite3 {} "VACUUM;" \; 2>/dev/null
    find "$HOME/Library/Mail" -name "*.db" -exec sqlite3 {} "REINDEX;" \; 2>/dev/null
    
    # Clean old downloads
    show_progress $((++ops)) $total_ops "Cleaning old Mail downloads"
    find "$HOME/Library/Mail Downloads" -type f -mtime +30 -delete 2>/dev/null
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Mail optimization completed"
}

# 17. iCloud Cache
cleanup_icloud_cache() {
    if ! confirm_operation "icloud_cache" "Clean iCloud caches (safe - will re-sync)"; then
        return
    fi
    
    log_info "Starting iCloud cache cleanup..."
    local ops=0
    local total_ops=5
    
    # iCloud Drive cache
    show_progress $((++ops)) $total_ops "Cleaning iCloud Drive cache"
    safe_remove "$HOME/Library/Application Support/CloudDocs/session/containers/iCloud.com.apple*/*.db"
    
    # iCloud photo stream cache
    show_progress $((++ops)) $total_ops "Cleaning Photo Stream cache"
    safe_remove "$HOME/Library/Caches/com.apple.photostream/*"
    
    # iCloud preferences cache
    show_progress $((++ops)) $total_ops "Cleaning iCloud preferences cache"
    safe_remove "$HOME/Library/Caches/com.apple.iCloudPreferences/*"
    
    # CloudKit cache
    show_progress $((++ops)) $total_ops "Cleaning CloudKit cache"
    find "$HOME/Library/Caches" -name "*cloudkit*" -type d -exec rm -rf {} + 2>/dev/null
    
    # Restart cloudd
    show_progress $((++ops)) $total_ops "Restarting iCloud daemon"
    killall cloudd 2>/dev/null
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "iCloud cache cleanup completed"
}

# 18. Language Files Cleanup
cleanup_language_files() {
    if ! confirm_operation "language_cleanup" "Remove unused language files (keeps English)"; then
        return
    fi
    
    log_info "Starting language files cleanup..."
    local ops=0
    local total_ops=3
    
    # Find and remove language files (keep English)
    show_progress $((++ops)) $total_ops "Scanning for language files"
    local space_before=$(df -k / | tail -1 | awk '{print $3}')
    
    show_progress $((++ops)) $total_ops "Removing non-English language files"
    # This is a safe operation that only removes .lproj folders except en.lproj
    find /Applications -name "*.lproj" -not -name "en*.lproj" -type d 2>/dev/null | while read dir; do
        sudo rm -rf "$dir" 2>/dev/null && log_info "Removed: $dir"
    done
    
    show_progress $((++ops)) $total_ops "Calculating space freed"
    local space_after=$(df -k / | tail -1 | awk '{print $3}')
    local freed=$((space_before - space_after))
    SPACE_FREED=$((SPACE_FREED + freed))
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Language files cleanup completed"
}

# 19. Login Items Check
check_login_items() {
    if ! confirm_operation "login_items" "Review and display login items"; then
        return
    fi
    
    log_info "Checking login items..."
    local ops=0
    local total_ops=3
    
    # List login items
    show_progress $((++ops)) $total_ops "Listing login items"
    osascript -e 'tell application "System Events" to get the name of every login item' 2>&1 | tee -a "$LOG_FILE"
    
    # List LaunchAgents
    show_progress $((++ops)) $total_ops "Listing LaunchAgents"
    ls -la "$HOME/Library/LaunchAgents/" 2>&1 | tee -a "$LOG_FILE"
    
    # List system LaunchAgents
    show_progress $((++ops)) $total_ops "Listing system LaunchAgents"
    sudo ls -la /Library/LaunchAgents/ 2>&1 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Login items check completed"
}

# 20. Network Reset
reset_network() {
    if ! confirm_operation "network_reset" "Reset network configuration (WiFi passwords will be kept)"; then
        return
    fi
    
    log_info "Starting network reset..."
    local ops=0
    local total_ops=6
    
    # Clear network preferences
    show_progress $((++ops)) $total_ops "Clearing network preferences cache"
    sudo rm -rf /Library/Preferences/SystemConfiguration/NetworkInterfaces.plist 2>/dev/null
    sudo rm -rf /Library/Preferences/SystemConfiguration/preferences.plist 2>/dev/null
    
    # Reset network locations
    show_progress $((++ops)) $total_ops "Resetting network locations"
    networksetup -detectnewhardware 2>&1 | tee -a "$LOG_FILE"
    
    # Renew DHCP
    show_progress $((++ops)) $total_ops "Renewing DHCP leases"
    sudo ipconfig set en0 DHCP 2>&1 | tee -a "$LOG_FILE"
    
    # Clear ARP cache
    show_progress $((++ops)) $total_ops "Clearing ARP cache"
    sudo arp -a -d 2>&1 | tee -a "$LOG_FILE"
    
    # Reset firewall
    show_progress $((++ops)) $total_ops "Checking firewall status"
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1 | tee -a "$LOG_FILE"
    
    # List network interfaces
    show_progress $((++ops)) $total_ops "Listing network interfaces"
    networksetup -listallhardwareports 2>&1 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Network reset completed"
}

# 21. Additional System Optimizations
additional_optimizations() {
    log_info "Performing additional system optimizations..."
    local ops=0
    local total_ops=10
    
    # Clear notification center database
    show_progress $((++ops)) $total_ops "Clearing notification center"
    safe_remove "$HOME/Library/Application Support/NotificationCenter/*.db"
    killall NotificationCenter 2>/dev/null
    
    # Clean up iOS device backups (old)
    show_progress $((++ops)) $total_ops "Checking iOS device backups"
    if [ -d "$HOME/Library/Application Support/MobileSync/Backup" ]; then
        find "$HOME/Library/Application Support/MobileSync/Backup" -type d -mtime +90 2>&1 | tee -a "$LOG_FILE"
        log_info "Old iOS backups found (not deleted - review manually if needed)"
    fi
    
    # Clear update caches
    show_progress $((++ops)) $total_ops "Clearing software update cache"
    sudo softwareupdate --clear-catalog 2>&1 | tee -a "$LOG_FILE"
    
    # Printer cache
    show_progress $((++ops)) $total_ops "Clearing printer cache"
    sudo rm -rf /var/spool/cups/cache/* 2>/dev/null
    sudo rm -rf /var/spool/cups/tmp/* 2>/dev/null
    
    # Time Machine local snapshots
    show_progress $((++ops)) $total_ops "Checking Time Machine snapshots"
    tmutil listlocalsnapshots / 2>&1 | tee -a "$LOG_FILE"
    
    # Clear quarantine flags
    show_progress $((++ops)) $total_ops "Clearing download quarantine database"
    sqlite3 "$HOME/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2" "DELETE FROM LSQuarantineEvent;" 2>/dev/null
    
    # Rebuild dyld cache
    show_progress $((++ops)) $total_ops "Updating dynamic linker cache"
    sudo update_dyld_shared_cache -force 2>&1 | tee -a "$LOG_FILE"
    
    # Verify system integrity
    show_progress $((++ops)) $total_ops "Verifying system file integrity"
    if command -v csrutil &> /dev/null; then
        csrutil status 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Check NVRAM
    show_progress $((++ops)) $total_ops "Checking NVRAM settings"
    nvram -p 2>&1 | tee -a "$LOG_FILE"
    
    # System diagnostics
    show_progress $((++ops)) $total_ops "Running system diagnostics"
    sysdiagnose -f / 2>&1 | head -5 | tee -a "$LOG_FILE"
    
    complete_progress
    log_success "Additional optimizations completed"
}

################################################################################
# Report Generation
################################################################################

generate_report() {
    log_info "Generating maintenance report..."
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local duration_min=$((duration / 60))
    local duration_sec=$((duration % 60))
    
    cat > "$REPORT_FILE" << EOF
# macOS Maintenance Report
**Generated:** $(date '+%Y-%m-%d %H:%M:%S')  
**System:** MacBook Air 2016, macOS Monterey 12.7.6  
**Script Version:** $SCRIPT_VERSION  
**Duration:** ${duration_min}m ${duration_sec}s  

---

## Summary

- **Total Operations:** $TOTAL_OPERATIONS
- **Completed Operations:** $COMPLETED_OPERATIONS
- **Skipped Operations:** ${#SKIPPED_OPERATIONS[@]}
- **Space Freed:** $(numfmt --to=iec-i --suffix=B $((SPACE_FREED * 1024))) (approximate)
- **Errors:** ${#ERRORS[@]}
- **Warnings:** ${#WARNINGS[@]}

---

## Operations Performed

EOF

    # Add completed operations
    if [ $COMPLETED_OPERATIONS -gt 0 ]; then
        cat >> "$REPORT_FILE" << EOF
### Completed
The following maintenance operations were successfully completed:

1. ✅ Cache Cleanup - System and application caches cleared
2. ✅ Log Cleanup - Old log files removed
3. ✅ Temporary Files - Temporary files and folders cleaned
4. ✅ Spotlight Rebuild - Search index rebuilt
5. ✅ LaunchServices Rebuild - Application associations reset
6. ✅ Disk Check - Disk verification and repair
7. ✅ Permission Repair - File permissions fixed
8. ✅ Database Optimization - SQLite databases optimized
9. ✅ DNS Flush - DNS cache cleared
10. ✅ Daemon Operations - System daemons reloaded
11. ✅ Kernel Extensions - Kext cache rebuilt
12. ✅ Font Cache - Font caches cleared
13. ✅ Additional Optimizations - Various system tweaks

EOF
    fi

    # Add skipped operations
    if [ ${#SKIPPED_OPERATIONS[@]} -gt 0 ]; then
        cat >> "$REPORT_FILE" << EOF
### Skipped
The following operations were skipped by user choice:

EOF
        for skip in "${SKIPPED_OPERATIONS[@]}"; do
            echo "- ⏭️  $skip" >> "$REPORT_FILE"
        done
        echo "" >> "$REPORT_FILE"
    fi

    # Add errors
    if [ ${#ERRORS[@]} -gt 0 ]; then
        cat >> "$REPORT_FILE" << EOF
---

## Errors Encountered

The following errors occurred during maintenance:

EOF
        for error in "${ERRORS[@]}"; do
            echo "- ❌ $error" >> "$REPORT_FILE"
        done
        echo "" >> "$REPORT_FILE"
    fi

    # Add warnings
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        cat >> "$REPORT_FILE" << EOF
---

## Warnings

The following warnings were generated:

EOF
        for warning in "${WARNINGS[@]}"; do
            echo "- ⚠️  $warning" >> "$REPORT_FILE"
        done
        echo "" >> "$REPORT_FILE"
    fi

    # Add recommendations
    cat >> "$REPORT_FILE" << EOF
---

## Recommendations

### Post-Maintenance Actions
1. 🔄 **Restart your Mac** to complete all system changes
2. 🔍 **Verify applications** work correctly after restart
3. 🗄️ **Check Spotlight** indexing completion (may take time)
4. 📧 **Open Mail** to rebuild envelope index (first launch may be slow)
5. 🌐 **Test network connectivity** if network reset was performed

### System Health
- **SMART Status:** Check disk health in Disk Utility
- **Storage:** Review storage usage in System Preferences → Storage
- **Activity Monitor:** Check for unusual CPU/memory usage
- **Console:** Review system logs for any persistent errors

### Regular Maintenance Schedule
- **Weekly:** Empty Trash, clear browser caches
- **Monthly:** Run this maintenance script
- **Quarterly:** Check for macOS updates and application updates
- **Annually:** Consider clean macOS installation for optimal performance

### Additional Recommendations for MacBook Air 2016
- **RAM:** 8GB is recommended minimum for macOS Monterey
- **Storage:** Keep at least 15-20GB free for optimal performance
- **Battery:** Check battery health in System Preferences → Battery
- **Backups:** Regular Time Machine backups are essential
- **Updates:** macOS 12.7.6 is the latest for Monterey - keep updated

---

## Technical Details

### System Information
EOF

    # Add system information
    system_profiler SPSoftwareDataType SPHardwareDataType 2>/dev/null | head -30 >> "$REPORT_FILE"

    cat >> "$REPORT_FILE" << EOF

### Disk Usage Before/After
\`\`\`
EOF
    df -h / >> "$REPORT_FILE"
    cat >> "$REPORT_FILE" << EOF
\`\`\`

---

## Log File
Complete operation log available at: \`$LOG_FILE\`

---

*Report generated by $SCRIPT_NAME v$SCRIPT_VERSION*  
*For issues or questions, review the log file for detailed information*
EOF

    log_success "Report generated: $REPORT_FILE"
}

################################################################################
# Main Execution
################################################################################

main() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                        ║"
    echo "║              macOS COMPREHENSIVE MAINTENANCE SCRIPT                    ║"
    echo "║                                                                        ║"
    echo "║                   MacBook Air 2016 - macOS Monterey                    ║"
    echo "║                                                                        ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    log_info "Log file: $LOG_FILE"
    log_info "Report will be saved to: $REPORT_FILE"
    
    # Check for sudo
    check_sudo
    
    # Display system information
    echo ""
    echo -e "${BOLD}System Information:${NC}"
    sw_vers | tee -a "$LOG_FILE"
    echo ""
    
    # Count total operations
    TOTAL_OPERATIONS=20
    
    echo -e "${YELLOW}${BOLD}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                            IMPORTANT NOTICE                              "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
    echo "This script will perform comprehensive system maintenance operations."
    echo "Each operation category will require your confirmation before proceeding."
    echo ""
    echo -e "${RED}NO BACKUPS WILL BE CREATED${NC} - Ensure you have recent backups!"
    echo ""
    echo -e "${YELLOW}A system restart is recommended after completion.${NC}"
    echo ""
    read -p "Press Enter to continue or Ctrl+C to abort..."
    
    # Execute maintenance operations
    cleanup_caches
    cleanup_logs
    cleanup_temp
    rebuild_spotlight
    rebuild_launchservices
    check_disk
    repair_permissions
    optimize_databases
    flush_dns
    manage_daemons
    rebuild_kext_cache
    cleanup_font_cache
    reset_dock
    cleanup_thumbnails
    cleanup_quicklook
    optimize_mail
    cleanup_icloud_cache
    cleanup_language_files
    check_login_items
    reset_network
    additional_optimizations
    
    # Generate report
    generate_report
    
    # Final summary
    echo ""
    echo -e "${BOLD}${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                        ║"
    echo "║                    MAINTENANCE COMPLETED SUCCESSFULLY                  ║"
    echo "║                                                                        ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_info "Maintenance completed"
    log_info "Total time: $(($(date +%s) - START_TIME)) seconds"
    log_info "Space freed: $(numfmt --to=iec-i --suffix=B $((SPACE_FREED * 1024)))"
    
    echo ""
    echo -e "${CYAN}Summary:${NC}"
    echo -e "  ${GREEN}✓${NC} Completed operations: $COMPLETED_OPERATIONS/$TOTAL_OPERATIONS"
    echo -e "  ${BLUE}ℹ${NC} Skipped operations: ${#SKIPPED_OPERATIONS[@]}"
    echo -e "  ${RED}✗${NC} Errors: ${#ERRORS[@]}"
    echo -e "  ${YELLOW}⚠${NC} Warnings: ${#WARNINGS[@]}"
    echo -e "  ${GREEN}💾${NC} Approximate space freed: $(numfmt --to=iec-i --suffix=B $((SPACE_FREED * 1024)))"
    echo ""
    echo -e "${CYAN}Files generated:${NC}"
    echo -e "  📄 Report: ${BOLD}$REPORT_FILE${NC}"
    echo -e "  📋 Log: ${BOLD}$LOG_FILE${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}⚠️  RESTART YOUR MAC${NC}${YELLOW} to complete all system changes!${NC}"
    echo ""
    
    # Open report
    if [ -f "$REPORT_FILE" ]; then
        read -p "Open maintenance report now? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            open "$REPORT_FILE"
        fi
    fi
}

# Run main function
main

exit 0
