#!/usr/bin/env bash
# send_mutt_interactive.sh
# Interactive wrapper for mutt with CC/BCC and edit options for subject/body.
# Usage: ./send_mutt_interactive.sh

set -euo pipefail

# Helper: prompt with default
prompt() {
  local varname="$1"; local prompt_text="$2"; local default="$3"
  local val
  if [ -n "$default" ]; then
    read -rp "$prompt_text [$default]: " val
    val="${val:-$default}"
  else
    read -rp "$prompt_text: " val
  fi
  printf -v "$varname" '%s' "$val"
}

# Helper: boolean prompt
prompt_yesno() {
  local varname="$1"; local prompt_text="$2"; local default="$3"
  local val
  local defchar
  if [ "$default" = "y" ]; then defchar="Y/n"; else defchar="y/N"; fi
  while true; do
    read -rp "$prompt_text [$defchar]: " val
    val="${val:-$default}"
    case "$val" in
      y|Y|yes|YES) printf -v "$varname" '%s' "yes"; break ;;
      n|N|no|NO)  printf -v "$varname" '%s' "no"; break ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

# Ensure mutt exists
if ! command -v mutt >/dev/null 2>&1; then
  echo "WARNING: 'mutt' not found in PATH. The script will still build the command, but sending will fail."
fi

echo "Interactive Mutt sender — enhanced (CC/BCC + edit subject/body). Ctrl+C to cancel."
echo

# Defaults based on your example
prompt content_type "Content type (text/plain | text/html)" "text/html"
prompt realname "Real name to display in From header" "Carlos Medina"
prompt_yesno use_from "Enable use_from (set use_from=yes)?" "y"
prompt_yesno envelope_from "Enable envelope_from (set envelope_from=yes)?" "y"
prompt from_addr "From email address" "carlos.medina@transcableusa.com"
prompt subject "Email subject" "Please complete this today before you leave"

# Option to edit subject
prompt_yesno edit_subject "Edit the subject now in your editor?" "n"
if [ "$edit_subject" = "yes" ]; then
  # Create temp file with subject, open editor, read back
  tmp_subject_file="$(mktemp)"
  printf '%s\n' "$subject" > "$tmp_subject_file"
  : "${EDITOR:=}"
  if [ -z "$EDITOR" ]; then
    if command -v nano >/dev/null 2>&1; then EDITOR=nano
    else EDITOR=vi; fi
  fi
  "$EDITOR" "$tmp_subject_file"
  subject="$(sed -n '1p' "$tmp_subject_file" | tr -d '\r\n')"
  rm -f "$tmp_subject_file"
  # If subject empty, warn and allow re-enter
  if [ -z "$subject" ]; then
    echo "Subject is empty after editing; please enter a subject manually."
    read -rp "Subject: " subject
  fi
fi

# Attachments: comma or space separated
read -rp "Attachment file paths (comma or space separated). Leave blank for none: " attachments_raw
# Normalize attachments into array
IFS=$' \t\n,' read -r -a attachments <<< "$attachments_raw"

# Recipient(s)
read -rp "Recipient email addresses (space-separated) [example: user@domain.com]: " recipients_raw
if [ -z "$recipients_raw" ]; then
  echo "No recipients entered — aborting."
  exit 1
fi
IFS=$' \t\n' read -r -a recipients <<< "$recipients_raw"

# CC and BCC prompts
read -rp "CC email addresses (space-separated). Leave blank for none: " cc_raw
IFS=$' \t\n' read -r -a ccs <<< "$cc_raw"
read -rp "BCC email addresses (space-separated). Leave blank for none: " bcc_raw
IFS=$' \t\n' read -r -a bccs <<< "$bcc_raw"

# Body file (text or html). Default from your example:
prompt body_file "Path to body file (e.g. htmlphishingemail.txt)" "htmlphishingemail.txt"

# Option to edit body file
prompt_yesno edit_body "Edit the body file now before previewing?" "n"
if [ "$edit_body" = "yes" ]; then
  if [ ! -f "$body_file" ]; then
      echo "Body file '$body_file' not found — creating new file."
    : > "$body_file"
  fi
  : "${EDITOR:=}"
  if [ -z "$EDITOR" ]; then
    if command -v nano >/dev/null 2>&1; then EDITOR=nano
    else EDITOR=vi; fi
  fi
  "$EDITOR" "$body_file"
