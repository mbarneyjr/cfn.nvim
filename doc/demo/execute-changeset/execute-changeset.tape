Output execute-changeset.gif

Set Shell zsh

Set FontSize 44
Set Width 2400
Set Height 1200
Set Padding 40

Set FontFamily "Berkeley Mono, BerkeleyMono Nerd Font"

Hide
Type `cd "$(git rev-parse --show-toplevel)"` Enter
Sleep 500ms
Type `nix develop .#sandbox-dev --command env AWS_SHARED_CREDENTIALS_FILE="$PWD/docs/demo/aws.local/credentials" AWS_CONFIG_FILE="$PWD/docs/demo/aws.local/config" nvim -c "source docs/demo/execute-changeset/seed.lua"`
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

Type ":Cfn changeset load"
Sleep 500ms
Enter
Sleep 2s
Enter
Sleep 1500ms

Enter
Sleep 1500ms

Type "G"
Sleep 1500ms

Type ":Cfn changeset execute"
Sleep 500ms
Enter
Sleep 2s
Enter
Sleep 3s

Hide
Sleep 24s
Show
Sleep 2000ms

Sleep 2s
Enter
Sleep 500ms
Enter
Sleep 500ms
Enter
Sleep 4000ms

Hide
Type ":qa!" Enter
Sleep 500ms
