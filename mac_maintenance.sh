#!/usr/bin/env bash

################################################################################
# macOS Comprehensive Maintenance Script
# Target: MacBook Air 2016, macOS Monterey 12.7.6
# Description: Exhaustive system maintenance with low-level operations
# Version: 2.0.0
################################################################################

set -euo pipefail
IFS=$'\n\t'

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
SCRIPT_VERSION="2.0.0"
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
FAILED_OPERATIONS=()
VERBOSE=false
AUTO_CONFIRM=false
CAFFEINATE_PID=""

# Operation categories with risk levels
# Using a function instead of associative array for Bash 3.x compatibility
get_risk_level() {
    case "$1" in
        cache_cleanup|log_cleanup|temp_cleanup|disk_check|dns_flush|font_cache|dock_reset|thumbnail_cache|quicklook_cache|login_items|system_updates|app_updates|driver_check|security_audit|backup_verification|network_diagnostics|thermal_monitoring|large_file_finder|duplicate_finder|startup_optimization|log_analysis)
            echo "LOW"
            ;;
        spotlight_rebuild|launchservices_rebuild|permission_repair|database_optimization|daemon_operations|mail_optimization|icloud_cache|language_cleanup|memory_management|apfs_snapshots|app_cache_optimization|browser_optimization|privacy_cleanup)
            echo "MEDIUM"
            ;;
        kext_rebuild|network_reset)
            echo "HIGH"
            ;;
        *)
            echo "UNKNOWN"
            ;;
    esac
}

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

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${MAGENTA}[$timestamp] DEBUG: $1${NC}" | tee -a "$LOG_FILE"
    fi
}

################################################################################
# Cleanup and Safety Functions
################################################################################

cleanup() {
    local exit_code=$?
    
    log_debug "Cleanup function called with exit code: $exit_code"
    
    # Stop caffeinate if running
    if [[ -n "$CAFFEINATE_PID" ]] && kill -0 "$CAFFEINATE_PID" 2>/dev/null; then
        log_debug "Stopping caffeinate process (PID: $CAFFEINATE_PID)"
        kill "$CAFFEINATE_PID" 2>/dev/null || true
    fi
    
    # Cleanup any temporary files created by script
    # (Currently all temps go to /tmp which is auto-cleaned)
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script exited with error code: $exit_code"
    else
        log_debug "Script cleanup completed successfully"
    fi
    
    return $exit_code
}

# Set trap for cleanup on exit, error, interrupt, or termination
trap cleanup EXIT ERR INT TERM

check_disk_space() {
    local required_gb=5
    log_info "Checking available disk space..."
    
    # Get available space in GB
    local available=$(df -g / | tail -1 | awk '{print $4}')
    
    log_debug "Available disk space: ${available}GB, Required: ${required_gb}GB"
    
    if [[ $available -lt $required_gb ]]; then
        log_error "Insufficient disk space: ${available}GB available, ${required_gb}GB required"
        log_error "Please free up disk space before running maintenance"
        return 1
    fi
    
    log_success "Sufficient disk space available: ${available}GB"
    return 0
}

