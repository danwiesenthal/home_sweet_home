#!/bin/bash

input=$(cat)

# ── Extract base data ─────────────────────────────────────────────────────────
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name')
context_window=$(echo "$input" | jq '.context_window')
cost_data=$(echo "$input" | jq '.cost')

[[ "$current_dir" == "$HOME"* ]] \
    && dir_display="~${current_dir#$HOME}" \
    || dir_display="$current_dir"

# ── Colors ────────────────────────────────────────────────────────────────────
CYAN=$'\033[36m'
GREEN=$'\033[32m'
MAGENTA=$'\033[35m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
BRED=$'\033[91m'
DIM=$'\033[2m'
RESET=$'\033[0m'
SEP=" ${DIM}│${RESET} "

# ── Git branch ────────────────────────────────────────────────────────────────
git_branch=""
if git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$current_dir" branch --show-current 2>/dev/null)
    [ -n "$branch" ] && git_branch=" ${MAGENTA}${branch}${RESET}"
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

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

# Cool→warm color by fill %
pct_color() {
    local p=$1
    if   [ "$p" -ge 85 ] 2>/dev/null; then printf "%s" "$BRED"
    elif [ "$p" -ge 70 ] 2>/dev/null; then printf "%s" "$YELLOW"
    elif [ "$p" -ge 40 ] 2>/dev/null; then printf "%s" "$GREEN"
    else                                    printf "%s" "$CYAN"
    fi
}

# Token abbreviation
fmt_tok() {
    local n=$1
    if   [ "$n" -ge 10000 ] 2>/dev/null; then awk "BEGIN{printf\"%.0fk\",$n/1000}"
    elif [ "$n" -ge 1000  ] 2>/dev/null; then awk "BEGIN{printf\"%.1fk\",$n/1000}"
    else echo "$n"
    fi
}

# ── LINE 1: Model + context + location ───────────────────────────────────────

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
        col=$(pct_color "$pct")
        bar=$(make_bar "$pct")
        context_bar="${col}${bar} ${pct}%${RESET}"
    fi
fi

line1_parts=()
line1_parts+=("${CYAN}${model_name}${RESET}")
[ -n "$context_bar" ] && line1_parts+=("$context_bar")
line1_parts+=("${GREEN}${dir_display}${git_branch}${RESET}")

line1=""
for part in "${line1_parts[@]}"; do
    [ -z "$line1" ] && line1="$part" || line1="${line1}${SEP}${part}"
done

# ── LINE 2: Plan usage, tokens, cache, cost ──────────────────────────────────

# Haiku probe: minimal API call to get rate limit headers
# Always works — even 429 responses include utilization headers
# Costs ~$0.00001 per probe, cached for 6 minutes
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

    # Extract rate limit headers
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

plan_5h="${DIM}5h:--${RESET}" plan_7d="${DIM}7d:--${RESET}" extra_str=""
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
        # Reset label (e.g., "5pm")
        rounded=$(( (f_reset_int + 1800) / 3600 * 3600 ))
        lbl=$(date -r "$rounded" '+%-I%p' 2>/dev/null | tr '[:upper:]' '[:lower:]')
        # Time remaining
        rem=$(( f_reset_int - now ))
        rem_str=""
        if [ "$rem" -gt 0 ]; then
            if [ "$rem" -ge 3600 ]; then
                rem_str=" $(( rem/3600 ))h$(( (rem%3600)/60 ))m"
            else
                rem_str=" $(( rem/60 ))m"
            fi
        fi
        col=$(pct_color "$p")
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
        # Reset label with day (e.g., "mon5pm")
        rounded=$(( (s_reset_int + 1800) / 3600 * 3600 ))
        lbl=$(date -r "$rounded" '+%a%-I%p' 2>/dev/null | tr '[:upper:]' '[:lower:]')
        # Time remaining
        rem=$(( s_reset_int - now ))
        rem_str=""
        if [ "$rem" -gt 0 ]; then
            days=$(( rem / 86400 ))
            hours=$(( (rem % 86400) / 3600 ))
            [ "$days" -gt 0 ] && rem_str=" ${days}d${hours}h" || rem_str=" ${hours}h"
        fi
        col=$(pct_color "$p")
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
        # Check if we have cached oauth data (even stale — dollar amounts don't change fast)
        if [ -f "$OAUTH_CACHE" ]; then
            extra_used=$(jq -r '.extra_usage.used_credits // empty' "$OAUTH_CACHE" 2>/dev/null)
            extra_limit=$(jq -r '.extra_usage.monthly_limit // empty' "$OAUTH_CACHE" 2>/dev/null)
            if [ -n "$extra_used" ] && [ -n "$extra_limit" ]; then
                used_fmt=$(awk "BEGIN{printf\"\$%.2f\",$extra_used/100}")
                limit_fmt=$(awk "BEGIN{printf\"\$%.0f\",$extra_limit/100}")
                dollar_info=" ${used_fmt}/${limit_fmt}"
            fi
        fi
        # Opportunistically refresh oauth (only if no backoff)
        if [ ! -f "$OAUTH_BACKOFF" ] || [ $(( now - $(stat -f %m "$OAUTH_BACKOFF" 2>/dev/null || echo 0) )) -gt 900 ]; then
            if [ -z "$(find "$OAUTH_CACHE" -newermt '10 minutes ago' 2>/dev/null)" ]; then
                # Re-fetch token (was local to fetch_probe)
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
                fi  # oauth_token
            fi
        fi
        if [ "$op" -gt 0 ] 2>/dev/null; then
            extra_str="${BRED}⚠ extra ${op}%${dollar_info}${RESET}"
        else
            extra_str="${BRED}⚠ extra on${dollar_info}${RESET}"
        fi
    fi
