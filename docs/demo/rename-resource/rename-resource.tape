Output rename-resource.gif

Set Shell zsh

Set FontSize 44
Set Width 2400
Set Height 1200
Set Padding 40

Set FontFamily "Berkeley Mono, BerkeleyMono Nerd Font"

Hide
Type `cd "$(git rev-parse --show-toplevel)"` Enter
Sleep 500ms
Type `nix develop .#sandbox --command env AWS_SHARED_CREDENTIALS_FILE="$PWD/docs/demo/aws.local/credentials" AWS_CONFIG_FILE="$PWD/docs/demo/aws.local/config" nvim`
Enter
Sleep 2s
Type ":intro"
Enter
Show
Sleep 1s

Enter
Type ":e docs/demo/templates/dev/events.yml"
Enter
Sleep 1500ms

Type "G"
Sleep 1500ms

Type "4gg"
Type "^"
Sleep 500ms

Type ":Cfn rename"
Sleep 500ms
Enter
Sleep 1500ms

Ctrl+U
Sleep 500ms
Type "EventsLog"
Sleep 1s
Enter
Sleep 1200ms

Type "/EventsLog"
Sleep 500ms
Enter
Sleep 500ms
Type "viw"
Sleep 2000ms
Escape

Hide
Type ":qa!" Enter
Sleep 500ms
