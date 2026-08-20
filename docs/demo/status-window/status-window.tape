Output status-window.gif

Set Shell zsh

Set FontSize 44
Set Width 2400
Set Height 1200
Set Padding 40

Set FontFamily "Berkeley Mono, BerkeleyMono Nerd Font"

Hide
Type `cd "$(git rev-parse --show-toplevel)"` Enter
Sleep 500ms
Type `nix develop .#sandbox --command env AWS_SHARED_CREDENTIALS_FILE="$PWD/docs/demo/aws.local/credentials" AWS_CONFIG_FILE="$PWD/docs/demo/aws.local/config" nvim -c "source docs/demo/seed-data.lua"`
Enter
Sleep 2s
Type ":intro"
Enter
Show
Sleep 1s

Enter
Type ":Cfn status"
Sleep 500ms
Enter
Ctrl+L
Sleep 800ms

Down 4
Sleep 600ms
Type ">"
Sleep 1s

Down 2
Sleep 600ms
Type ">"
Sleep 4000ms

Hide
Type ":qa!" Enter
Sleep 500ms
