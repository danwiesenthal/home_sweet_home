#!/bin/bash
# Status line for Claude Code.
#
# Layout (Dan 2026-05-05 spec):
#   Line 1: model_short │ context% │ 5h➞HH:MM ▓▓░ N% NhMm │ 7d➞dayHH:MM …
#   Line 2: 7d window │ bat N% (⚡ if charging)
#   Line 3: in ~/cwd
#   Line 4: on <branch>   (omitted in non-git dirs)
#
# Color thresholds (Dan 2026-05-09):
#  - Context window (1M models): non-linear, by ABSOLUTE tokens,
#    matching where model performance falls off. Blue ≤100k, green
#    ≤256k, then yellow→orange→red through 400k/600k.
#  - 5h / 7d usage: PACING-RELATIVE with an absolute guard. Color
#    tracks (usage% − time-elapsed%): blue under pace, green on/
#    slightly-over (wide green band — being one block past the pace
#    marker is still fine), then yellow→orange→red only as usage gets
#    *significantly* ahead of pace; plus usage ≥90% floors at orange
#    (nearly out) and ≥90% with real time left forces red (locked out
#    for a while). Near the window's end a near-full bar stays orange,
#    not red — a reset is close.
#  - Battery: simple absolute thresholds — ≥80 blue, ≥60 green,
#    ≥40 yellow, ≥20 orange, <20 red.
#
# Tokens / cache-hit / session-spend are intentionally commented out
# below — kept in source for easy re-enable, but excluded from the
# rendered line by request 2026-05-05.
#
# Backup of the prior version: ~/.claude/statusline-command.sh.bak-2026-05-05

input=$(cat)

# ── Extract base data ─────────────────────────────────────────────────────────
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')
context_window=$(echo "$input" | jq '.context_window')
cost_data=$(echo "$input" | jq '.cost')

# Reasoning-effort suffix for the model slug. Source of truth is the
# statusline input JSON (.effort.level) — this reflects the live
# session value, including transient /effort overrides. NOT
# settings.json: that's the persistent default and goes stale the
# moment the user runs /effort during a session.
effort_level=$(echo "$input" | jq -r '.effort.level // empty' 2>/dev/null)
case "$effort_level" in
    xhigh)  effort_short="xhigh" ;;
    high)   effort_short="high"  ;;
    medium) effort_short="med"   ;;
    low)    effort_short="low"   ;;
    "")     effort_short=""      ;;
    *)      effort_short="$effort_level" ;;   # max, or any future label
esac

[[ "$current_dir" == "$HOME"* ]] \
    && dir_display="~${current_dir#$HOME}" \
    || dir_display="$current_dir"

# ── Colors ────────────────────────────────────────────────────────────────────
# Cool→warm palette: cyan (peaceful) → green → orange → red.
# 2026-05-05 (Dan): switched the low-pressure end from \033[34m
# (dark blue) to \033[36m (cyan, same as the model slug accent) —
# easier on the eye for the steady-state colors that fill most of
# the line most of the time.
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[38;5;220m'   # 256-color gold; sits naturally between green and orange-208
ORANGE=$'\033[38;5;208m'   # 256-color orange (between yellow and red)
RED=$'\033[31m'
BRED=$'\033[91m'           # bright red (still used for ⚠ extra warning)
MAGENTA=$'\033[35m'
DIM=$'\033[2m'
RESET=$'\033[0m'
SEP=" ${DIM}│${RESET} "

# ── Git branch ────────────────────────────────────────────────────────────────
branch=""
if git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$current_dir" branch --show-current 2>/dev/null)
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

# Compact model id: "Opus 4.7 (1M context)" -> "op4.7-1M"
shorten_model() {
    local raw="$1" base="$1" suffix=""
    case "$raw" in
        *"(1M context)"*) suffix="-1M" ;;
        *"(200k context)"*) suffix="-200k" ;;
    esac
    base="${raw% (*}"
    local family version short
    family="${base%% *}"
    version="${base##* }"
    case "$family" in
        Opus)   short="op" ;;
        Sonnet) short="so" ;;
        Haiku)  short="hk" ;;
        *)      # Unknown family — keep first 2 chars lowercased
                short=$(printf '%s' "${family:0:2}" | tr '[:upper:]' '[:lower:]')
                ;;
    esac
    # If family == version (single-word display name), don't double-print
    [ "$family" = "$version" ] && version=""
    printf "%s%s%s" "$short" "$version" "$suffix"
}

