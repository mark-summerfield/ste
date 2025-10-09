# Copyright © 2025 Mark Summerfield. All rights reserved.

oo::define App method file_open {} {
    $TheTextEdit clear
    $TheTextEdit deserialize [readFile $Filename binary]
    set textEdit [$TheTextEdit textedit]
    $textEdit edit modified false
    $textEdit edit reset
    $textEdit mark set insert end
    $textEdit see insert
    focus $textEdit
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$Filename'."
}

oo::define App method file_save {} {
    if {[string match *.tkt $Filename]} {
        writeFile $Filename [$TheTextEdit serialize false]
    } else {
        writeFile $Filename binary [$TheTextEdit serialize]
    }
    my show_message "Saved '$Filename'."
}