fi

# Validate files
if [ -n "$body_file" ] && [ ! -f "$body_file" ]; then
  echo "ERROR: body file '$body_file' does not exist."
  exit 1
fi

for a in "${attachments[@]}"; do
  if [ -n "$a" ] && [ ! -f "$a" ]; then
    echo "ERROR: attachment '$a' does not exist."
    exit 1
  fi
done

# Prepare mutt option strings
mutt_opts=()
mutt_opts+=( -e "set content_type=\"$content_type\"" )
mutt_opts+=( -e "set realname=\"$realname\"" )
if [ "$use_from" = "yes" ]; then
  mutt_opts+=( -e "set use_from=yes" )
else
  mutt_opts+=( -e "set use_from=no" )
fi
if [ "$envelope_from" = "yes" ]; then
  mutt_opts+=( -e "set envelope_from=yes" )
else
  mutt_opts+=( -e "set envelope_from=no" )
fi
mutt_opts+=( -e "set from=\"$from_addr\"" )
mutt_opts+=( -s "$subject" )

# Attachments flags
for a in "${attachments[@]}"; do
  [ -n "$a" ] || continue
  mutt_opts+=( -a "$a" )
done

# CC/BCC flags (-c for cc, -b for bcc)
for c in "${ccs[@]}"; do
  [ -n "$c" ] || continue
  mutt_opts+=( -c "$c" )
done
for b in "${bccs[@]}"; do
  [ -n "$b" ] || continue
  mutt_opts+=( -b "$b" )
done

# Build recipient list for mutt (mutt expects recipients after --)
recipients_joined="${recipients[*]}"

# Compose a preview
echo
echo "================ MESSAGE PREVIEW ================"
echo "From: $realname <$from_addr>"
echo "To: ${recipients_joined}"
if [ "${#ccs[@]}" -gt 0 ] && [ -n "${ccs[0]}" ]; then
  printf "CC: "
  printf "%s " "${ccs[@]}"
  echo
fi
if [ "${#bccs[@]}" -gt 0 ] && [ -n "${bccs[0]}" ]; then
  printf "BCC: "
  printf "%s " "${bccs[@]}"
  echo
fi
echo "Subject: $subject"
echo "Content-Type: $content_type"
if [ "${#attachments[@]}" -gt 0 ] && [ -n "${attachments[0]}" ]; then
  echo "Attachments:"
  for a in "${attachments[@]}"; do
    [ -n "$a" ] || continue
    echo "  - $a"
  done
else
  echo "Attachments: (none)"
fi
echo "-------------------------------------------------"
echo "Message body (first 200 lines):"
echo "-------------------------------------------------"
# Print body safely; show line numbers for clarity
nl -ba "$body_file" | sed -n '1,200p'
echo "-------------------------------------------------"
echo

# Show the exact mutt command that will be run (for transparency)
echo "The following mutt command will be executed:"
display_cmd="mutt"
for opt in "${mutt_opts[@]}"; do
  # make a readable representation
  esc=$(printf '%s' "$opt" | sed 's/"/\\"/g')
  display_cmd+=" $esc"
done
display_cmd+=" -- ${recipients[*]}"
display_cmd+=" < $body_file"
echo
echo "$display_cmd"
echo

# Confirmation
prompt_yesno proceed "Send this email now?" "n"
if [ "$proceed" != "yes" ]; then
  echo "Aborted by user. No email sent."
  exit 0
fi

# Prepare args for mutt invocation
args=()
for opt in "${mutt_opts[@]}"; do
  args+=( "$opt" )
done
args+=( -- )
for r in "${recipients[@]}"; do
  args+=( "$r" )
done

# Execute mutt with stdin redirected from the body file
echo "Sending..."
if mutt "${args[@]}" < "$body_file"; then
  echo "Email successfully handed to mutt."
  exit 0
else
  echo "mutt returned a non-zero exit code. Email may not have been sent."
  exit 1
fi
