# Copyright © 2025 Mark Summerfield. All rights reserved.

oo::define App method file_open {} {
    $ATextEdit deserialize [readFile $Filename binary]
    $ATextEdit focus
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$Filename'."
}

oo::define App method file_import_text filename {
    $ATextEdit load [readFile $filename]
    $ATextEdit focus
    set Filename [regsub {\.txt$} $filename .ste]
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$filename' (will save as '$Filename')." long
}

oo::define App method file_save {} {
    if {[string match *.tkt $Filename]} {
        writeFile $Filename [$ATextEdit serialize false]
    } else {
        writeFile $Filename binary [$ATextEdit serialize]
    }
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Saved '$Filename'."
}