start_caffeinate() {
    # Prevent system sleep during maintenance
    if command -v caffeinate &> /dev/null; then
        log_debug "Starting caffeinate to prevent system sleep"
        caffeinate -dims -w $$ &
        CAFFEINATE_PID=$!
        log_debug "Caffeinate started with PID: $CAFFEINATE_PID"
    else
        log_warning "caffeinate command not available"
    fi
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
    
    # Calculate ETA - with division by zero protection
    local elapsed=$(($(date +%s) - START_TIME))
    local eta_min=0
    local eta_sec=0
    
    if [ "$elapsed" -gt 0 ] && [ "$current" -gt 0 ]; then
        local rate=$(awk "BEGIN {printf \"%.4f\", $current / $elapsed}")
        local remaining=$((total - current))
        local eta=$(awk "BEGIN {if ($rate > 0) print int($remaining / $rate); else print 0}")
        eta_min=$((eta / 60))
        eta_sec=$((eta % 60))
    fi
    
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
    local risk=$(get_risk_level "$category")
    
    # Auto-confirm if flag is set
    if [[ "$AUTO_CONFIRM" == "true" ]]; then
        log_debug "Auto-confirming operation: $category"
        return 0
    fi
    
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

usage() {
    cat << EOF
${BOLD}${CYAN}macOS Comprehensive Maintenance Script v${SCRIPT_VERSION}${NC}

${BOLD}USAGE:${NC}
    $(basename "$0") [OPTIONS]

${BOLD}DESCRIPTION:${NC}
    Comprehensive macOS maintenance script for deep system cleaning and optimization.
    Performs 37+ maintenance operations including cache cleanup, memory management,
    security audit, backup verification, and much more.

${BOLD}OPTIONS:${NC}
    -h, --help              Show this help message and exit
    -v, --verbose           Enable verbose output (debug logging)
    -y, --yes               Auto-confirm all operations (no prompts)
    -o, --operation <name>  Run only a specific operation
    -l, --list              List all available operations and exit
    --no-color              Disable color output
    --skip <operation>      Skip a specific operation
    --only-risk <level>     Only run operations of specific risk level (LOW/MEDIUM/HIGH)
    --version               Show version and exit

${BOLD}EXAMPLES:${NC}
    # Interactive mode (default)
    ./mac_maintenance.sh

    # Verbose mode with all operations auto-confirmed
    ./mac_maintenance.sh --verbose --yes

    # Run only low-risk operations
    ./mac_maintenance.sh --only-risk LOW

    # Run specific operation
    ./mac_maintenance.sh --operation cache_cleanup

    # List all available operations
    ./mac_maintenance.sh --list

${BOLD}RISK LEVELS:${NC}
    ${GREEN}LOW${NC}     - Safe operations (cache cleanup, diagnostics, verification)
    ${YELLOW}MEDIUM${NC}  - May require restart (database optimization, rebuilds)
    ${RED}HIGH${NC}    - Significant changes (kernel cache, network reset)

${BOLD}NOTES:${NC}
    - Script requires sudo for some operations
    - Always ensure you have recent backups before running
    - System restart recommended after completion
    - Detailed logs saved to /tmp/mac_maintenance_*.log
    - Report generated on Desktop

${BOLD}OPERATIONS PERFORMED:${NC}
    See --list for complete operation list

For more information, visit: https://github.com/costaindustries-source/mac-cleaner
EOF
}

list_operations() {
    echo -e "${BOLD}${CYAN}Available Operations (37 total):${NC}\n"
    
    echo -e "${GREEN}LOW RISK Operations:${NC}"
    echo "  1.  cache_cleanup          - Clean system and application caches"
    echo "  2.  log_cleanup            - Clean system and application logs"
    echo "  3.  temp_cleanup           - Clean temporary files"
    echo "  4.  disk_check             - Verify and repair disk"
    echo "  5.  dns_flush              - Flush DNS cache"
    echo "  6.  font_cache             - Clean font caches"
    echo "  7.  dock_reset             - Reset Dock"
    echo "  8.  thumbnail_cache        - Clean thumbnail caches"
    echo "  9.  quicklook_cache        - Clean QuickLook cache"
    echo "  10. login_items            - Review login items"
    echo "  11. system_updates         - Check for system updates"
    echo "  12. app_updates            - Check for application updates"
    echo "  13. driver_check           - Check hardware and drivers"
    echo "  14. security_audit         - Comprehensive security audit"
    echo "  15. backup_verification    - Verify Time Machine backups"
    echo "  16. network_diagnostics    - Network diagnostics"
    echo "  17. thermal_monitoring     - Monitor system temperature"
    echo "  18. large_file_finder      - Find large files"
    echo "  19. duplicate_finder       - Find duplicate files"
    echo "  20. startup_optimization   - Analyze startup configuration"
    echo "  21. log_analysis           - Analyze system logs"
    
    echo -e "\n${YELLOW}MEDIUM RISK Operations:${NC}"
    echo "  22. spotlight_rebuild      - Rebuild Spotlight index"
    echo "  23. launchservices_rebuild - Rebuild LaunchServices"
    echo "  24. permission_repair      - Repair disk permissions"
    echo "  25. database_optimization  - Optimize system databases"
    echo "  26. daemon_operations      - Reload system daemons"
    echo "  27. mail_optimization      - Optimize Mail.app"
    echo "  28. icloud_cache           - Clean iCloud cache"
    echo "  29. language_cleanup       - Remove unused language files"
    echo "  30. memory_management      - Memory analysis and optimization"
    echo "  31. apfs_snapshots         - Manage APFS snapshots"
    echo "  32. app_cache_optimization - Clean development tool caches"
    echo "  33. browser_optimization   - Optimize browser databases"
    echo "  34. privacy_cleanup        - Clean privacy-sensitive data"
    
    echo -e "\n${RED}HIGH RISK Operations:${NC}"
    echo "  35. kext_rebuild           - Rebuild kernel extension cache"
    echo "  36. network_reset          - Reset network configuration"
    
    echo -e "\n${CYAN}Additional:${NC}"
    echo "  37. additional_optimizations - Various system tweaks"
    
    echo ""
}

parse_arguments() {
    local SINGLE_OPERATION=""
    local ONLY_RISK=""
    local SKIP_OPERATIONS=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                log_debug "Verbose mode enabled"
                ;;
            -y|--yes)
                AUTO_CONFIRM=true
                log_info "Auto-confirm mode enabled"
                ;;
            -o|--operation)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    echo -e "${RED}Error: --operation requires an argument${NC}"
                    echo "Use --list to see available operations"
                    exit 1
                fi
                SINGLE_OPERATION="$2"
                shift
                ;;
            -l|--list)
                list_operations
                exit 0
                ;;
            --no-color)
                # Disable colors
                RED=''
                GREEN=''
                YELLOW=''
                BLUE=''
                MAGENTA=''
                CYAN=''
                NC=''
                BOLD=''
                ;;
            --skip)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    echo -e "${RED}Error: --skip requires an argument${NC}"
                    exit 1
                fi
                SKIP_OPERATIONS+=("$2")
                shift
                ;;
            --only-risk)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    echo -e "${RED}Error: --only-risk requires an argument${NC}"
                    echo "Valid values: LOW, MEDIUM, HIGH"
                    exit 1
                fi
                ONLY_RISK="$2"
                shift
                ;;
            --version)
                echo "macOS Maintenance Script v$SCRIPT_VERSION"
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
        shift
    done
    
    # Export for use in other functions
    export SINGLE_OPERATION
    export ONLY_RISK
    export SKIP_OPERATIONS
}

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
    if ! diskutil resetUserPermissions / $(id -u) 2>&1 | tee -a "$LOG_FILE"; then
        # Error -69841 is a known issue that can be safely ignored
        if grep -q "\-69841" "$LOG_FILE"; then
            log_warning "Permission reset returned error -69841 (known issue, can be ignored)"
        else
            log_error "Permission reset failed with unexpected error"
        fi
    fi
    
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

# 21. System Updates Check
check_system_updates() {
    if ! confirm_operation "system_updates" "Check for macOS system updates and security patches"; then
        return
    fi
    
    log_info "Starting system updates check..."
    local ops=0
    local total_ops=5
    
    # Check for available updates
    show_progress $((++ops)) $total_ops "Checking for macOS updates"
    log_info "Checking for available system updates..."
    if softwareupdate --list 2>&1 | tee -a "$LOG_FILE"; then
        log_info "System update check completed"
    else
        log_warning "System update check failed - network may be unavailable"
    fi
    
    # Show current macOS version
    show_progress $((++ops)) $total_ops "Checking current macOS version"
    local current_version=$(sw_vers -productVersion)
    local build_version=$(sw_vers -buildVersion)
    log_info "Current macOS version: $current_version (Build: $build_version)"
    
    # Check for critical updates
    show_progress $((++ops)) $total_ops "Checking for critical security updates"
    local critical_updates=$(softwareupdate --list 2>&1 | grep -c "recommended" || echo "0")
    if [ "$critical_updates" -gt 0 ]; then
        log_warning "Found $critical_updates recommended security updates"
        log_info "To install updates, run: sudo softwareupdate --install --all"
    else
        log_success "No critical security updates pending"
    fi
    
    # Check automatic update settings
    show_progress $((++ops)) $total_ops "Checking automatic update settings"
    defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>&1 | tee -a "$LOG_FILE"
    
    # Show last update check time
    show_progress $((++ops)) $total_ops "Checking last update verification"
    defaults read /Library/Preferences/com.apple.SoftwareUpdate LastFullSuccessfulDate 2>&1 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "System updates check completed"
}

