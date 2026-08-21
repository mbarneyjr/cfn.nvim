Output stack-refactor.gif

Set Shell zsh

Set FontSize 44
Set Width 2400
Set Height 1200
Set Padding 40

Set FontFamily "Berkeley Mono, BerkeleyMono Nerd Font"

Hide
Type `cd "$(git rev-parse --show-toplevel)"` Enter
Sleep 500ms
Type `nix develop .#sandbox-dev --command env AWS_SHARED_CREDENTIALS_FILE="$PWD/docs/demo/aws.local/credentials" AWS_CONFIG_FILE="$PWD/docs/demo/aws.local/config" nvim -c "source docs/demo/stack-refactor/seed.lua"`
Enter
Sleep 2s
Type ":intro"
Enter
Show
Sleep 1s

Enter
Type ":e docs/demo/templates/dev/database.yml"
Enter
Sleep 1500ms

Type ":vsplit docs/demo/templates/dev/database-v2.yml"
Enter
Sleep 1500ms

Ctrl+W
Sleep 300ms
Type "l"
Sleep 1200ms

Type "14gg"
Sleep 1200ms
Type "dG"
Sleep 1500ms
Type ":w"
Sleep 500ms
Enter
Sleep 1200ms

Ctrl+W
Sleep 300ms
Type "h"
Sleep 1200ms

Type "G"
Sleep 1200ms
Type "p"
Sleep 1500ms
Type ":w"
Sleep 500ms
Enter
Sleep 1500ms

Type ":only"
Enter
Sleep 500ms

Type ":Cfn refactor refresh"
Sleep 500ms
Enter
Sleep 2s
Enter
Sleep 1500ms

Type ":Cfn status"
Sleep 500ms
Enter
Ctrl+L
Sleep 800ms
Type "/stack refactor:"
Sleep 500ms
Enter
Sleep 1000ms

Type "/inferred"
Sleep 500ms
Enter
Sleep 2500ms

Type ":Cfn refactor create"
Sleep 500ms
Enter
Sleep 2s
Enter
Sleep 1s

Hide
Sleep 20s
Enter
Sleep 20s
Enter
Sleep 15s
Enter
Sleep 2s
Enter
Sleep 500ms
Enter
Show
Sleep 2500ms

Type ":Cfn refactor execute"
Sleep 500ms
Enter
Sleep 2s
Enter
Sleep 1s

Hide
Sleep 20s
Enter
Sleep 20s
Enter
Sleep 15s
Enter
Sleep 2s
Enter
Sleep 500ms
Enter
Show
Sleep 4000ms

Hide
Type ":qa!" Enter
Sleep 500ms
