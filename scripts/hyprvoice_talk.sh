#!/bin/bash
# ==============================================================================
# hyprvoice_talk.sh - Smart Hybrid Controller for Hyprvoice
#
# Features:
# 1. Push-to-Talk (Hold >400ms): Speak while holding the button, releases to stop.
# 2. Hands-free Toggle (Click <400ms): Click once to start recording freely for
#    minutes without holding, click again to finalize and paste.
# 3. Audio Loopback Protection: Auto-pauses active media players (Spotify, Chrome)
#    and auto-mutes speaker output while recording to keep microphone audio clean.
# 4. Debounce & Concurrency: flock-based serialization to eliminate race conditions.
# ==============================================================================

action=$1

STATE_FILE="/tmp/hyprvoice_media_state"
LOCK_FILE="/tmp/hyprvoice_talk.lock"
TIME_FILE="/tmp/hyprvoice_start_time"
TOGGLE_FILE="/tmp/hyprvoice_toggle_mode"
JUST_STOPPED_FILE="/tmp/hyprvoice_just_stopped"

# Use file locking to serialize start and stop calls and prevent race conditions
exec 200>"$LOCK_FILE"
flock -x 200

get_status() {
    hyprvoice status 2>/dev/null | grep -oP 'status=\K\w+' || echo "idle"
}

STATUS=$(get_status)
now_ms=$(date +%s%3N)

if [ "$action" = "start" ]; then
    # If we are already recording in hands-free toggle mode, this click means STOP
    if [ -f "$TOGGLE_FILE" ]; then
        rm -f "$TOGGLE_FILE" "$TIME_FILE"
        touch "$JUST_STOPPED_FILE"
        
        hyprvoice toggle
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
        if [ -f "$STATE_FILE" ]; then
            playerctl play 2>/dev/null
            rm -f "$STATE_FILE"
        fi
        exit 0
    fi

    # Only start if hyprvoice is currently idle
    if [ "$STATUS" = "idle" ]; then
        echo "$now_ms" > "$TIME_FILE"
        rm -f "$TOGGLE_FILE" "$JUST_STOPPED_FILE"
        
        # 1. Pause media if playing (browsers, Spotify, etc.)
        if playerctl status 2>/dev/null | grep -q "Playing"; then
            playerctl pause
            echo "paused" > "$STATE_FILE"
        else
            rm -f "$STATE_FILE"
        fi
        
        # 2. Mute speakers to prevent mic pollution & ensure mic is unmuted
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 1
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0 2>/dev/null
        
        # 3. Start recording
        hyprvoice toggle
    fi

elif [ "$action" = "stop" ]; then
    # If the user clicked to stop hands-free recording, ignore the release of that click
    if [ -f "$JUST_STOPPED_FILE" ]; then
        rm -f "$JUST_STOPPED_FILE"
        exit 0
    fi

    start_ms=$(cat "$TIME_FILE" 2>/dev/null || echo 0)
    duration=$(( now_ms - start_ms ))

    # If the button was released in less than 400ms, treat it as a CLICK (Toggle / Hands-free mode)
    # Don't stop recording! Let the user speak freely for minutes without holding the button.
    if [ "$duration" -lt 400 ]; then
        touch "$TOGGLE_FILE"
        exit 0
    fi

    # If it was held >= 400ms, treat it as Push-to-Talk (stop on release)
    rm -f "$TOGGLE_FILE" "$TIME_FILE"
    
    if [ "$STATUS" != "idle" ]; then
        hyprvoice toggle
    fi
    
    # Always unmute speakers on stop/release
    wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
    
    # Resume media if we paused it
    if [ -f "$STATE_FILE" ]; then
        playerctl play 2>/dev/null
        rm -f "$STATE_FILE"
    fi
fi