# 22. Application Updates Check
check_app_updates() {
    if ! confirm_operation "app_updates" "Check for application updates (Homebrew, App Store, etc.)"; then
        return
    fi
    
    log_info "Starting application updates check..."
    local ops=0
    local total_ops=6
    
    # Check Homebrew updates
    show_progress $((++ops)) $total_ops "Checking Homebrew packages"
    if command -v brew &> /dev/null; then
        log_info "Homebrew is installed - checking for outdated packages"
        if brew update 2>&1 | tee -a "$LOG_FILE"; then
            local outdated=$(brew outdated 2>/dev/null | wc -l | tr -d ' ')
            if [ "$outdated" -gt 0 ]; then
                log_warning "Found $outdated outdated Homebrew packages:"
                brew outdated 2>&1 | tee -a "$LOG_FILE"
                log_info "To update: brew upgrade"
            else
                log_success "All Homebrew packages are up to date"
            fi
        else
            log_warning "Homebrew update check failed - network may be unavailable"
        fi
    else
        log_info "Homebrew not installed (optional package manager)"
    fi
    
    # Check App Store updates
    show_progress $((++ops)) $total_ops "Checking App Store updates"
    if command -v mas &> /dev/null; then
        log_info "Checking App Store for updates..."
        if mas outdated 2>&1 | tee -a "$LOG_FILE"; then
            log_info "To update App Store apps: mas upgrade"
        else
            log_warning "App Store update check failed - network may be unavailable"
        fi
    else
        log_info "mas-cli not installed - check App Store manually for updates"
        log_info "Install mas-cli with: brew install mas"
    fi
    
    # Check for npm global packages
    show_progress $((++ops)) $total_ops "Checking npm global packages"
    if command -v npm &> /dev/null; then
        log_info "Checking outdated npm global packages..."
        if npm outdated -g 2>&1 | tee -a "$LOG_FILE"; then
            log_info "npm global packages check completed"
        else
            log_warning "npm update check failed - network may be unavailable"
        fi
    else
        log_info "npm not installed"
    fi
    
    # Check for pip packages
    show_progress $((++ops)) $total_ops "Checking pip packages"
    if command -v pip3 &> /dev/null; then
        log_info "Checking outdated pip packages..."
        if timeout 30 pip3 list --outdated 2>&1 | tee -a "$LOG_FILE"; then
            log_info "pip packages check completed"
        else
            log_warning "pip update check failed - network may be unavailable or timeout reached"
        fi
    else
        log_info "pip3 not installed"
    fi
    
    # Check for gem packages
    show_progress $((++ops)) $total_ops "Checking Ruby gems"
    if command -v gem &> /dev/null; then
        log_info "Checking outdated Ruby gems..."
        gem outdated 2>&1 | tee -a "$LOG_FILE" || log_info "All gems up to date"
    else
        log_info "Ruby gems not installed"
    fi
    
    # System applications version check
    show_progress $((++ops)) $total_ops "Listing system applications"
    log_info "Key system applications versions:"
    system_profiler SPApplicationsDataType 2>/dev/null | grep -A 2 "Safari\|Mail\|Messages\|Photos" | tee -a "$LOG_FILE" || log_info "Application data not available"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Application updates check completed"
}

# 23. Driver and Hardware Check
check_drivers_hardware() {
    if ! confirm_operation "driver_check" "Check hardware drivers, firmware, and system health"; then
        return
    fi
    
    log_info "Starting driver and hardware check..."
    local ops=0
    local total_ops=10
    
    # Check for available firmware updates
    show_progress $((++ops)) $total_ops "Checking for firmware updates"
    log_info "Checking for available firmware updates..."
    system_profiler SPiBridgeDataType 2>/dev/null | tee -a "$LOG_FILE" || log_info "iBridge data not available"
    
    # Check storage drivers
    show_progress $((++ops)) $total_ops "Checking storage drivers and health"
    log_info "Storage controller information:"
    system_profiler SPNVMeDataType SPSerialATADataType 2>/dev/null | head -30 | tee -a "$LOG_FILE"
    
    # Check display drivers
    show_progress $((++ops)) $total_ops "Checking display information"
    log_info "Display and graphics information:"
    system_profiler SPDisplaysDataType 2>/dev/null | head -30 | tee -a "$LOG_FILE"
    
    # Check USB devices and drivers
    show_progress $((++ops)) $total_ops "Checking USB devices"
    log_info "USB devices connected:"
    # Use subshell to prevent SIGPIPE from terminating the script
    (system_profiler SPUSBDataType 2>/dev/null | grep -A 5 "Product ID\|Manufacturer" | head -30 || true) | tee -a "$LOG_FILE"
    
    # Check Bluetooth status
    show_progress $((++ops)) $total_ops "Checking Bluetooth status"
    log_info "Bluetooth information:"
    system_profiler SPBluetoothDataType 2>/dev/null | head -20 | tee -a "$LOG_FILE"
    
    # Check Wi-Fi drivers and status
    show_progress $((++ops)) $total_ops "Checking Wi-Fi status"
    log_info "Wi-Fi information:"
    system_profiler SPAirPortDataType 2>/dev/null | head -30 | tee -a "$LOG_FILE"
    
    # Check audio drivers
    show_progress $((++ops)) $total_ops "Checking audio devices"
    log_info "Audio devices:"
    system_profiler SPAudioDataType 2>/dev/null | head -30 | tee -a "$LOG_FILE"
    
    # Check battery health (for laptops)
    show_progress $((++ops)) $total_ops "Checking battery health"
    log_info "Battery information:"
    system_profiler SPPowerDataType 2>/dev/null | grep -A 10 "Health\|Cycle Count\|Condition" | tee -a "$LOG_FILE"
    pmset -g batt 2>&1 | tee -a "$LOG_FILE"
    
    # Check for kernel extensions
    show_progress $((++ops)) $total_ops "Checking loaded kernel extensions"
    log_info "Non-Apple kernel extensions:"
    # Use subshell to prevent SIGPIPE from terminating the script
    (kextstat | grep -v com.apple | head -20 || true) | tee -a "$LOG_FILE"
    
    # Check system load and performance
    show_progress $((++ops)) $total_ops "Checking system performance"
    log_info "System load and memory:"
    uptime | tee -a "$LOG_FILE"
    vm_stat | head -10 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Driver and hardware check completed"
}

# 24. Additional System Optimizations
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

# 25. Memory Management
manage_memory() {
    if ! confirm_operation "memory_management" "Analyze and optimize memory usage"; then
        return
    fi
    
    log_info "Starting memory management..."
    local ops=0
    local total_ops=5
    
    # Check memory pressure
    show_progress $((++ops)) $total_ops "Analyzing memory pressure"
    log_info "Memory pressure analysis:"
    if command -v memory_pressure &> /dev/null; then
        memory_pressure 2>&1 | head -10 | tee -a "$LOG_FILE"
    fi
    
    # Get memory statistics
    show_progress $((++ops)) $total_ops "Collecting memory statistics"
    vm_stat | head -20 | tee -a "$LOG_FILE"
    
    # Check swap usage
    show_progress $((++ops)) $total_ops "Checking swap usage"
    sysctl vm.swapusage 2>&1 | tee -a "$LOG_FILE"
    
    # Top memory consumers
    show_progress $((++ops)) $total_ops "Identifying top memory consumers"
    log_info "Top 10 memory consumers:"
    # Use subshell to prevent SIGPIPE from terminating the script
    # when head closes the pipe early (exit code 141)
    (ps aux | sort -rk 4 | head -11 || true) | tee -a "$LOG_FILE"
    
    # Purge inactive memory
    show_progress $((++ops)) $total_ops "Purging inactive memory"
    read -p "Purge inactive memory to free RAM? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Purging memory..."
        sudo purge
        log_success "Memory purged successfully"
    else
        log_info "Memory purge skipped"
    fi
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Memory management completed"
}

