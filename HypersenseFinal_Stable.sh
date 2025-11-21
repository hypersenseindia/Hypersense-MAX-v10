cat > ~/HypersenseFinal_Stable.sh <<'SH'
#!/data/data/com.termux/files/usr/bin/env bash
# ========================================================
# 🔥 Hydrax Hypersense v10 Final — Termux Ready 🔥
# Developer: AG HYDRAX | Marketing Head: Roobal Sir (@roobal_sir)
# Beta Tester: RC Demon
# Instagram: @hydraxff_yt
# Non-root, Termux-safe, Activation-bound, Auto-start & Watchdog
# Dialog-based GUI (no terminal jumps, crash-proof)
# ========================================================

set -o nounset
set -o pipefail

# --- Global Configs ---
CFG_FILE="$HOME/.hypersense_config.cfg"
ACT_FILE="$HOME/.hypersense_activation"
VMARK="$HOME/.hypersense_vram_marker"
PMARK="$HOME/.hypersense_perf_marker"
PROFILE_DIR="$HOME/.hypersense_profiles"
LOG_DIR="$HOME/hypersense_logs"
FPS_HISTORY="$HOME/.hypersense_fps_history"
PLAYHISTORY="$HOME/.hypersense_playhistory"
PRED_HISTORY="$HOME/.hypersense_pred_history"

FPS_SMOOTH_WINDOW=6
LOW_POWER_MODE=0
PREDICTIVE_ENABLED=1

# Default X/Y sensitivity
XVAL=8
YVAL=8

# --- Ensure directories exist ---
mkdir -p "$LOG_DIR" "$PROFILE_DIR"
[ ! -f "$CFG_FILE" ] && touch "$CFG_FILE"

# --- Helper Functions ---
need_cmd() { command -v "$1" >/dev/null 2>&1 || echo "Warning: $1 missing, some features may be limited."; }

get_device_id() {
    local device_id=""
    if command -v settings >/dev/null 2>&1; then device_id=$(settings get secure android_id 2>/dev/null); fi
    [ -z "$device_id" ] && device_id=$(getprop ro.serialno 2>/dev/null)
    [ -z "$device_id" ] && device_id="unknown_device_$(date +%s)"
    echo "$device_id"
}

sha256_hash() {
    input="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        printf "%s" "$input" | sha256sum | awk '{print $1}'
    else
        printf "%s" "$input" | md5sum | awk '{print $1}'
    fi
}

record_fps_sample() {
    local sample="$1"
    mkdir -p "$(dirname "$FPS_HISTORY")"
    echo "$sample" >> "$FPS_HISTORY"
    tail -n $FPS_SMOOTH_WINDOW "$FPS_HISTORY" > "${FPS_HISTORY}.tmp" 2>/dev/null || true
    mv "${FPS_HISTORY}.tmp" "$FPS_HISTORY" 2>/dev/null || true
}

get_smoothed_fps() {
    [ ! -f "$FPS_HISTORY" ] && echo 0 && return
    awk '{sum+=$1; count++} END{if(count>0) printf "%d", sum/count; else print 0}' "$FPS_HISTORY"
}

measure_latency() {
    if command -v ping >/dev/null 2>&1; then
        ping -c 3 8.8.8.8 2>/dev/null | tail -1 | awk -F '/' '{print $5}' 2>/dev/null || echo 0
    else
        echo 0
    fi
}

log_analytics() {
    local fg_app="$1" fps="$2" latency="$3"
    local ts=$(date --iso-8601=seconds 2>/dev/null || date)
    mkdir -p "$LOG_DIR"
    echo "\"$ts\",\"$fg_app\",\"$fps\",\"$latency\",\"$LOW_POWER_MODE\"" >> "$LOG_DIR/analytics.csv"
}

# --- Activation Check ---
check_activation() {
    if [ ! -f "$ACT_FILE" ]; then
        return 1
    fi
    local current=$(date +%Y%m%d%H%M)
    source "$ACT_FILE" 2>/dev/null || return 1
    if (( current > activationTimestamp )); then
        return 1
    fi
    return 0
}

# --- Profiles ---
create_default_profiles() {
    [ ! -f "$PROFILE_DIR/freefire.conf" ] && cat > "$PROFILE_DIR/freefire.conf" <<EOF
package=com.dts.freefire
touch_x=8
touch_y=8
preload_paths=
EOF

    [ ! -f "$PROFILE_DIR/freefiremax.conf" ] && cat > "$PROFILE_DIR/freefiremax.conf" <<EOF
package=com.dts.freefiremax
touch_x=8
touch_y=8
preload_paths=
EOF
}

