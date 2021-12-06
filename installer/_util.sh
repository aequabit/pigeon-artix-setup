function pai_run_guided_editor() {
  tmux \
    new-session  "nano $1 && tmux kill-window -t 0" \; \
    split-window -h "cat docs/_common.txt $2 | less" \; \
    select-pane -t 0
}

function pai_guided_editor_dev() {
  tmux \
    new-session  "nano $1" \; \
    split-window -h "nano $2" \; \
    select-pane -t 0
}
