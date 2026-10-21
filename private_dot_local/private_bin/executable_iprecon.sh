#!/usr/bin/env bash
# ============================================================================
#  iprecon.sh — passive OSINT collection for an IPv4 address
#  Version 2.0
#
#  Every lookup goes to a third-party data source. No packets are sent to the
#  target address and no connection is made to it.
#
#  Sources: RDAP (registry data), Team Cymru (BGP/ASN), ip-api.com (geo/ASN),
#           AbuseIPDB, AlienVault OTX, VirusTotal, Tor exit list, blocklist.de
#
#  Requires: curl, dig (bind-utils), jq.   Optional: nc (netcat) for the
#            Team Cymru TCP fallback.
#
#  Deliberately NO `set -e`. The previous revision used it and an unfollowed
#  HTTP 302 from the RDAP bootstrap killed the script silently. Failures are
#  handled per source instead, so one dead API never costs you the rest.
# ============================================================================

VERSION="2.0"
UA="iprecon-osint/${VERSION}"
TIMEOUT_HTTP=20

# ---- argument parsing ------------------------------------------------------

DEBUG=0
JSON_OUT=0
COLOR=1
IP=""

usage() {
    cat <<EOF
iprecon.sh ${VERSION} — passive OSINT for an IPv4 address

Usage: $(basename "$0") <ipv4> [options]

Options:
  --json        Emit consolidated JSON to stdout (suppresses human output)
  --debug       Print query URLs, HTTP status, redirect counts to stderr
  --no-color    Disable ANSI colour
  -h, --help    This message

Environment:
  ABUSEIPDB_KEY   AbuseIPDB API key   (free tier: 1000 checks/day)
  VT_API_KEY      VirusTotal API key  (free tier: 4 requests/min)
  OTX_API_KEY     AlienVault OTX key  (optional; raises rate limit)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)     JSON_OUT=1 ;;
        --debug)    DEBUG=1 ;;
        --no-color) COLOR=0 ;;
        -h|--help)  usage; exit 0 ;;
        -*)         printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
        *)          if [[ -z "$IP" ]]; then IP="$1"
                    else printf 'Unexpected argument: %s\n' "$1" >&2; exit 2; fi ;;
    esac
    shift
done

[[ -n "$IP" ]] || { usage >&2; exit 2; }

# ---- validation ------------------------------------------------------------