fi

# Session token totals
total_in=$(echo "$context_window" | jq '.total_input_tokens // empty')
total_out=$(echo "$context_window" | jq '.total_output_tokens // empty')

token_str=""
if [ -n "$total_in" ] && [ "$total_in" != "null" ] && \
   [ -n "$total_out" ] && [ "$total_out" != "null" ]; then
    in_disp=$(fmt_tok "$total_in")
    out_disp=$(fmt_tok "$total_out")
    token_str="${DIM}i:${in_disp} o:${out_disp}${RESET}"
elif [ "$usage" != "null" ]; then
    in_disp=$(fmt_tok "$in_total")
    out_disp=$(fmt_tok "$(echo "$usage" | jq '.output_tokens // 0')")
    token_str="${DIM}i:${in_disp} o:${out_disp}${RESET}"
fi

# Cache hit rate
cache_str=""
if [ "$usage" != "null" ]; then
    input_tokens=$(echo "$usage" | jq '.input_tokens // 0')
    cache_read=$(echo "$usage"   | jq '.cache_read_input_tokens // 0')
    denom=$((input_tokens + cache_read))
    if [ "$denom" -gt 0 ] && [ "$cache_read" -gt 0 ]; then
        cpct=$((cache_read * 100 / denom))
        if   [ "$cpct" -ge 70 ]; then CACHE_COLOR=$GREEN
        elif [ "$cpct" -ge 40 ]; then CACHE_COLOR=$YELLOW
        else                          CACHE_COLOR=$RED
        fi
        cache_str="${CACHE_COLOR}⚡${cpct}%${RESET}"
    fi
fi

# Session cost (from Claude Code JSON — most accurate source)
cost_str=""
if [ "$cost_data" != "null" ]; then
    cost_usd=$(echo "$cost_data" | jq -r '.total_cost_usd // 0')
    if [ "$cost_usd" != "0" ] && [ "$cost_usd" != "null" ]; then
        cost_str="${DIM}s:\$$(printf "%.2f" "$cost_usd")${RESET}"
    fi
fi

# ── Assemble line 2 ──────────────────────────────────────────────────────────
line2_parts=()
[ -n "$plan_5h"   ] && line2_parts+=("$plan_5h")
[ -n "$plan_7d"   ] && line2_parts+=("$plan_7d")
[ -n "$extra_str" ] && line2_parts+=("$extra_str")
[ -n "$token_str" ] && line2_parts+=("$token_str")
[ -n "$cache_str" ] && line2_parts+=("$cache_str")
[ -n "$cost_str"  ] && line2_parts+=("$cost_str")

line2=""
for part in "${line2_parts[@]}"; do
    [ -z "$line2" ] && line2="$part" || line2="${line2}${SEP}${part}"
done

printf "%s\n%s\n" "$line1" "$line2"
