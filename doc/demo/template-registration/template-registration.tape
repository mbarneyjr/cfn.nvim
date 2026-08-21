Output template-registration.gif

Set Shell zsh

Set FontSize 44
Set Width 2400
Set Height 1200
Set Padding 40

Set FontFamily "Berkeley Mono, BerkeleyMono Nerd Font"

Hide
Type `cd "$(git rev-parse --show-toplevel)"` Enter
Sleep 500ms
Type `nix develop .#sandbox-dev --command env AWS_SHARED_CREDENTIALS_FILE="$PWD/docs/demo/aws.local/credentials" AWS_CONFIG_FILE="$PWD/docs/demo/aws.local/config" nvim`
Enter
Sleep 2s
Type ":e docs/demo/templates/dev/sessions.yml"
Enter
Sleep 1500ms
Type ":Cfn template unregister"
Enter
Sleep 500ms
Type ":bd"
Enter
Sleep 300ms
Type ":intro"
Enter
Show
Sleep 1s

Enter
Type ":e docs/demo/templates/dev/sessions.yml"
Enter
Sleep 1500ms

Type ":Cfn template register"
Sleep 500ms
Enter
Sleep 1500ms

Type "dev"
Sleep 1s
Enter
Sleep 2s

Enter
Sleep 2s

Type "NEW STACK"
Sleep 1s
Enter
Sleep 2s

Ctrl+U
Type "app-sessions"
Sleep 1s
Enter
Sleep 2000ms

Type ":Cfn status"
Sleep 500ms
Enter
Ctrl+L
Sleep 1200ms

Type "/sessions.yml"
Sleep 500ms
Enter
Sleep 500ms
Type "V"
Sleep 1500ms

Hide
Escape
Type ":qa!" Enter
Sleep 500ms