# Progress bar with optional pacing marker │
make_bar() {
    local pct=$1 target=${2:-} width=${3:-10}
    local filled=$(( (pct * width + 50) / 100 ))
    [ "$filled" -gt "$width" ] && filled=$width
    local target_pos=-1
    if [ -n "$target" ] && [ "$target" -ge 0 ] 2>/dev/null; then
        target_pos=$(( (target * width + 50) / 100 ))
        [ "$target_pos" -ge "$width" ] && target_pos=$(( width - 1 ))
    fi
    local bar=""
    for ((i=0; i<width; i++)); do
        if   [ "$i" -eq "$target_pos" ]; then bar="${bar}│"
        elif [ "$i" -lt "$filled" ];     then bar="${bar}▓"
        else                                  bar="${bar}░"
        fi
    done
    printf "%s" "$bar"
}

# Context window: color by ABSOLUTE tokens used, not fill %.
# 1M-context models perform best in the first 100k, decent through
# 256k, then degrade. Past 256k transition through yellow→orange→red
# so the bar reflects the model-quality cliff, not bar-fill geometry.
# (Dan 2026-05-09 — replaces prior 25/50/75 fill-% thresholds.)
pct_color_context() {
    local tokens=$1
    if   [ "$tokens" -ge 600000 ] 2>/dev/null; then printf "%s" "$RED"
    elif [ "$tokens" -ge 400000 ] 2>/dev/null; then printf "%s" "$ORANGE"
    elif [ "$tokens" -ge 256000 ] 2>/dev/null; then printf "%s" "$YELLOW"
    elif [ "$tokens" -ge 100000 ] 2>/dev/null; then printf "%s" "$GREEN"
    else                                            printf "%s" "$CYAN"
    fi
}

# 5h / 7d windows: pacing-aware color with an absolute-proximity guard.
# Dan 2026-05-09 v2 — the v1 bands (yellow at just +10 over pace, i.e.
# one block past the marker) alarmed too early. Rules now:
#   delta = usage% − time-elapsed%
#   - delta < 0          → blue (cyan)  — under pace, plenty of room
#   - 0 ≤ delta < 20     → green        — on pace / slightly over: fine
#   - 20 ≤ delta < 35    → yellow
#   - 35 ≤ delta < 50    → orange
#   - delta ≥ 50         → red          — burning the window far too fast
# Plus an absolute guard — "ahead of pace" only bites if you're actually
# near the cap:
#   - usage ≥ 90%                        → at least orange (nearly out)
#   - usage ≥ 90% AND time-elapsed ≤ 65% → red (maxed with real time
#                                           left = locked out a while)
# Near the window's end the small delta + the ≤65% carve-out keep even a
# near-full bar at orange, not red — a reset is close by then.
pct_color_pacing() {
    local usage=$1 target=$2
    local delta=$(( usage - target ))
    local sev   # 0 cyan · 1 green · 2 yellow · 3 orange · 4 red
    if   [ "$delta" -ge 50 ] 2>/dev/null; then sev=4
    elif [ "$delta" -ge 35 ] 2>/dev/null; then sev=3
    elif [ "$delta" -ge 20 ] 2>/dev/null; then sev=2
    elif [ "$delta" -ge 0  ] 2>/dev/null; then sev=1
    else                                        sev=0
    fi
    if [ "$usage" -ge 90 ] 2>/dev/null; then
        if   [ "$target" -le 65 ] 2>/dev/null; then sev=4
        elif [ "$sev" -lt 3 ];                 then sev=3
        fi
    fi
    case "$sev" in
        4) printf "%s" "$RED"    ;;
        3) printf "%s" "$ORANGE" ;;
        2) printf "%s" "$YELLOW" ;;
        1) printf "%s" "$GREEN"  ;;
        *) printf "%s" "$CYAN"   ;;
    esac
}

