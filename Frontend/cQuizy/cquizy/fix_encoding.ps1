
$path = "h:\13_S1_3_vizsgaremek\Frontend\cQuizy\cquizy\lib\test_taking_page.dart"
$content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)

# Replacement map based on double-encoding (UTF8 -> CP1250 reading)
$replacements = @{
    ([char]0x0102 + [char]0x02C7) = [char]0x00E1 # á (0xC3 0xA1)
    ([char]0x0102 + [char]0x00A9) = [char]0x00E9 # é (0xC3 0xA9)
    ([char]0x0102 + [char]0x00AD) = [char]0x00ED # í (0xC3 0xAD)
    ([char]0x0102 + [char]0x0142) = [char]0x00F3 # ó (0xC3 0xB3)
    ([char]0x0102 + [char]0x00B6) = [char]0x00F6 # ö (0xC3 0xB6)
    ([char]0x0102 + [char]0x015F) = [char]0x00FA # ú (0xC3 0xBA)
    ([char]0x0102 + [char]0x013D) = [char]0x00FC # ü (0xC3 0xBC)
    ([char]0x0139 + [char]0x2018) = [char]0x0151 # ő (0xC5 0x91)
    ([char]0x0139 + [char]0x0105) = [char]0x0171 # ű (0xC5 0xB1)
    
    # Uppercase
    ([char]0x0102 + [char]0x0164) = [char]0x00CD # Í (C3 8D) - Fixed from screenshot ĂŤ
    ([char]0x0102 + [char]0x02DD) = [char]0x00CD # Í (C3 8D) - Alternative
    ([char]0x0102 + [char]0x2030) = [char]0x00C9 # É (C3 89)
    ([char]0x0102 + [char]0x201D) = [char]0x00D3 # Ó (C3 93)
    ([char]0x0102 + [char]0x2013) = [char]0x00D6 # Ö (C3 96)
    ([char]0x0139 + [char]0x0151) = [char]0x0150 # Ő (C5 90)
    ([char]0x0139 + [char]0x0171) = [char]0x0170 # Ű (C5 B0)
    ([char]0x0102 + [char]0x0021) = [char]0x00C1 # Á (C3 81)
}

foreach ($key in $replacements.Keys) {
    $content = $content.Replace($key, $replacements[$key])
}

[System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