if ! [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    printf "Error: '%s' is not a valid dotted-quad IPv4 address.\n" "$IP" >&2
    exit 2
fi

IFS=. read -r o1 o2 o3 o4 <<< "$IP"
for o in "$o1" "$o2" "$o3" "$o4"; do
    if (( 10#$o > 255 )); then
        printf 'Error: octet %s out of range in %s\n' "$o" "$IP" >&2
        exit 2
    fi
done

# 10# forces base-10 so leading zeros aren't read as octal
o1d=$((10#$o1)); o2d=$((10#$o2))

PRIVATE_NOTE=""
if   (( o1d == 10 ));                            then PRIVATE_NOTE="RFC1918 10/8"
elif (( o1d == 127 ));                           then PRIVATE_NOTE="loopback 127/8"
elif (( o1d == 192 && o2d == 168 ));             then PRIVATE_NOTE="RFC1918 192.168/16"
elif (( o1d == 172 && o2d >= 16 && o2d <= 31 )); then PRIVATE_NOTE="RFC1918 172.16/12"
elif (( o1d == 169 && o2d == 254 ));             then PRIVATE_NOTE="link-local 169.254/16"
elif (( o1d == 100 && o2d >= 64 && o2d <= 127 ));then PRIVATE_NOTE="CGNAT 100.64/10"
elif (( o1d == 0 ));                             then PRIVATE_NOTE="this-network 0/8"
elif (( o1d >= 224 && o1d <= 239 ));             then PRIVATE_NOTE="multicast 224/4"
elif (( o1d >= 240 ));                           then PRIVATE_NOTE="reserved 240/4"
fi

# ---- dependencies ----------------------------------------------------------

missing=()
for bin in curl dig jq; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
done
if (( ${#missing[@]} > 0 )); then
    printf 'Error: missing required tools: %s\n' "${missing[*]}" >&2
    printf '  openSUSE:      sudo zypper in curl bind-utils jq\n' >&2
    printf '  Debian/Ubuntu: sudo apt install curl dnsutils jq\n' >&2
    printf '  Fedora:        sudo dnf install curl bind-utils jq\n' >&2
    exit 3
fi

# ---- colours, temp dir, helpers -------------------------------------------

if (( COLOR )) && [[ -t 1 ]]; then
    C_HDR=$'\033[1;36m'; C_WARN=$'\033[1;33m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
    C_HDR=""; C_WARN=""; C_DIM=""; C_RST=""
fi

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/iprecon.XXXXXX") || exit 4
trap 'rm -rf "$WORKDIR"' EXIT INT TERM

debug() { (( DEBUG )) && printf '%s[debug]%s %s\n' "$C_DIM" "$C_RST" "$*" >&2; return 0; }
hr()    { (( JSON_OUT )) || printf '\n%s=== %s ===%s\n' "$C_HDR" "$1" "$C_RST"; return 0; }
say()   { (( JSON_OUT )) || printf '%s\n' "$*"; return 0; }
warn()  { (( JSON_OUT )) || printf '%s%s%s\n' "$C_WARN" "$*" "$C_RST"; return 0; }
store() { printf '%s' "$2" > "$WORKDIR/$1.json"; }

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# fetch <url> [extra curl args...]
# Sets FETCH_BODY, FETCH_CODE, FETCH_REDIRS, FETCH_TIME; returns nonzero on curl error.
fetch() {
    local url="$1"; shift
    local out rc
    out=$(curl -sSL --max-time "$TIMEOUT_HTTP" -A "$UA" \
          -w $'\n'"__IPRECON_META__%{http_code}|%{num_redirects}|%{time_total}" \
          "$@" "$url" 2>/dev/null)
    rc=$?
    if [[ "$out" == *$'\n'__IPRECON_META__* ]]; then
        FETCH_BODY="${out%$'\n'__IPRECON_META__*}"
        IFS='|' read -r FETCH_CODE FETCH_REDIRS FETCH_TIME \
            <<< "${out##*$'\n'__IPRECON_META__}"
    else
        FETCH_BODY=""; FETCH_CODE="000"; FETCH_REDIRS="?"; FETCH_TIME="?"
    fi
    debug "GET $url  ->  HTTP ${FETCH_CODE}  (${FETCH_REDIRS} redirects, ${FETCH_TIME}s, curl_rc=${rc})"
    return "$rc"
}

# ---------------------------------------------------------------- 1. PTR ---
hr "Reverse DNS (PTR)"
PTR_TEXT=""
PTR_RAW=$(dig +short -x "$IP" 2>/dev/null)
if [[ -n "$(trim "$PTR_RAW")" ]]; then
    PTR_TEXT="$(trim "$PTR_RAW")"
    say "$PTR_TEXT"
else
    STATUS=$(dig -x "$IP" +noall +comments 2>/dev/null |
             awk '/status:/ {for (i=1; i<=NF; i++)
                      if ($i ~ /^status:/) {sub(/^status:/,"",$i); print $i; exit}}')
    case "${STATUS:-EMPTY}" in
        NXDOMAIN)
            PTR_TEXT="no PTR (NXDOMAIN - name does not exist; no reverse record configured)" ;;
        NOERROR)
            if dig -x "$IP" +noall +authority 2>/dev/null | grep -qE 'SOA|NS'; then
                PTR_TEXT="no PTR (zone exists, record simply not set)"
            else
                PTR_TEXT="no PTR (NOERROR with empty answer)"
            fi ;;
        SERVFAIL)
            PTR_TEXT="no PTR (SERVFAIL - local resolution problem; check your resolver/pfBlockerNG)" ;;
        *)
            PTR_TEXT="no PTR (unexpected query status: ${STATUS:-none})" ;;
    esac
    say "$PTR_TEXT"
fi
printf '%s' "$PTR_TEXT" | jq -Rs . > "$WORKDIR/ptr.json"

# --------------------------------------------------------------- 2. RDAP ---
hr "RDAP (registry data via rdap.org bootstrap)"
fetch "https://rdap.org/ip/$IP" || true
if [[ "$FETCH_CODE" != "200" ]]; then
    debug "bootstrap did not return 200 (got ${FETCH_CODE}); trying ARIN directly"
    fetch "https://rdap.arin.net/registry/ip/$IP" || true
fi
if [[ "$FETCH_CODE" == "200" ]] \
   && printf '%s' "$FETCH_BODY" | jq -e . >/dev/null 2>&1; then
    RDAP_OBJ=$(printf '%s' "$FETCH_BODY" | jq '{
        handle: .handle,
        network: .name,
        range: ((.startAddress // "?") + " - " + (.endAddress // "?")),
        type: .type,
        country: .country,
        parent: .parentHandle,
        events: [.events[]? | "\(.eventAction): \(.eventDate)"],
        abuse_emails: [.. | objects | select(has("vcardArray"))
                       | .vcardArray[1][]? | select(.[0]=="email") | .[3]] | unique
    }')
    say "$RDAP_OBJ"
    printf '%s' "$RDAP_OBJ" > "$WORKDIR/rdap.json"
else
    say "(RDAP lookup failed - HTTP ${FETCH_CODE})"
    echo null > "$WORKDIR/rdap.json"
fi

# --------------------------------------------------------- 3. Team Cymru ---
hr "Team Cymru (ASN / BGP origin)"
REV_OCTETS="$o4.$o3.$o2.$o1"
CYMRU_TXT=$(dig +short TXT "${REV_OCTETS}.origin.asn.cymru.com" 2>/dev/null)
CYMRU_OBJ=""
if [[ -n "$(trim "$CYMRU_TXT")" ]]; then
    # format: "8075 | 4.176.0.0/12 | US | arin |"
    CYMRU_OBJ=$(printf '%s' "$CYMRU_TXT" | tr -d '"' | jq -R \
        'split("|") | map(gsub("^ +| +$"; ""))
         | {asn: .[0], prefix: .[1], country: .[2], registry: .[3], allocated: .[4]}')
elif command -v nc >/dev/null 2>&1; then
    debug "DNS origin query empty - falling back to whois.cymru.com TCP/43 verbose"
    CYMRU_ROW=$(printf 'begin\nverbose\n%s\nend\n' "$IP" \
        | timeout 10 nc whois.cymru.com 43 2>/dev/null \
        | awk -F'|' 'NR>3 {print; exit}')
    if [[ -n "$(trim "$CYMRU_ROW")" ]]; then
        # verbose: ASN | IP | Prefix | CC | Registry | Allocated | AS Name
        CYMRU_OBJ=$(printf '%s' "$CYMRU_ROW" | jq -R \
            'split("|") | map(gsub("^ +| +$"; ""))
             | {asn: .[0], prefix: .[2], country: .[3],
                registry: .[4], allocated: .[5], as_name: .[6]}')
    fi
fi
if [[ -n "$CYMRU_OBJ" ]]; then
    say "$CYMRU_OBJ"
    printf '%s' "$CYMRU_OBJ" > "$WORKDIR/cymru.json"
else
    say "(Cymru lookup failed)"
    echo null > "$WORKDIR/cymru.json"
fi

# ------------------------------------------------------- 4. Geo / ISP -------
hr "Geolocation / ISP (ip-api.com)"
fetch "http://ip-api.com/json/${IP}?fields=status,message,country,regionName,city,lat,lon,timezone,isp,org,as,reverse,proxy,hosting,mobile"
if [[ "$FETCH_CODE" == "200" ]] \
   && printf '%s' "$FETCH_BODY" | jq -e '.status == "success"' >/dev/null 2>&1; then
    GEO_OBJ=$(printf '%s' "$FETCH_BODY" | jq '{
        location: {city: .city, region: .regionName, country: .country,
                   lat: .lat, lon: .lon, timezone: .timezone},
        network:  {isp: .isp, org: .org, asn: .as},
        flags:    {proxy: .proxy, hosting: .hosting, mobile: .mobile},
        reverse:  .reverse}')
    say "$GEO_OBJ"
    printf '%s' "$GEO_OBJ" > "$WORKDIR/geo.json"
else
    MSG=$(printf '%s' "$FETCH_BODY" | jq -r '.message // empty' 2>/dev/null)
    say "(ip-api failed - HTTP ${FETCH_CODE}${MSG:+, $MSG})"
    echo null > "$WORKDIR/geo.json"
fi

# ---------------------------------------------------------- 5. AbuseIPDB ---
hr "AbuseIPDB (reputation)"
if [[ -n "$ABUSEIPDB_KEY" ]]; then
    fetch "https://api.abuseipdb.com/api/v2/check?ipAddress=${IP}&maxAgeInDays=90" \
          -H "Key: $ABUSEIPDB_KEY" -H "Accept: application/json" || true
    if printf '%s' "$FETCH_BODY" | jq -e '.data' >/dev/null 2>&1; then
        ABUSE_OBJ=$(printf '%s' "$FETCH_BODY" | jq '.data | {
            abuse_confidence_score, total_reports, is_tor, usage_type,
            isp, domain, last_reported: (.reports[-1].reportCreatedAt // null)}')
        say "$ABUSE_OBJ"
        printf '%s' "$ABUSE_OBJ" > "$WORKDIR/abuse.json"
    else
        say "(AbuseIPDB API error - HTTP ${FETCH_CODE})"
        echo null > "$WORKDIR/abuse.json"
    fi
else
    say "(skipped: ABUSEIPDB_KEY not set)"
    echo null > "$WORKDIR/abuse.json"
fi

# --------------------------------------------------------------- 6. OTX ---
hr "AlienVault OTX (threat pulses)"
OTX_HEADERS=()
[[ -n "$OTX_API_KEY" ]] && OTX_HEADERS=(-H "X-OTX-API-KEY: $OTX_API_KEY")
fetch "https://otx.alienvault.com/api/v1/indicators/IPv4/${IP}/general" \
      "${OTX_HEADERS[@]}" || true
if printf '%s' "$FETCH_BODY" | jq -e '.pulse_info' >/dev/null 2>&1; then
    OTX_OBJ=$(printf '%s' "$FETCH_BODY" | jq '{
        pulse_count: ([.pulse_info.pulses[]?] | length),
        pulse_names: [.pulse_info.pulses[]?.name] | unique}')
    say "$OTX_OBJ"
    printf '%s' "$OTX_OBJ" > "$WORKDIR/otx.json"
else
    say "(OTX lookup failed - HTTP ${FETCH_CODE}; free key recommended)"
    echo null > "$WORKDIR/otx.json"
fi

# ---------------------------------------------------- 7. VirusTotal --------
hr "VirusTotal (passive DNS / detections)"
if [[ -n "$VT_API_KEY" ]]; then
    fetch "https://www.virustotal.com/api/v3/ip_addresses/${IP}" \
          -H "x-apikey: $VT_API_KEY" || true
    if printf '%s' "$FETCH_BODY" | jq -e '.data' >/dev/null 2>&1; then
        VT_OBJ=$(printf '%s' "$FETCH_BODY" | jq '.data.attributes | {
            as_owner, country, reputation,
            last_https_certificate_date,
            detections_malicious: .last_analysis_stats.malicious,
            detections_suspicious: .last_analysis_stats.suspicious}')
        say "$VT_OBJ"
        printf '%s' "$VT_OBJ" > "$WORKDIR/vt.json"
    else
        say "(VirusTotal API error - HTTP ${FETCH_CODE})"
        echo null > "$WORKDIR/vt.json"
    fi
else
    say "(skipped: VT_API_KEY not set)"
    echo null > "$WORKDIR/vt.json"
fi

# --------------------------------------------------------------- 8. Tor ----
hr "Tor exit-node check"
fetch "https://check.torproject.org/exit-addresses" || true
if [[ "$FETCH_CODE" == "200" ]]; then
    if grep -q "^ExitAddress $IP " <<< "$FETCH_BODY"; then
        TOR_VAL=true; say "IS a Tor exit node"
    else
        TOR_VAL=false; say "(not currently listed as a Tor exit node)"
    fi
else
    TOR_VAL=null; say "(Tor list unavailable - HTTP ${FETCH_CODE})"
fi
echo "$TOR_VAL" > "$WORKDIR/tor.json"

hr "Done"