# Battery color: high charge is peaceful (cyan, like the other meters
# at low pressure), low charge is alarming (red). Inverted from the
# usage meters because for battery, full = good. Bands at 80/60/40/20
# (Dan 2026-05-09) — blue down to 80, green to 60, yellow to 40,
# orange to 20, red below.
bat_color() {
    local p=$1
    if   [ "$p" -lt 20 ] 2>/dev/null; then printf "%s" "$RED"
    elif [ "$p" -lt 40 ] 2>/dev/null; then printf "%s" "$ORANGE"
    elif [ "$p" -lt 60 ] 2>/dev/null; then printf "%s" "$YELLOW"
    elif [ "$p" -lt 80 ] 2>/dev/null; then printf "%s" "$GREEN"
    else                                    printf "%s" "$CYAN"
    fi
}

# Token abbreviation (kept for the commented-out tokens path)
fmt_tok() {
    local n=$1
    if   [ "$n" -ge 10000 ] 2>/dev/null; then awk "BEGIN{printf\"%.0fk\",$n/1000}"
    elif [ "$n" -ge 1000  ] 2>/dev/null; then awk "BEGIN{printf\"%.1fk\",$n/1000}"
    else echo "$n"
    fi
}

# pmset → "bat ▓▓▓░░░░░░░ 30%" — meter shape consistent with the
# context / 5h / 7d bars. Returns empty on desktop Mac (no battery)
# so the caller can drop the segment cleanly.
fetch_battery() {
    local raw pct
    raw=$(pmset -g batt 2>/dev/null) || return
    [ -z "$raw" ] && return
    pct=$(echo "$raw" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
    [ -z "$pct" ] && return
    local col bar
    col=$(bat_color "$pct")
    bar=$(make_bar "$pct")
    printf "%sbat %s %s%%%s" "$col" "$bar" "$pct" "$RESET"
}

# ── Context-window bar ────────────────────────────────────────────────────────
# (built independently so it can land on line 1 with the model id)

context_bar=""
usage=$(echo "$context_window" | jq '.current_usage')
if [ "$usage" != "null" ]; then
    input_tokens=$(echo "$usage" | jq '.input_tokens // 0')
    cache_create=$(echo "$usage"  | jq '.cache_creation_input_tokens // 0')
    cache_read=$(echo "$usage"    | jq '.cache_read_input_tokens // 0')
    size=$(echo "$context_window" | jq '.context_window_size')
    in_total=$((input_tokens + cache_create + cache_read))

    pct=$(echo "$context_window" | jq '.used_percentage // empty')
    if [ -z "$pct" ] || [ "$pct" = "null" ]; then
        [ "$size" != "null" ] && [ "$size" -gt 0 ] 2>/dev/null \
            && pct=$((in_total * 100 / size))
    fi
    if [ -n "$pct" ] && [ "$pct" != "null" ]; then
        pct=$(awk "BEGIN{printf\"%d\",$pct}")
        col=$(pct_color_context "$in_total")
        bar=$(make_bar "$pct")
        context_bar="${col}${bar} ${pct}%${RESET}"
    fi
fi

# ── Plan-usage probe (5h + 7d + overage) ──────────────────────────────────────
# Haiku probe: minimal API call to get rate limit headers.
# Always works — even 429 responses include utilization headers.
# Costs ~$0.00001 per probe, cached for 6 minutes.
PROBE_CACHE="/tmp/claude_probe_cache.json"
PROBE_TTL=360

fetch_probe() {
    local now=$(date +%s)

    # Use cached result if fresh
    if [ -f "$PROBE_CACHE" ]; then
        local age=$(( now - $(stat -f %m "$PROBE_CACHE" 2>/dev/null || echo 0) ))
        [ "$age" -lt "$PROBE_TTL" ] && { cat "$PROBE_CACHE"; return; }
    fi

    # Get OAuth token
    local token=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local creds
        creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        [ -n "$creds" ] && token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    fi
    if [ -z "$token" ]; then
        for creds_path in "$HOME/.claude/.credentials.json" "$HOME/.claude/credentials.json"; do
            [ -f "$creds_path" ] && token=$(jq -r '.claudeAiOauth.accessToken // .oauth_token // empty' "$creds_path" 2>/dev/null)
            [ -n "$token" ] && break
        done
    fi
    [ -z "$token" ] && return

    # Minimal Haiku call — response headers always include rate limit data
    local tmpheaders=$(mktemp) tmpbody=$(mktemp)
    curl -s --max-time 5 \
        -D "$tmpheaders" -o "$tmpbody" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-version: 2023-06-01" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Content-Type: application/json" \
        -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"x"}]}' \
        "https://api.anthropic.com/v1/messages" 2>/dev/null

    local f_util f_reset s_util s_reset o_util o_reset o_use
    f_util=$(grep -i 'anthropic-ratelimit-unified-5h-utilization:' "$tmpheaders" | awk '{print $2}' | tr -d '\r\n')
    f_reset=$(grep -i 'anthropic-ratelimit-unified-5h-reset:' "$tmpheaders" | awk '{print $2}' | tr -d '\r\n')
    s_util=$(grep -i 'anthropic-ratelimit-unified-7d-utilization:' "$tmpheaders" | awk '{print $2}' | tr -d '\r\n')
    s_reset=$(grep -i 'anthropic-ratelimit-unified-7d-reset:' "$tmpheaders" | awk '{print $2}' | tr -d '\r\n')
    o_util=$(grep -i 'anthropic-ratelimit-unified-overage-utilization:' "$tmpheaders" | awk '{print $2}' | tr -d '\r\n')
    o_reset=$(grep -i 'anthropic-ratelimit-unified-overage-reset:' "$tmpheaders" | awk '{print $2}' | tr -d '\r\n')
    o_use=$(grep -i 'anthropic-ratelimit-unified-overage-in-use:' "$tmpheaders" | awk '{print $2}' | tr -d '\r\n')
    rm -f "$tmpheaders" "$tmpbody"

    if [ -n "$f_util" ]; then
        local result
        result=$(jq -n \
            --arg fu "$f_util" --arg fr "$f_reset" \
            --arg su "$s_util" --arg sr "$s_reset" \
            --arg ou "${o_util:-0}" --arg or2 "${o_reset:-0}" --arg oi "${o_use:-false}" \
            '{five_h:{util:($fu|tonumber),reset:($fr|tonumber)},
              seven_d:{util:($su|tonumber),reset:($sr|tonumber)},
              overage:{util:($ou|tonumber),reset:($or2|tonumber),in_use:($oi=="true")}}' 2>/dev/null)
        [ -n "$result" ] && echo "$result" > "$PROBE_CACHE" && echo "$result"
    elif [ -f "$PROBE_CACHE" ]; then
        cat "$PROBE_CACHE"
    fi
}

