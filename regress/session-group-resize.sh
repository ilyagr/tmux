#!/bin/sh

# Test that window-size=latest works correctly when switching windows in
# session groups. When a larger client switches to a window that was previously
# only viewed by a smaller client, the window should resize immediately.
#
# This is a regression test for a bug where server_client_set_session() called
# recalculate_sizes() before setting window->latest, causing the resize
# calculation to use the old (smaller) client's size.

PATH=/bin:/usr/bin
TERM=screen

[ -z "$TEST_TMUX" ] && TEST_TMUX=$(readlink -f ../tmux)
TMUX="$TEST_TMUX -Ltest"
$TMUX kill-server 2>/dev/null

TMP1=$(mktemp)
TMP2=$(mktemp)
trap "rm -f $TMP1 $TMP2" 0 1 15

# Create a session with two windows, staying on window 0.
$TMUX -f/dev/null new -d -s test -x 80 -y 24 || exit 1
$TMUX neww -t test || exit 1
$TMUX selectw -t test:0 || exit 1

# Attach a small control client and have it select window 1.
# This makes the small client the "latest" for window 1.
# The sleep keeps stdin open so the control client stays attached.
(echo "refresh-client -C 80,24"; echo "selectw -t :1"; sleep 5) |
	$TMUX -f/dev/null -C a -t test >$TMP1 2>&1 &
PID1=$!

# Wait for small client to be on window 1.
n=0
while [ $n -lt 20 ]; do
	$TMUX lsc -F '#{client_name} #{window_index}' 2>/dev/null | grep -q " 1$" && break
	sleep 0.1
	n=$((n + 1))
done

# Create a grouped session with a larger control client.
# It starts on window 0 (inherited), then switches to window 1.
(echo "refresh-client -C 134,51"; echo "switch-client -t :=1"; sleep 5) |
	$TMUX -f/dev/null -C new -t test -x 134 -y 51 >$TMP2 2>&1 &
PID2=$!

# Wait briefly for the switch-client command to execute, then check.
# The resize should happen immediately (within 0.2s), not eventually.
# With the bug, the resize is delayed until some other event triggers it.
sleep 0.2
OUT=$($TMUX lsw -t test -F '#{window_index}:#{window_width}x#{window_height}' 2>/dev/null)

# Clean up - kill server (terminates clients). Don't wait for background
# sleeps; they'll be orphaned but harmless.
$TMUX kill-server 2>/dev/null

# Final check: window 1 should be 134x51 immediately after the switch.
# Before the fix, window 1 stayed at 80x24 until a later event.
echo "$OUT" | grep -q "1:134x51" || exit 1

exit 0
