Output create-changeset.gif

Set Shell zsh

Set FontSize 44
Set Width 2400
Set Height 1200
Set Padding 40

Set FontFamily "Berkeley Mono, BerkeleyMono Nerd Font"

Hide
Type `cd "$(git rev-parse --show-toplevel)"` Enter
Sleep 500ms
Type `nix develop .#sandbox --command env AWS_SHARED_CREDENTIALS_FILE="$PWD/docs/demo/aws.local/credentials" AWS_CONFIG_FILE="$PWD/docs/demo/aws.local/config" nvim -c "source docs/demo/create-changeset/seed.lua"`
Enter
Sleep 2s
Type ":intro"
Enter
Show
Sleep 1s

Enter
Type ":e docs/demo/templates/prod/storage.yml"
Enter
Sleep 1500ms

Type ":Cfn changeset create"
Sleep 500ms
Enter
Sleep 2s
Enter
Sleep 1s

Type "C"
Sleep 1500ms
Type "Enabled"
Sleep 1s
Enter
Sleep 1s

Down 1
Type "cc30"
Escape
Sleep 500ms

Down 1
Type "ccqa"
Escape
Sleep 1500ms
Type "ccprod"
Escape
Sleep 800ms

Ctrl+S
Sleep 1500ms

Type "iteam=platform"
Escape
Sleep 500ms
Ctrl+S
Sleep 1500ms

Hide
Sleep 9s
Enter
Sleep 500ms
Sleep 3s
Show

Type "gg"
Sleep 500ms
Type "G"
Sleep 4000ms

Hide
Type ":qa!" Enter
Sleep 500ms
