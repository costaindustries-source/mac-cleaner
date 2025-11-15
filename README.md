# macOS Comprehensive Maintenance Script

A powerful, exhaustive maintenance script specifically designed for MacBook Air 2016 running macOS Monterey 12.7.6. This script performs low-level system operations with high-level output, featuring progress tracking, risk assessment, and detailed reporting.

## Features

### Core Functionality
- ✅ **Comprehensive Cleanup**: Cache, logs, temporary files, and system debris
- ✅ **System Rebuild**: Spotlight, LaunchServices, kernel extensions, and font caches
- ✅ **Optimization**: Database optimization for Mail, Safari, Photos, and more
- ✅ **Disk Management**: Verification, repair, and permission fixes
- ✅ **Network Operations**: DNS flush, network reset, daemon management
- ✅ **Progress Tracking**: Real-time progress bar with ETA calculation
- ✅ **Risk Assessment**: Each operation shows LOW/MEDIUM/HIGH risk level
- ✅ **User Confirmation**: Confirm each category before execution
- ✅ **Timestamped Logging**: Complete audit trail of all operations
- ✅ **Markdown Report**: Detailed final report saved to Desktop
- ✅ **Sudo Support**: Automatic privilege escalation when needed

### Maintenance Operations

#### Low-Level Operations (Safe)
1. **Cache Cleanup** - User, system, browser, and application caches
2. **Log Cleanup** - System and application logs (keeps recent logs)
3. **Temporary Files** - System and user temporary files
4. **DNS Flush** - DNS cache and resolver cleanup
5. **Disk Check** - Disk verification and SMART status
6. **Font Cache** - Font cache cleanup and rebuild
7. **Dock Reset** - Dock database and cache reset
8. **Thumbnail Cache** - Icon and thumbnail cache cleanup
9. **QuickLook Cache** - QuickLook cache and plugin refresh
10. **Login Items** - Review and list login items

#### Medium-Risk Operations
11. **Spotlight Rebuild** - Complete search index rebuild
12. **LaunchServices Rebuild** - Application associations database
13. **Permission Repair** - File permissions and ACLs
14. **Database Optimization** - SQLite VACUUM and REINDEX for system databases
15. **Daemon Operations** - System daemon reload and restart
16. **Mail Optimization** - Mail envelope index and database optimization
17. **iCloud Cache** - iCloud Drive and sync cache cleanup
18. **Language Cleanup** - Remove unused language files (keeps English)

#### High-Risk Operations
19. **Kernel Extensions** - Kext cache rebuild (requires reboot)
20. **Network Reset** - Complete network configuration reset

#### Additional Optimizations
- Notification Center database cleanup
- iOS device backup management
- Software update cache clearing
- Printer cache cleanup
- Time Machine snapshot review
- Quarantine flags cleanup
- Dynamic linker cache update
- System integrity verification
- NVRAM diagnostics

## System Requirements

- **Hardware**: MacBook Air 2016 (or compatible Mac)
- **OS Version**: macOS Monterey 12.7.6
- **RAM**: 8GB recommended
- **Free Space**: At least 5GB for safe operation
- **Permissions**: Sudo/admin access required
- **Backup**: Recent Time Machine or other backup (NO BACKUPS CREATED BY SCRIPT)

## Installation

1. Clone this repository:
```bash
git clone https://github.com/costaindustries-source/mac-cleaner.git
cd mac-cleaner
```

2. Make the script executable:
```bash
chmod +x mac_maintenance.sh
```

## Usage

### Basic Usage
```bash
./mac_maintenance.sh
```

The script will:
1. Display system information
2. Request sudo privileges
3. Present each operation category for confirmation
4. Show risk level (LOW/MEDIUM/HIGH) for each category
5. Display real-time progress with ETA
6. Generate timestamped log file in `/tmp/`
7. Create detailed Markdown report on Desktop

