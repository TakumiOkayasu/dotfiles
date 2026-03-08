Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object Windows.Forms.Form
$form.Text = "日本語入力"
$form.Width = 600
$form.Height = 160
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$textbox = New-Object Windows.Forms.TextBox
$textbox.Dock = "Fill"
$textbox.Font = New-Object Drawing.Font("Yu Gothic UI", 16)
$textbox.ImeMode = [Windows.Forms.ImeMode]::On

# Enter で確定、Escape でキャンセル
$confirmed = $false
$textbox.Add_KeyDown({
    if ($_.KeyCode -eq "Return") {
        $script:confirmed = $true
        $form.Close()
    }
    elseif ($_.KeyCode -eq "Escape") {
        $form.Close()
    }
})

$form.Controls.Add($textbox)
$form.Add_Shown({ $textbox.Focus() })
$form.ShowDialog() | Out-Null

if ($confirmed -and $textbox.Text.Length -gt 0) {
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    Write-Output $textbox.Text
}
