param (
    [string]$Text = "System online. Scene description ready.",
    [string]$OutFile = "D:\smart-glasses\scene.wav"
)

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.Rate = 1
if ($OutFile) {
    $synth.SetOutputToWaveFile($OutFile)
    $synth.Speak($Text)
    $synth.Dispose()
    Write-Host "Audio written to: $OutFile"
} else {
    $synth.Speak($Text)
    $synth.Dispose()
    Write-Host "Spoken successfully."
}