plan_5h="" plan_7d="" extra_str=""
probe_json=$(fetch_probe 2>/dev/null)

if [ -n "$probe_json" ]; then
    now=$(date +%s)

    # ── 5h bar: real utilization + pacing marker ────────────────────────────
    f_util=$(echo "$probe_json" | jq -r '.five_h.util')
    f_reset=$(echo "$probe_json" | jq -r '.five_h.reset')
    if [ -n "$f_util" ] && [ "$f_util" != "null" ]; then
        p=$(awk "BEGIN{printf\"%d\",$f_util*100}")
        # Pacing: how far through the 5h window are we?
        window=18000
        f_reset_int=$(awk "BEGIN{printf\"%d\",$f_reset}")
        elapsed=$(( now - (f_reset_int - window) ))
        [ "$elapsed" -lt 0 ] && elapsed=0
        [ "$elapsed" -gt "$window" ] && elapsed=$window
        tgt=$(( elapsed * 100 / window ))
        # Reset label: precise HH:MM (no hour-rounding — Dan 2026-05-05).
        # The API-returned reset is the actual moment; our display
        # should reflect that, not a rounded "5pm" that hides 23 min.
        lbl=$(date -r "$f_reset_int" '+%-I:%M%p' 2>/dev/null | tr '[:upper:]' '[:lower:]')
        # Time remaining (always Hh Mm — Dan: actual minutes, not just hours)
        rem=$(( f_reset_int - now ))
        rem_str=""
        if [ "$rem" -gt 0 ]; then
            if [ "$rem" -ge 3600 ]; then
                rem_str=" $(( rem/3600 ))h$(( (rem%3600)/60 ))m"
            else
                rem_str=" $(( rem/60 ))m"
            fi
        fi
        col=$(pct_color_pacing "$p" "$tgt")
        bar=$(make_bar "$p" "$tgt")
        plan_5h="${col}5h➞${lbl} ${bar} ${p}%${rem_str}${RESET}"
    fi

    # ── 7d bar: real utilization + pacing marker ────────────────────────────
    s_util=$(echo "$probe_json" | jq -r '.seven_d.util')
    s_reset=$(echo "$probe_json" | jq -r '.seven_d.reset')
    if [ -n "$s_util" ] && [ "$s_util" != "null" ]; then
        p=$(awk "BEGIN{printf\"%d\",$s_util*100}")
        window=604800
        s_reset_int=$(awk "BEGIN{printf\"%d\",$s_reset}")
        elapsed=$(( now - (s_reset_int - window) ))
        [ "$elapsed" -lt 0 ] && elapsed=0
        [ "$elapsed" -gt "$window" ] && elapsed=$window
        tgt=$(( elapsed * 100 / window ))
        # Reset label: precise day+HH:MM.
        lbl=$(date -r "$s_reset_int" '+%a%-I:%M%p' 2>/dev/null | tr '[:upper:]' '[:lower:]')
        # Time remaining
        rem=$(( s_reset_int - now ))
        rem_str=""
        if [ "$rem" -gt 0 ]; then
            days=$(( rem / 86400 ))
            hours=$(( (rem % 86400) / 3600 ))
            mins=$(( (rem % 3600) / 60 ))
            if [ "$days" -gt 0 ]; then
                rem_str=" ${days}d${hours}h"
            else
                rem_str=" ${hours}h${mins}m"
            fi
        fi
        col=$(pct_color_pacing "$p" "$tgt")
        bar=$(make_bar "$p" "$tgt")
        plan_7d="${col}7d➞${lbl} ${bar} ${p}%${rem_str}${RESET}"
    fi

    # ── Extra/overage usage ─────────────────────────────────────────────────
    o_in_use=$(echo "$probe_json" | jq -r '.overage.in_use')
    o_util=$(echo "$probe_json" | jq -r '.overage.util')
    if [ "$o_in_use" = "true" ]; then
        op=$(awk "BEGIN{printf\"%d\",$o_util*100}")
        # Try to enrich with dollar amounts from oauth endpoint (best-effort)
        OAUTH_CACHE="/tmp/claude_oauth_extra.json"
        OAUTH_BACKOFF="/tmp/claude_oauth_backoff"
        dollar_info=""
        if [ -f "$OAUTH_CACHE" ]; then
            extra_used=$(jq -r '.extra_usage.used_credits // empty' "$OAUTH_CACHE" 2>/dev/null)
            extra_limit=$(jq -r '.extra_usage.monthly_limit // empty' "$OAUTH_CACHE" 2>/dev/null)
            if [ -n "$extra_used" ] && [ -n "$extra_limit" ]; then
                used_fmt=$(awk "BEGIN{printf\"\$%.2f\",$extra_used/100}")
                limit_fmt=$(awk "BEGIN{printf\"\$%.0f\",$extra_limit/100}")
                dollar_info=" ${used_fmt}/${limit_fmt}"
            fi
        fi
        if [ ! -f "$OAUTH_BACKOFF" ] || [ $(( now - $(stat -f %m "$OAUTH_BACKOFF" 2>/dev/null || echo 0) )) -gt 900 ]; then
            if [ -z "$(find "$OAUTH_CACHE" -newermt '10 minutes ago' 2>/dev/null)" ]; then
                oauth_token=""
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    oauth_creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
                    [ -n "$oauth_creds" ] && oauth_token=$(echo "$oauth_creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
                fi
                if [ -n "$oauth_token" ]; then
                otmp=$(mktemp)
                ocode=$(curl -s --max-time 3 -w "%{http_code}" -o "$otmp" \
                    -H "Authorization: Bearer $oauth_token" \
                    -H "anthropic-beta: oauth-2025-04-20" \
                    -H "Content-Type: application/json" \
                    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
                if [ "$ocode" = "200" ] && jq -e '.extra_usage' "$otmp" > /dev/null 2>&1; then
                    cp "$otmp" "$OAUTH_CACHE"
                    rm -f "$OAUTH_BACKOFF"
                    extra_used=$(jq -r '.extra_usage.used_credits // empty' "$OAUTH_CACHE" 2>/dev/null)
                    extra_limit=$(jq -r '.extra_usage.monthly_limit // empty' "$OAUTH_CACHE" 2>/dev/null)
                    if [ -n "$extra_used" ] && [ -n "$extra_limit" ]; then
                        used_fmt=$(awk "BEGIN{printf\"\$%.2f\",$extra_used/100}")
                        limit_fmt=$(awk "BEGIN{printf\"\$%.0f\",$extra_limit/100}")
                        dollar_info=" ${used_fmt}/${limit_fmt}"
                    fi
                elif [ "$ocode" = "429" ]; then
                    touch "$OAUTH_BACKOFF"
                fi
                rm -f "$otmp"
                fi
            fi
        fi
        if [ "$op" -gt 0 ] 2>/dev/null; then
            extra_str="${BRED}⚠ extra ${op}%${dollar_info}${RESET}"
        else
            extra_str="${BRED}⚠ extra on${dollar_info}${RESET}"
        fi
    fi
fi

# ── Tokens / cache / spend (DISABLED 2026-05-05; kept for re-enable) ─────────
# Per Dan 2026-05-05 these were not load-bearing on the visible line. The
# computation stays here so re-enabling is just one assembly-array edit.
#
# total_in=$(echo "$context_window" | jq '.total_input_tokens // empty')
# total_out=$(echo "$context_window" | jq '.total_output_tokens // empty')
# token_str=""
# if [ -n "$total_in" ] && [ "$total_in" != "null" ] && \
#    [ -n "$total_out" ] && [ "$total_out" != "null" ]; then
#     in_disp=$(fmt_tok "$total_in")
#     out_disp=$(fmt_tok "$total_out")
#     token_str="${DIM}i:${in_disp} o:${out_disp}${RESET}"
# elif [ "$usage" != "null" ]; then
#     in_disp=$(fmt_tok "$in_total")
#     out_disp=$(fmt_tok "$(echo "$usage" | jq '.output_tokens // 0')")
#     token_str="${DIM}i:${in_disp} o:${out_disp}${RESET}"
# fi
#
# cache_str=""
# if [ "$usage" != "null" ]; then
#     input_tokens=$(echo "$usage" | jq '.input_tokens // 0')
#     cache_read=$(echo "$usage"   | jq '.cache_read_input_tokens // 0')
#     denom=$((input_tokens + cache_read))
#     if [ "$denom" -gt 0 ] && [ "$cache_read" -gt 0 ]; then
#         cpct=$((cache_read * 100 / denom))
#         if   [ "$cpct" -ge 70 ]; then CACHE_COLOR=$GREEN
#         elif [ "$cpct" -ge 40 ]; then CACHE_COLOR=$YELLOW
#         else                          CACHE_COLOR=$RED
#         fi
#         cache_str="${CACHE_COLOR}⚡${cpct}%${RESET}"
#     fi
# fi
#
# cost_str=""
# if [ "$cost_data" != "null" ]; then
#     cost_usd=$(echo "$cost_data" | jq -r '.total_cost_usd // 0')
#     if [ "$cost_usd" != "0" ] && [ "$cost_usd" != "null" ]; then
#         cost_str="${DIM}s:\$$(printf "%.2f" "$cost_usd")${RESET}"
#     fi
# fi

# ── Assemble output ──────────────────────────────────────────────────────────
# 2026-05-05 layout (Dan: built for thinner windows):
#   Line 1: model + context + 5h (+ extra/overage warning when on)
#   Line 2: 7d + battery
#   Line 3: in <cwd> on <branch>
# Empty lines skipped — desktop Mac (no battery) + LM Studio off
# (no probe result) collapses to a 1-line output cleanly.

model_short=$(shorten_model "$model_name")
bat_str=$(fetch_battery)

# Line 1 — model (+ reasoning-effort suffix), context, 5h, overage if active
model_slug="${CYAN}${model_short}${RESET}"
[ -n "$effort_short" ] && model_slug="${model_slug}${DIM}·${RESET}${MAGENTA}${effort_short}${RESET}"
line1_parts=("$model_slug")
[ -n "$context_bar" ] && line1_parts+=("$context_bar")
[ -n "$plan_5h"     ] && line1_parts+=("$plan_5h")
[ -n "$extra_str"   ] && line1_parts+=("$extra_str")

line1=""
for part in "${line1_parts[@]}"; do
    [ -z "$line1" ] && line1="$part" || line1="${line1}${SEP}${part}"
done

# Line 2 — battery + 7d window (Dan 2026-05-05: battery first; quicker
# glance for the meter Dan looks at most when laptop is unplugged).
line2_parts=()
[ -n "$bat_str" ] && line2_parts+=("$bat_str")
[ -n "$plan_7d" ] && line2_parts+=("$plan_7d")

line2=""
for part in "${line2_parts[@]}"; do
    [ -z "$line2" ] && line2="$part" || line2="${line2}${SEP}${part}"
done

# Line 3 — "in <cwd>". Line 4 — "on <branch>" (split off 2026-05-05
# so the combined line doesn't overflow on long repo paths + branch
# names). Small English prepositions in dim, values in their semantic
# colors. Line 4 omitted in non-git dirs.
line3="${DIM}in${RESET} ${GREEN}${dir_display}${RESET}"
line4=""
if [ -n "$branch" ]; then
    line4="${DIM}on${RESET} ${MAGENTA}${branch}${RESET}"
fi

# Print only non-empty lines so a sparse environment doesn't render
# blank rows. Trailing `exit 0` prevents the script from inheriting
# the exit status of the last `[ -n "$lineN" ]` test — when line2 or
# line4 is empty (e.g. no git branch in /tmp, or no battery on a
# desktop), that test returns 1 and Claude Code would treat the
# statusline as failed.
printf "%s\n" "$line1"
[ -n "$line2" ] && printf "%s\n" "$line2"
printf "%s\n" "$line3"
[ -n "$line4" ] && printf "%s\n" "$line4"
exit 0
