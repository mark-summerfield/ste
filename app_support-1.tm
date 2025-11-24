# Copyright © 2025 Mark Summerfield. All rights reserved.

package require util

oo::define App method file_open {} {
    $ATextEdit deserialize [readFile $Filename binary] \
        [file extension $Filename]
    $ATextEdit focus
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$Filename'."
}

oo::define App method file_save {} {
    set ext [file extension $Filename]
    set out [$ATextEdit serialize $ext]
    if {$ext eq ".tkt"} {
        writeFile $Filename $out
    } else {
        writeFile $Filename binary $out
    }
    $ATextEdit edit reset
    $ATextEdit edit modified false
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Saved '$Filename'."
}

oo::define App method file_import_text filename {
    $ATextEdit import_text [readFile $filename]
    $ATextEdit focus
    set Filename [regsub {\.txt$} $filename .ste]
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$filename' (will save as '$Filename')." long
}

oo::define App method file_import_html filename {
    $ATextEdit import_html [readFile $filename]
    $ATextEdit focus
    set Filename [regsub {\.html$} $filename .ste]
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$filename' (will save as '$Filename')." long
}