### Interactive Confirmation
For each operation category, you'll see:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Operation Category: cache_cleanup
Description: Clean system and user caches (browser, app, system)
Risk Level: LOW - Safe operation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Proceed with this operation? [Y/n]
```

- Press `Y` or `Enter` to proceed
- Press `N` to skip the operation

### Progress Display
```
Progress: [████████████████████░░░░░░░░░░░░░░░░░] 65% (13/20) ETA: 2m 15s - Cleaning font cache
```

## Output Files

### Log File
- Location: `/tmp/mac_maintenance_YYYYMMDD_HHMMSS.log`
- Contains: Timestamped record of all operations
- Format: `[YYYY-MM-DD HH:MM:SS] INFO/ERROR/WARNING: Message`

### Report File
- Location: `~/Desktop/maintenance_report_YYYYMMDD_HHMMSS.md`
- Contains:
  - Execution summary
  - Space freed
  - Operations performed
  - Errors and warnings
  - System recommendations
  - Technical details
  - System information

## Safety Features

### No Backup Mode
⚠️ **IMPORTANT**: This script does NOT create backups. Ensure you have:
- Recent Time Machine backup
- Critical files backed up to external storage
- Cloud sync enabled for important documents

### Risk Levels Explained

**LOW Risk** - Safe operations that can be run anytime:
- Cache cleanup
- Log cleanup
- Temporary files
- DNS flush
- Font cache
- Dock reset

**MEDIUM Risk** - May require application restart or brief system interruption:
- Spotlight rebuild
- LaunchServices rebuild
- Permission repair
- Database optimization
- Mail optimization

**HIGH Risk** - Significant system changes, restart recommended:
- Kernel extension cache rebuild
- Complete network reset

### What Gets Deleted

**Safe to Delete** (automatically removed):
- Browser caches (Safari, Chrome, Firefox)
- Application caches
- System cache files (SIP-safe)
- Old log files (keeps recent)
- Temporary files
- Download quarantine database
- Font caches
- Icon caches
- Thumbnail caches

**NOT Deleted** (preserved):
- User documents
- Application data
- Photos, Music, Movies
- Mail messages (only cache/index)
- System files
- Configuration files
- Keychain data
- WiFi passwords

## Post-Maintenance Steps

1. **Restart Your Mac** - Essential for kext cache and system changes
2. **Verify Applications** - Ensure apps launch correctly
3. **Check Spotlight** - Search indexing may take 10-30 minutes
4. **Open Mail** - First launch may be slow (rebuilding index)
5. **Test Network** - If network reset was performed
6. **Review Report** - Check for any errors or warnings

## Recommended Maintenance Schedule

- **Weekly**: Empty Trash, clear browser caches manually
- **Monthly**: Run this comprehensive maintenance script
- **Quarterly**: Check for macOS and app updates
- **Annually**: Consider clean macOS installation

## Troubleshooting

### Script Won't Run
```bash
# Make sure it's executable
chmod +x mac_maintenance.sh

# Check permissions
ls -l mac_maintenance.sh
```

### Sudo Password Issues
```bash
# Pre-authenticate
sudo -v

# Then run script
./mac_maintenance.sh
```

### Operation Failed
- Check the log file in `/tmp/` for detailed error messages
- Some operations require System Integrity Protection (SIP) disabled
- Ensure sufficient disk space available
- Try running individual operations by confirming only specific categories

### System Feels Slow After Maintenance
- Wait for Spotlight indexing to complete (check Activity Monitor for `mds_stores`)
- Restart your Mac if not already done
- Some databases rebuild on first app launch (normal)

## Technical Details

### Low-Level Operations Performed

**Cache Management**:
- `rm -rf` on user/system cache directories
- Package manager cache cleanup (brew, npm, pip, gem)
- Font cache database removal
- Application-specific cache cleanup

**System Rebuilds**:
- `mdutil` for Spotlight indexing
- `lsregister` for LaunchServices
- `kextcache` for kernel extensions
- `atsutil` for font cache

**Database Operations**:
- SQLite `VACUUM` and `REINDEX` on system databases
- Mail envelope index rebuild
- Safari, Photos, Calendar database optimization

**Disk Operations**:
- `diskutil verifyVolume` for verification
- `diskutil repairVolume` for repairs
- `diskutil resetUserPermissions` for permissions
- SMART status checking

**Network Operations**:
- `dscacheutil -flushcache` for DNS
- `killall -HUP mDNSResponder` for responder
- `networksetup` for configuration
- ARP cache clearing

**Daemon Management**:
- `launchctl` for daemon control
- System daemon kickstart
- User agent reload

## Compatibility

### Tested On
- MacBook Air (13-inch, Early 2015)
- MacBook Air (13-inch, 2017)
- MacBook Pro (Retina, 13-inch, Early 2015)
- macOS Monterey 12.7.x

### May Work On
- macOS Big Sur 11.x
- macOS Catalina 10.15.x
- Other Intel-based Macs from 2015-2017 era

### Not Compatible With
- Apple Silicon Macs (M1/M2/M3) - some operations differ
- macOS Ventura or newer - commands may have changed
- macOS Mojave or older - some commands not available

## Contributing

Feel free to open issues or submit pull requests for:
- Additional maintenance operations
- Bug fixes
- Compatibility improvements
- Documentation updates

## License

This script is provided as-is for educational and maintenance purposes. Use at your own risk.

## Disclaimer

⚠️ **WARNING**: This script performs system-level operations. While designed to be safe:
- Always maintain current backups
- Review operations before confirming
- Understand risk levels
- Test on non-production systems first
- Some operations may affect system stability if interrupted

The authors are not responsible for any data loss or system issues resulting from use of this script.

## Credits

Created for comprehensive macOS maintenance on MacBook Air 2016, macOS Monterey 12.7.6.

---

**Version**: 1.0.0  
**Last Updated**: November 2025  
**Status**: Production Ready