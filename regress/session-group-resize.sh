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
OUT=$(mktemp)
trap "rm -f $TMP1 $TMP2 $OUT" 0 1 15

# Create a session with two windows. After neww, current window is 1.
$TMUX -f/dev/null new -d -s test -x 80 -y 24 || exit 1
$TMUX neww -t test || exit 1
sleep 0.5

# Attach a small control client (80x24) to window 1 (the current window).
(echo "refresh-client -C 80,24"; sleep 10) | $TMUX -f/dev/null -C a -t test >$TMP1 2>&1 &
PID1=$!
sleep 0.5

# Create a grouped session with a larger control client (134x51).
# Select window 0 so the large client views window 0 while small client views window 1.
# Then switch to window 1 - this is where the bug manifests.
(echo "refresh-client -C 134,51"
 echo "selectw -t :0"
 sleep 1
 echo "switch-client -t :=1"
 sleep 2) | $TMUX -f/dev/null -C new -t test -x 134 -y 51 >$TMP2 2>&1 &
PID2=$!
sleep 2.5

# Check window 1's size - it should have resized to 134x51 immediately
# when the larger client switched to it.
$TMUX lsw -t test -F '#{window_index}:#{window_width}x#{window_height}' > $OUT

# Clean up
kill $PID1 $PID2 2>/dev/null
wait $PID1 $PID2 2>/dev/null
$TMUX kill-server 2>/dev/null

# Window 1 should be 134x51 (the larger client's size).
# Before the fix, window 1 stayed at 80x24 because recalculate_sizes()
# was called before window->latest was updated.
grep -q "1:134x51" $OUT || exit 1

exit 0