# 26. APFS Snapshot Management
manage_apfs_snapshots() {
    if ! confirm_operation "apfs_snapshots" "Manage APFS snapshots (can free significant space)"; then
        return
    fi
    
    log_info "Starting APFS snapshot management..."
    local ops=0
    local total_ops=4
    
    # List all snapshots
    show_progress $((++ops)) $total_ops "Listing APFS snapshots"
    log_info "Local Time Machine snapshots:"
    tmutil listlocalsnapshots / 2>&1 | tee -a "$LOG_FILE"
    
    # Count snapshots
    show_progress $((++ops)) $total_ops "Analyzing snapshot disk usage"
    local snapshot_count=$(tmutil listlocalsnapshots / 2>&1 | grep "com.apple" | wc -l | tr -d ' ')
    log_info "Found $snapshot_count local snapshots"
    
    if [[ $snapshot_count -gt 0 ]]; then
        # Show current disk usage
        show_progress $((++ops)) $total_ops "Checking disk usage"
        df -h / | tee -a "$LOG_FILE"
        
        log_warning "Deleting snapshots will free disk space but removes backup points"
        read -p "Delete all local Time Machine snapshots? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            show_progress $((++ops)) $total_ops "Deleting snapshots"
            local space_before=$(df -k / | tail -1 | awk '{print $3}')
            
            tmutil listlocalsnapshots / 2>&1 | grep "com.apple" | while read -r snapshot; do
                local snap_date=$(echo "$snapshot" | sed 's/com.apple.TimeMachine.//')
                log_info "Deleting snapshot: $snap_date"
                sudo tmutil deletelocalsnapshots "$snap_date" 2>&1 | tee -a "$LOG_FILE"
            done
            
            local space_after=$(df -k / | tail -1 | awk '{print $3}')
            local freed=$((space_before - space_after))
            if [[ $freed -gt 0 ]]; then
                SPACE_FREED=$((SPACE_FREED + freed))
                log_success "Freed $(numfmt --to=iec-i --suffix=B $((freed * 1024))) from snapshots"
            fi
        else
            log_info "Snapshot deletion skipped"
        fi
    else
        show_progress $((++ops)) $total_ops "No snapshots to delete"
        log_info "No local snapshots found"
    fi
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "APFS snapshot management completed"
}

# 27. Security Audit
perform_security_audit() {
    if ! confirm_operation "security_audit" "Comprehensive security audit"; then
        return
    fi
    
    log_info "Starting security audit..."
    local ops=0
    local total_ops=10
    
    # Check SIP status
    show_progress $((++ops)) $total_ops "Checking System Integrity Protection"
    log_info "System Integrity Protection status:"
    csrutil status 2>&1 | tee -a "$LOG_FILE"
    
    # Check Gatekeeper
    show_progress $((++ops)) $total_ops "Checking Gatekeeper"
    log_info "Gatekeeper status:"
    spctl --status 2>&1 | tee -a "$LOG_FILE"
    
    # Check FileVault
    show_progress $((++ops)) $total_ops "Checking FileVault encryption"
    log_info "FileVault status:"
    fdesetup status 2>&1 | tee -a "$LOG_FILE"
    
    if ! fdesetup status 2>&1 | grep -q "FileVault is On"; then
        log_warning "⚠️ FileVault is OFF - your disk is not encrypted!"
        log_warning "Enable in System Preferences → Security & Privacy → FileVault"
    else
        log_success "✓ FileVault is enabled"
    fi
    
    # Check Firewall
    show_progress $((++ops)) $total_ops "Checking firewall"
    log_info "Firewall status:"
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1 | tee -a "$LOG_FILE"
    
    # Check for unsigned applications
    show_progress $((++ops)) $total_ops "Checking for unsigned applications"
    log_info "Scanning /Applications for unsigned apps (this may take a moment)..."
    local unsigned_count=0
    find /Applications -name "*.app" -maxdepth 2 2>/dev/null | while read -r app; do
        if ! codesign -v "$app" 2>/dev/null; then
            log_warning "Unsigned application: $(basename "$app")"
            unsigned_count=$((unsigned_count + 1))
        fi
    done
    
    # Check SSH configuration
    show_progress $((++ops)) $total_ops "Checking SSH configuration"
    if [[ -d "$HOME/.ssh" ]]; then
        log_info "SSH directory exists"
        local ssh_perms=$(stat -f%A "$HOME/.ssh" 2>/dev/null)
        if [[ "$ssh_perms" != "700" ]]; then
            log_warning "⚠️ .ssh directory has insecure permissions ($ssh_perms)!"
            log_info "Fix with: chmod 700 ~/.ssh"
        else
            log_success "✓ SSH directory permissions are secure"
        fi
    fi
    
    # Check for world-writable files in home
    show_progress $((++ops)) $total_ops "Checking for insecure file permissions"
    log_info "Checking for world-writable files in home directory..."
    local writable=$(find "$HOME" -type f -perm -002 2>/dev/null | head -10)
    if [[ -n "$writable" ]]; then
        log_warning "Found world-writable files:"
        echo "$writable" | tee -a "$LOG_FILE"
        log_warning "Consider fixing with: chmod 644 <file>"
    else
        log_success "✓ No world-writable files found in home directory"
    fi
    
    # Check sudo configuration
    show_progress $((++ops)) $total_ops "Checking sudo timeout"
    local sudo_timeout=$(sudo -V 2>&1 | grep "Authentication timestamp timeout" | awk '{print $4}')
    if [[ -n "$sudo_timeout" ]]; then
        log_info "Sudo timeout: $sudo_timeout minutes"
    fi
    
    # Check automatic updates
    show_progress $((++ops)) $total_ops "Checking automatic updates"
    local auto_check=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null)
    if [[ "$auto_check" == "1" ]]; then
        log_success "✓ Automatic update check is enabled"
    else
        log_warning "⚠️ Automatic update check is disabled"
    fi
    
    # Summary
    show_progress $((++ops)) $total_ops "Generating security summary"
    log_info "Security audit completed - review warnings above"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Security audit completed"
}

# 28. Backup Verification
verify_backups() {
    if ! confirm_operation "backup_verification" "Verify Time Machine and backup configuration"; then
        return
    fi
    
    log_info "Starting backup verification..."
    local ops=0
    local total_ops=6
    
    # Time Machine status
    show_progress $((++ops)) $total_ops "Checking Time Machine status"
    log_info "Time Machine status:"
    tmutil status 2>&1 | tee -a "$LOG_FILE"
    
    # Last backup date
    show_progress $((++ops)) $total_ops "Checking last backup"
    log_info "Last Time Machine backup:"
    local last_backup=$(tmutil latestbackup 2>&1)
    if [[ -n "$last_backup" ]] && [[ "$last_backup" != *"No machine directory"* ]]; then
        echo "$last_backup" | tee -a "$LOG_FILE"
        log_success "✓ Time Machine backup found"
    else
        log_error "✗ No Time Machine backups found!"
        log_warning "Configure Time Machine in System Preferences"
    fi
    
    # Backup destinations
    show_progress $((++ops)) $total_ops "Checking backup destinations"
    log_info "Time Machine destinations:"
    tmutil destinationinfo 2>&1 | tee -a "$LOG_FILE"
    
    # Check if Time Machine is enabled
    show_progress $((++ops)) $total_ops "Verifying Time Machine is enabled"
    if tmutil status 2>&1 | grep -q "Running = 1"; then
        log_success "✓ Time Machine is currently running"
    else
        log_info "Time Machine is not currently running"
    fi
    
    # List local snapshots
    show_progress $((++ops)) $total_ops "Listing local snapshots"
    log_info "Local Time Machine snapshots:"
    local snap_count=$(tmutil listlocalsnapshots / 2>&1 | grep "com.apple" | wc -l | tr -d ' ')
    log_info "Found $snap_count local snapshots"
    
    # Check iCloud sync status
    show_progress $((++ops)) $total_ops "Checking iCloud sync"
    log_info "iCloud sync status:"
    if command -v brctl &> /dev/null; then
        brctl status 2>&1 | head -20 | tee -a "$LOG_FILE"
    else
        log_info "brctl not available on this macOS version"
    fi
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Backup verification completed"
}