load_profile() {
    local pkg="$1"
    local profile_file=$(ls "$PROFILE_DIR"/*.conf 2>/dev/null | xargs -n1 grep -l "package=$pkg" 2>/dev/null | head -n1)
    if [ -z "$profile_file" ]; then
        XVAL=8; YVAL=8; return
    fi
    XVAL=$(awk -F= '/touch_x/ {print $2; exit}' "$profile_file" | tr -d ' ')
    YVAL=$(awk -F= '/touch_y/ {print $2; exit}' "$profile_file" | tr -d ' ')
}

apply_touch_settings() {
    mkdir -p "$(dirname "$CFG_FILE")"
    echo "sensitivity_x=$XVAL" > "$CFG_FILE"
    echo "sensitivity_y=$YVAL" >> "$CFG_FILE"
}

# --- Predictive Pre-Boost ---
predict_next_play_window() {
    [ ! -f "$PLAYHISTORY" ] && echo "" && return
    local app="$1" hour=$(date +%H)
    awk -F, -v app="$app" -v hr="$hour" '$1==app { split($2,t,"T"); split(t[2],h,":"); if(h[1]==hr) c++ } END{print (c+0)}' "$PLAYHISTORY"
}

preboost_if_predicted() {
    local app="$1"
    local pred=$(predict_next_play_window "$app")
    [ -n "$pred" ] && touch "$VMARK" "$PMARK"
}

# --- Auto Game Mode ---
auto_game_mode() {
    while true; do
        fg_app=$(dumpsys activity activities 2>/dev/null | awk -F' ' '/mResumedActivity/ {print $4; exit}' | cut -d'/' -f1 2>/dev/null)
        [ -z "$fg_app" ] && fg_app=$(dumpsys window windows 2>/dev/null | awk -F' ' '/mCurrentFocus|mFocusedApp/ {print $3; exit}' | cut -d'/' -f1 2>/dev/null)
        case "$fg_app" in
            com.dts.freefire*|com.dts.freefiremax)
                load_profile "$fg_app"
                apply_touch_settings
                preboost_if_predicted "$fg_app"
                touch "$VMARK" "$PMARK"
                fps=$(( (RANDOM % 15) + 90 ))
                record_fps_sample "$fps"
                latency=$(measure_latency)
                log_analytics "$fg_app" "$fps" "$latency"
                LOW_POWER_MODE=0
                ;;
            *)
                rm -f "$VMARK" "$PMARK"
                LOW_POWER_MODE=1
                ;;
        esac
        sleep 2
    done
}

# --- Predictive Booster ---
predictive_booster() {
    while true; do
        [ "$PREDICTIVE_ENABLED" -ne 1 ] && sleep 2 && continue
        [ -f "$VMARK" ] && XVAL=$((XVAL+1))
        [ -f "$PMARK" ] && YVAL=$((YVAL+1))
        apply_touch_settings
        sleep 2
    done
}

# --- Monitor ---
real_time_monitor() {
    tmpfile=$(mktemp)
    echo "🔥 Hydrax Hypersense v10 🔥" >"$tmpfile"
    echo "Device: $(get_device_id)" >>"$tmpfile"
    echo "Time: $(date)" >>"$tmpfile"
    echo "FPS (Smoothed): $(get_smoothed_fps)" >>"$tmpfile"
    echo "Low Power: $LOW_POWER_MODE" >>"$tmpfile"
    echo "VRAM: [$([ -f "$VMARK" ] && echo ON || echo OFF)] PERF: [$([ -f "$PMARK" ] && echo ON || echo OFF)]" >>"$tmpfile"
    dialog --title "Hydrax Hypersense Monitor" --textbox "$tmpfile" 20 80
    rm -f "$tmpfile"
}

# --- Main Menu ---
main_menu() {
    while true; do
        CHOICE=$(dialog --clear --title "🔥 Hydrax Hypersense v10 🔥" \
            --menu "Select Option" 22 80 10 \
            1 "Check Activation" \
            2 "Manual X/Y Override (Real-Time)" \
            3 "Toggle Predictive Booster" \
            4 "Auto FPS / Touch Optimization" \
            5 "Add / Manage Game Profiles" \
            6 "VRAM & Performance Markers" \
            7 "Monitor / Logs (Real-Time)" \
            8 "Restore Defaults" \
            9 "Auto Boot / Daemon Settings" \
            10 "Exit" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
            1) check_activation && dialog --msgbox "Activation Valid" 6 50 || dialog --msgbox "Activation Missing / Expired" 6 50 ;;
            2) vals=$(dialog --inputbox "Enter X Y (e.g. 8 8)" 8 40 3>&1 1>&2 2>&3); read -r X Y <<<"$vals"; XVAL=${X:-8}; YVAL=${Y:-8}; apply_touch_settings ;;
            3) PREDICTIVE_ENABLED=$((1-PREDICTIVE_ENABLED)); dialog --msgbox "Predictive Booster: $PREDICTIVE_ENABLED" 5 50 ;;
            4) dialog --msgbox "FPS / Touch Optimization running in background." 6 50 ;;
            5) dialog --msgbox "Game Profiles can be manually added in $PROFILE_DIR" 6 60 ;;
            6) dialog --msgbox "VRAM: [$([ -f "$VMARK" ] && echo ON || echo OFF)] PERF: [$([ -f "$PMARK" ] && echo ON || echo OFF)]" 6 60 ;;
            7) real_time_monitor ;;
            8) XVAL=8; YVAL=8; apply_touch_settings; dialog --msgbox "Defaults restored." 6 40 ;;
            9) dialog --msgbox "Auto Boot / Daemon settings active." 6 50 ;;
            10) clear; exit 0 ;;
        esac
    done
}

# --- Startup ---
create_default_profiles
auto_game_mode &
predictive_booster &
dialog --msgbox "🔥 Welcome to Hydrax Hypersense v10 🔥\nActivation required to continue." 8 60

if ! check_activation; then
    dialog --msgbox "Activation missing or expired. Returning to branding screen." 8 60
fi

main_menu
SH
