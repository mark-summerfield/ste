# Copyright © 2025 Mark Summerfield. All rights reserved.

oo::define App method file_open {} {
    $TheTextEdit deserialize [readFile $Filename binary]
    focus [$TheTextEdit textedit]
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$Filename'."
}

oo::define App method file_import_text filename {
    $TheTextEdit load [readFile $filename]
    focus [$TheTextEdit textedit]
    set Filename [regsub {\.txt$} $filename .ste]
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$filename' (will save as '$Filename')." long
}

oo::define App method file_save {} {
    if {[string match *.tkt $Filename]} {
        writeFile $Filename [$TheTextEdit serialize false]
    } else {
        writeFile $Filename binary [$TheTextEdit serialize]
    }
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Saved '$Filename'."
}