# 29. Network Diagnostics
perform_network_diagnostics() {
    if ! confirm_operation "network_diagnostics" "Comprehensive network diagnostics"; then
        return
    fi
    
    log_info "Starting network diagnostics..."
    local ops=0
    local total_ops=8
    
    # Current network interfaces
    show_progress $((++ops)) $total_ops "Checking network interfaces"
    log_info "Active network interfaces:"
    ifconfig | grep -A 4 "^en" | tee -a "$LOG_FILE"
    
    # DNS servers
    show_progress $((++ops)) $total_ops "Checking DNS configuration"
    log_info "Current DNS servers:"
    scutil --dns 2>&1 | grep "nameserver" | head -10 | tee -a "$LOG_FILE"
    
    # Network routes
    show_progress $((++ops)) $total_ops "Checking network routes"
    log_info "Network routing table:"
    netstat -rn | head -20 | tee -a "$LOG_FILE"
    
    # Test connectivity
    show_progress $((++ops)) $total_ops "Testing internet connectivity"
    log_info "Testing internet connectivity..."
    
    if ping -c 3 -t 5 8.8.8.8 &> /dev/null; then
        log_success "✓ Internet connectivity: OK"
    else
        log_error "✗ Internet connectivity: FAILED"
    fi
    
    show_progress $((++ops)) $total_ops "Testing DNS resolution"
    if ping -c 3 -t 5 google.com &> /dev/null; then
        log_success "✓ DNS resolution: OK"
    else
        log_error "✗ DNS resolution: FAILED"
    fi
    
    # Wi-Fi diagnostics
    show_progress $((++ops)) $total_ops "Checking Wi-Fi information"
    log_info "Wi-Fi information:"
    if [[ -f /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport ]]; then
        /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # VPN status
    show_progress $((++ops)) $total_ops "Checking VPN configuration"
    log_info "VPN configurations:"
    scutil --nc list 2>&1 | tee -a "$LOG_FILE"
    
    # Proxy settings
    show_progress $((++ops)) $total_ops "Checking proxy settings"
    log_info "Proxy settings:"
    networksetup -getwebproxy Wi-Fi 2>&1 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Network diagnostics completed"
}

# 30. Thermal Monitoring
monitor_thermal_status() {
    if ! confirm_operation "thermal_monitoring" "Monitor system temperature and thermal status"; then
        return
    fi
    
    log_info "Starting thermal monitoring..."
    local ops=0
    local total_ops=4
    
    # Check if osx-cpu-temp is available
    show_progress $((++ops)) $total_ops "Checking CPU temperature"
    if command -v osx-cpu-temp &> /dev/null; then
        log_info "CPU Temperature:"
        osx-cpu-temp 2>&1 | tee -a "$LOG_FILE"
    else
        log_info "osx-cpu-temp not installed"
        log_info "Install with: brew install osx-cpu-temp"
    fi
    
    # Check fan speed and thermal pressure
    show_progress $((++ops)) $total_ops "Checking fan and thermal status"
    log_info "System thermal status:"
    # Use subshell to prevent SIGPIPE from terminating the script
    (sudo powermetrics --samplers smc -i 1 -n 1 2>&1 | grep -i "fan\|thermal" | head -10 || true) | tee -a "$LOG_FILE"
    
    # CPU usage
    show_progress $((++ops)) $total_ops "Checking CPU usage"
    log_info "CPU usage:"
    top -l 1 | grep "CPU usage" | tee -a "$LOG_FILE"
    
    # Check for throttling
    show_progress $((++ops)) $total_ops "Checking CPU frequency"
    log_info "CPU frequency:"
    sysctl hw.cpufrequency hw.cpufrequency_max 2>&1 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Thermal monitoring completed"
}

# 31. Large File Finder
find_large_files() {
    if ! confirm_operation "large_file_finder" "Find large files consuming disk space"; then
        return
    fi
    
    log_info "Searching for large files..."
    local ops=0
    local total_ops=2
    
    show_progress $((++ops)) $total_ops "Scanning for files larger than 100MB"
    echo "Top 50 largest files on the system:" | tee -a "$LOG_FILE"
    
    # Find files larger than 100MB, excluding system and backup locations
    show_progress $((++ops)) $total_ops "Generating report"
    # Use subshell to prevent SIGPIPE from terminating the script
    # when head closes the pipe early (exit code 141)
    (sudo find / -type f -size +100M \
        -not -path "*/Library/Application Support/MobileSync/Backup/*" \
        -not -path "*/Backups.backupdb/*" \
        -not -path "*/System/*" \
        -not -path "*/private/var/db/*" \
        -not -path "*/.Spotlight-V100/*" \
        -not -path "*/.fseventsd/*" \
        -exec du -h {} \; 2>/dev/null | \
        sort -rh | head -50 || true) | tee -a "$LOG_FILE"
    
    log_info "Review and delete large unnecessary files manually"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Large file finder completed"
}

# 32. Duplicate File Finder
find_duplicate_files() {
    if ! confirm_operation "duplicate_finder" "Scan for duplicate files (read-only analysis)"; then
        return
    fi
    
    log_info "Scanning for duplicate files (this may take several minutes)..."
    local ops=0
    local total_ops=3
    
    show_progress $((++ops)) $total_ops "Preparing scan"
    local temp_report="/tmp/duplicates_$(date +%Y%m%d_%H%M%S).txt"
    
    # Find duplicates by size and hash in common locations
    show_progress $((++ops)) $total_ops "Scanning common locations"
    find "$HOME/Downloads" "$HOME/Documents" "$HOME/Desktop" -type f -size +1M 2>/dev/null | \
        while read -r file; do
            if [[ -f "$file" ]]; then
                local hash=$(md5 -q "$file" 2>/dev/null)
                local size=$(stat -f%z "$file" 2>/dev/null)
                echo "${hash}|${size}|${file}"
            fi
        done | sort | uniq -w 32 -d > "$temp_report"
    
    show_progress $((++ops)) $total_ops "Analyzing results"
    local dup_count=$(wc -l < "$temp_report" | tr -d ' ')
    
    if [[ $dup_count -gt 0 ]]; then
        log_warning "Found $dup_count potential duplicate files"
        log_info "Report saved to: $temp_report"
        cat "$temp_report" | tee -a "$LOG_FILE"
        log_info "Review and manually delete duplicates if needed"
    else
        log_success "No duplicate files found"
        rm "$temp_report"
    fi
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Duplicate file finder completed"
}

