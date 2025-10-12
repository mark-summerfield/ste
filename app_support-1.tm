# Copyright © 2025 Mark Summerfield. All rights reserved.

oo::define App method file_open {} {
    if {[string match *.ste $Filename]} {
        lassign {true $::STE_PREFIX} compressed prefix
    } elseif {[string match *.tkt $Filename]} {
        lassign {false ""} compressed prefix
    } elseif {[string match *.tktz $Filename]} {
        lassign {true ""} compressed prefix
    } else {
        my show_error "unrecognized format for '$Filename'"
        return
    }
    $ATextEdit deserialize [readFile $Filename binary] $compressed $prefix
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
        if {[string match *.ste $Filename]} {
            set raw [$ATextEdit serialize true $::STE_PREFIX]
        } elseif {[string match *.tktz $Filename]} {
            set raw [$ATextEdit serialize]
        } else {
            my show_error "unrecognized format for '$Filename'"
            return
        }
        writeFile $Filename binary $raw
    }
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Saved '$Filename'."
}