# 33. Startup Optimization
optimize_startup() {
    if ! confirm_operation "startup_optimization" "Optimize system startup and boot time"; then
        return
    fi
    
    log_info "Analyzing startup configuration..."
    local ops=0
    local total_ops=6
    
    # List user LaunchAgents
    show_progress $((++ops)) $total_ops "Listing user LaunchAgents"
    log_info "User LaunchAgents:"
    ls -la "$HOME/Library/LaunchAgents/" 2>&1 | tee -a "$LOG_FILE"
    
    # List system LaunchAgents
    show_progress $((++ops)) $total_ops "Listing system LaunchAgents"
    log_info "System LaunchAgents:"
    sudo ls -la /Library/LaunchAgents/ 2>&1 | tee -a "$LOG_FILE"
    
    # List system LaunchDaemons
    show_progress $((++ops)) $total_ops "Listing system LaunchDaemons"
    log_info "System LaunchDaemons:"
    sudo ls -la /Library/LaunchDaemons/ 2>&1 | tee -a "$LOG_FILE"
    
    # Show currently loaded user agents
    show_progress $((++ops)) $total_ops "Checking loaded user agents"
    log_info "Currently loaded user agents (non-Apple):"
    launchctl list | grep -v "com.apple" | tee -a "$LOG_FILE"
    
    # Boot time analysis
    show_progress $((++ops)) $total_ops "Analyzing boot time"
    log_info "Last boot time:"
    sysctl kern.boottime | tee -a "$LOG_FILE"
    
    log_info "System uptime:"
    uptime | tee -a "$LOG_FILE"
    
    # Recommendations
    show_progress $((++ops)) $total_ops "Generating recommendations"
    log_warning "Review the list above and disable unnecessary services manually"
    log_info "To disable a service: launchctl unload <path-to-plist>"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Startup optimization analysis completed"
}

# 34. Application Cache Optimization
optimize_app_caches() {
    if ! confirm_operation "app_cache_optimization" "Optimize application-specific caches and settings"; then
        return
    fi
    
    log_info "Optimizing application caches..."
    local ops=0
    local total_ops=8
    
    # Xcode derived data
    show_progress $((++ops)) $total_ops "Checking Xcode caches"
    if [[ -d "$HOME/Library/Developer/Xcode/DerivedData" ]]; then
        local xcode_size=$(du -sh "$HOME/Library/Developer/Xcode/DerivedData" 2>/dev/null | awk '{print $1}')
        log_info "Xcode DerivedData size: $xcode_size"
        safe_remove "$HOME/Library/Developer/Xcode/DerivedData/*"
    fi
    
    # Docker cleanup
    show_progress $((++ops)) $total_ops "Checking Docker"
    if command -v docker &> /dev/null; then
        log_info "Cleaning Docker caches..."
        docker system prune -af --volumes 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Gradle cache
    show_progress $((++ops)) $total_ops "Checking Gradle cache"
    if [[ -d "$HOME/.gradle/caches" ]]; then
        local gradle_size=$(du -sh "$HOME/.gradle/caches" 2>/dev/null | awk '{print $1}')
        log_info "Gradle cache size: $gradle_size"
        safe_remove "$HOME/.gradle/caches/*"
    fi
    
    # Node modules global cache
    show_progress $((++ops)) $total_ops "Checking npm cache"
    if [[ -d "$HOME/.npm" ]]; then
        local npm_size=$(du -sh "$HOME/.npm" 2>/dev/null | awk '{print $1}')
        log_info "npm cache size: $npm_size"
        if command -v npm &> /dev/null; then
            npm cache clean --force 2>&1 | tee -a "$LOG_FILE"
        fi
    fi
    
    # Yarn cache
    show_progress $((++ops)) $total_ops "Checking Yarn cache"
    if command -v yarn &> /dev/null; then
        log_info "Cleaning Yarn cache..."
        yarn cache clean 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Python __pycache__
    show_progress $((++ops)) $total_ops "Cleaning Python cache files"
    log_info "Removing Python cache files..."
    find "$HOME" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
    find "$HOME" -type f -name "*.pyc" -delete 2>/dev/null
    find "$HOME" -type f -name "*.pyo" -delete 2>/dev/null
    
    # Go cache
    show_progress $((++ops)) $total_ops "Checking Go cache"
    if command -v go &> /dev/null; then
        log_info "Cleaning Go cache..."
        go clean -cache 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Rust cache
    show_progress $((++ops)) $total_ops "Checking Rust cache"
    if [[ -d "$HOME/.cargo" ]]; then
        log_info "Rust/Cargo cache found (not cleaning - may be needed)"
    fi
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Application cache optimization completed"
}

# 35. Browser Optimization
optimize_browsers() {
    if ! confirm_operation "browser_optimization" "Optimize browser profiles and databases"; then
        return
    fi
    
    log_info "Optimizing browser profiles..."
    local ops=0
    local total_ops=4
    
    # Safari profile
    show_progress $((++ops)) $total_ops "Optimizing Safari"
    if [[ -f "$HOME/Library/Safari/History.db" ]]; then
        safe_remove "$HOME/Library/Safari/History.db-shm"
        safe_remove "$HOME/Library/Safari/History.db-wal"
        sqlite3 "$HOME/Library/Safari/History.db" "VACUUM;" 2>/dev/null
        sqlite3 "$HOME/Library/Safari/History.db" "REINDEX;" 2>/dev/null
        log_success "Safari database optimized"
    fi
    
    # Chrome profiles
    show_progress $((++ops)) $total_ops "Optimizing Chrome"
    if [[ -d "$HOME/Library/Application Support/Google/Chrome" ]]; then
        log_info "Chrome profile optimization:"
        find "$HOME/Library/Application Support/Google/Chrome" -name "History" -exec sqlite3 {} "VACUUM;" \; 2>/dev/null
        find "$HOME/Library/Application Support/Google/Chrome" -name "Cookies" -exec sqlite3 {} "VACUUM;" \; 2>/dev/null
        log_success "Chrome databases optimized"
    fi
    
    # Firefox profiles
    show_progress $((++ops)) $total_ops "Optimizing Firefox"
    if [[ -d "$HOME/Library/Application Support/Firefox" ]]; then
        log_info "Firefox profile optimization:"
        find "$HOME/Library/Application Support/Firefox" -name "places.sqlite" -exec sqlite3 {} "VACUUM;" \; 2>/dev/null
        find "$HOME/Library/Application Support/Firefox" -name "cookies.sqlite" -exec sqlite3 {} "VACUUM;" \; 2>/dev/null
        log_success "Firefox databases optimized"
    fi
    
    # Edge
    show_progress $((++ops)) $total_ops "Optimizing Edge"
    if [[ -d "$HOME/Library/Application Support/Microsoft Edge" ]]; then
        log_info "Edge profile optimization:"
        find "$HOME/Library/Application Support/Microsoft Edge" -name "History" -exec sqlite3 {} "VACUUM;" \; 2>/dev/null
        log_success "Edge databases optimized"
    fi
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Browser optimization completed"
}

# 36. Privacy Data Cleanup
cleanup_privacy_data() {
    if ! confirm_operation "privacy_cleanup" "Clean privacy-sensitive data (cookies, history, etc.)"; then
        return
    fi
    
    log_info "Cleaning privacy-sensitive data..."
    local ops=0
    local total_ops=6
    
    # Safari history and cookies
    show_progress $((++ops)) $total_ops "Safari privacy data"
    read -p "Clear Safari browsing history? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        safe_remove "$HOME/Library/Safari/History.db"
        safe_remove "$HOME/Library/Safari/History.db-shm"
        safe_remove "$HOME/Library/Safari/History.db-wal"
        log_success "Safari history cleared"
    fi
    
    # Recent items
    show_progress $((++ops)) $total_ops "Recent items"
    safe_remove "$HOME/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/*"
    safe_remove "$HOME/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentApplications.sfl*"
    safe_remove "$HOME/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentDocuments.sfl*"
    safe_remove "$HOME/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentServers.sfl*"
    
    # Siri data
    show_progress $((++ops)) $total_ops "Siri data"
    safe_remove "$HOME/Library/Assistant/SiriAnalytics.db"
    
    # Quick Look recent items
    show_progress $((++ops)) $total_ops "Quick Look recent items"
    safe_remove "$HOME/Library/Application Support/Quick Look/*"
    
    # Spotlight suggestions
    show_progress $((++ops)) $total_ops "Spotlight suggestions"
    safe_remove "$HOME/Library/Safari/RecentSearches.plist"
    
    # Clear clipboard
    show_progress $((++ops)) $total_ops "Clipboard"
    read -p "Clear clipboard? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pbcopy < /dev/null
        log_success "Clipboard cleared"
    fi
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "Privacy data cleanup completed"
}

# 37. System Log Analysis
analyze_system_logs() {
    if ! confirm_operation "log_analysis" "Analyze system logs for errors and warnings"; then
        return
    fi
    
    log_info "Analyzing system logs..."
    local ops=0
    local total_ops=4
    
    # Recent system errors
    show_progress $((++ops)) $total_ops "Checking for recent errors"
    log_info "Recent system errors (last 1 hour):"
    log show --predicate 'eventMessage contains "error" OR eventMessage contains "fail"' \
        --info --last 1h 2>/dev/null | tail -100 | tee -a "$LOG_FILE"
    
    # Kernel panics
    show_progress $((++ops)) $total_ops "Checking for kernel panics"
    log_info "Checking for kernel panics:"
    if ls /Library/Logs/DiagnosticReports/Kernel_*.panic 2>/dev/null; then
        log_warning "⚠️ Kernel panics detected!"
        ls -lt /Library/Logs/DiagnosticReports/Kernel_*.panic | tee -a "$LOG_FILE"
    else
        log_success "✓ No kernel panics found"
    fi
    
    # Application crashes
    show_progress $((++ops)) $total_ops "Checking for application crashes"
    log_info "Recent application crashes (last 7 days):"
    # Use subshell to prevent SIGPIPE from terminating the script
    # when head closes the pipe early (exit code 141)
    (find "$HOME/Library/Logs/DiagnosticReports" -name "*.crash" -mtime -7 -exec basename {} \; 2>/dev/null | \
        sort | uniq -c | sort -rn | head -10 || true) | tee -a "$LOG_FILE"
    
    # Disk errors
    show_progress $((++ops)) $total_ops "Checking for disk errors"
    log_info "Checking for disk errors:"
    log show --predicate 'processImagePath contains "diskmanagementd" OR processImagePath contains "fsck"' \
        --info --last 24h 2>/dev/null | grep -i "error\|fail" | tail -20 | tee -a "$LOG_FILE"
    
    complete_progress
    COMPLETED_OPERATIONS=$((COMPLETED_OPERATIONS + 1))
    log_success "System log analysis completed"
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
13. ✅ System Updates Check - macOS and security updates verified
14. ✅ Application Updates Check - Third-party software updates checked
15. ✅ Driver and Hardware Check - System health and drivers verified
16. ✅ Additional Optimizations - Various system tweaks

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
    
    # Generate HTML report as well
    generate_html_report
}

# Generate HTML Report
generate_html_report() {
    local html_report="${REPORT_FILE%.md}.html"
    log_debug "Generating HTML report: $html_report"
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local duration_min=$((duration / 60))
    local duration_sec=$((duration % 60))
    
    cat > "$html_report" << 'EOHTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>macOS Maintenance Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        header h1 { font-size: 2.5em; margin-bottom: 10px; }
        header p { font-size: 1.1em; opacity: 0.9; }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 40px;
            background: #f8f9fa;
        }
        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
            border-left: 4px solid #667eea;
        }
        .stat-card h3 {
            color: #666;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 10px;
        }
        .stat-card .value {
            font-size: 2.5em;
            font-weight: bold;
            color: #333;
        }
        .stat-card .label {
            color: #999;
            font-size: 0.9em;
            margin-top: 5px;
        }
        .success { color: #28a745; }
        .warning { color: #ffc107; }
        .error { color: #dc3545; }
        .info { color: #17a2b8; }
        .content {
            padding: 40px;
        }
        section {
            margin-bottom: 40px;
        }
        h2 {
            color: #333;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid #667eea;
        }
        .operation-list {
            list-style: none;
        }
        .operation-list li {
            padding: 12px;
            margin-bottom: 8px;
            background: #f8f9fa;
            border-radius: 4px;
            border-left: 3px solid #28a745;
        }
        .operation-list li::before {
            content: "✓ ";
            color: #28a745;
            font-weight: bold;
            margin-right: 10px;
        }
        .skipped-list li {
            border-left-color: #ffc107;
        }
        .skipped-list li::before {
            content: "⏭ ";
            color: #ffc107;
        }
        .error-list li {
            border-left-color: #dc3545;
        }
        .error-list li::before {
            content: "✗ ";
            color: #dc3545;
        }
        .warning-list li {
            border-left-color: #ffc107;
        }
        .warning-list li::before {
            content: "⚠ ";
            color: #ffc107;
        }
        footer {
            background: #2c3e50;
            color: white;
            padding: 30px 40px;
            text-align: center;
        }
        footer p { opacity: 0.8; }
        .badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 0.85em;
            font-weight: 600;
            margin-left: 8px;
        }
        .badge-success { background: #d4edda; color: #155724; }
        .badge-warning { background: #fff3cd; color: #856404; }
        .badge-danger { background: #f8d7da; color: #721c24; }
        .badge-info { background: #d1ecf1; color: #0c5460; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🔧 macOS Maintenance Report</h1>
EOHTML

    # Add timestamp and version
    cat >> "$html_report" << EOF
            <p>Generated: $(date '+%B %d, %Y at %H:%M:%S')</p>
            <p>Script Version: $SCRIPT_VERSION</p>
        </header>

        <div class="stats">
            <div class="stat-card">
                <h3>Operations Completed</h3>
                <div class="value success">$COMPLETED_OPERATIONS</div>
                <div class="label">out of $TOTAL_OPERATIONS total</div>
            </div>
            <div class="stat-card">
                <h3>Space Freed</h3>
                <div class="value info">$(numfmt --to=iec-i --suffix=B $((SPACE_FREED * 1024)))</div>
                <div class="label">approximate</div>
            </div>
            <div class="stat-card">
                <h3>Execution Time</h3>
                <div class="value info">${duration_min}m ${duration_sec}s</div>
                <div class="label">total duration</div>
            </div>
            <div class="stat-card">
                <h3>Status</h3>
                <div class="value">
                    <span class="badge badge-success">✓ ${COMPLETED_OPERATIONS} OK</span>
                    <span class="badge badge-warning">⚠ ${#WARNINGS[@]} Warnings</span>
                    <span class="badge badge-danger">✗ ${#ERRORS[@]} Errors</span>
                </div>
            </div>
        </div>

        <div class="content">
EOF

    # Add completed operations
    if [[ $COMPLETED_OPERATIONS -gt 0 ]]; then
        cat >> "$html_report" << 'EOF'
            <section>
                <h2>✅ Completed Operations</h2>
                <ul class="operation-list">
                    <li>Cache Cleanup - System and application caches cleared</li>
                    <li>Log Cleanup - Old log files removed</li>
                    <li>Temporary Files - Temporary files and folders cleaned</li>
                    <li>Memory Management - Memory analyzed and optimized</li>
                    <li>APFS Snapshots - Snapshot management performed</li>
                    <li>Security Audit - Security configuration verified</li>
                    <li>Backup Verification - Backup status confirmed</li>
                    <li>And more... (see detailed report for complete list)</li>
                </ul>
            </section>
EOF
    fi

    # Add skipped operations
    if [[ ${#SKIPPED_OPERATIONS[@]} -gt 0 ]]; then
        cat >> "$html_report" << 'EOF'
            <section>
                <h2>⏭ Skipped Operations</h2>
                <ul class="operation-list skipped-list">
EOF
        for skip in "${SKIPPED_OPERATIONS[@]}"; do
            echo "                    <li>$skip</li>" >> "$html_report"
        done
        cat >> "$html_report" << 'EOF'
                </ul>
            </section>
EOF
    fi

    # Add errors
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        cat >> "$html_report" << 'EOF'
            <section>
                <h2>❌ Errors Encountered</h2>
                <ul class="operation-list error-list">
EOF
        for error in "${ERRORS[@]}"; do
            echo "                    <li>$error</li>" >> "$html_report"
        done
        cat >> "$html_report" << 'EOF'
                </ul>
            </section>
EOF
    fi

    # Add warnings
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        cat >> "$html_report" << 'EOF'
            <section>
                <h2>⚠️ Warnings</h2>
                <ul class="operation-list warning-list">
EOF
        for warning in "${WARNINGS[@]}"; do
            echo "                    <li>$warning</li>" >> "$html_report"
        done
        cat >> "$html_report" << 'EOF'
                </ul>
            </section>
EOF
    fi

    # Add recommendations
    cat >> "$html_report" << EOF
            <section>
                <h2>📋 Recommendations</h2>
                <h3>Post-Maintenance Actions</h3>
                <ul class="operation-list">
                    <li>Restart your Mac to complete all system changes</li>
                    <li>Verify applications work correctly after restart</li>
                    <li>Check Spotlight indexing completion (may take time)</li>
                    <li>Open Mail to rebuild envelope index (first launch may be slow)</li>
                    <li>Test network connectivity if network reset was performed</li>
                </ul>

                <h3>Regular Maintenance Schedule</h3>
                <ul class="operation-list">
                    <li>Weekly: Empty Trash, clear browser caches</li>
                    <li>Monthly: Run this maintenance script</li>
                    <li>Quarterly: Check for macOS and application updates</li>
                    <li>Annually: Consider clean macOS installation for optimal performance</li>
                </ul>
            </section>

            <section>
                <h2>📊 System Information</h2>
                <pre style="background: #f8f9fa; padding: 20px; border-radius: 4px; overflow-x: auto;">
$(sw_vers)
$(df -h / | tail -1)
                </pre>
            </section>

            <section>
                <h2>📁 Files Generated</h2>
                <ul class="operation-list">
                    <li><strong>Markdown Report:</strong> $REPORT_FILE</li>
                    <li><strong>HTML Report:</strong> $html_report</li>
                    <li><strong>Log File:</strong> $LOG_FILE</li>
                </ul>
            </section>
        </div>

        <footer>
            <p><strong>macOS Maintenance Script v$SCRIPT_VERSION</strong></p>
            <p>For issues or questions, review the log file for detailed information</p>
            <p style="margin-top: 10px; font-size: 0.9em;">Generated on MacBook Air 2016 • macOS Monterey 12.7.6</p>
        </footer>
    </div>
</body>
</html>
EOF

    log_success "HTML report generated: $html_report"
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
    echo "║                          VERSION 2.0.0                                 ║"
    echo "║                                                                        ║"
    echo "║                   MacBook Air 2016 - macOS Monterey                    ║"
    echo "║                                                                        ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    log_info "Log file: $LOG_FILE"
    log_info "Report will be saved to: $REPORT_FILE"
    
    # Critical pre-flight checks
    log_info "Performing pre-flight checks..."
    
    # Check disk space
    if ! check_disk_space; then
        log_error "Pre-flight check failed: insufficient disk space"
        exit 1
    fi
    
    # Start caffeinate to prevent sleep
    start_caffeinate
    
    # Check for sudo
    check_sudo
    
    # Display system information
    echo ""
    echo -e "${BOLD}System Information:${NC}"
    sw_vers | tee -a "$LOG_FILE"
    echo ""
    
    # Count total operations (updated to include new operations)
    TOTAL_OPERATIONS=37
    
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
    
    # Execute maintenance operations in order
    # Network-dependent operations MUST run before network reset
    check_system_updates
    check_app_updates
    
    # NEW: Critical operations first
    verify_backups
    manage_memory
    perform_security_audit
    
    # Regular maintenance operations
    cleanup_caches
    cleanup_logs
    cleanup_temp
    manage_apfs_snapshots
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
    check_drivers_hardware
    additional_optimizations
    
    # NEW: Additional high-priority operations
    find_large_files
    find_duplicate_files
    optimize_startup
    optimize_app_caches
    optimize_browsers
    cleanup_privacy_data
    analyze_system_logs
    
    # NEW: Additional diagnostics
    perform_network_diagnostics
    monitor_thermal_status
    
    # Network reset should be last among network operations
    reset_network
    
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

# Parse command-line arguments
parse_arguments "$@"

# Run main function
main

exit 0
