# Copyright © 2025-26 Mark Summerfield. All rights reserved.

package require util

oo::define App method file_open {} {
    if {[$AnSte deserialize [readFile $Filename binary] \
            [file extension $Filename]]} {
        # the document may have set its own fonts (.ste v2+) so keep the
        # config (and so File->Config) in sync with what is displayed
        [Config new] set_fonts [$AnSte fonts]
        $AnSte focus
        wm title . "[tk appname] — [file tail $Filename]"
        my show_message "Opened '$Filename'."
    }
}

oo::define App method file_save {} {
    if {![file isdirectory [file dirname $Filename]]} {
        if {![$AnSte isempty]} {
            my on_file_save_as
        }
        return
    }
    set ext [file extension $Filename]
    set out [$AnSte serialize $ext]
    if {$ext eq ".tkt"} {
        writeFile $Filename $out
    } else {
        writeFile $Filename binary $out
    }
    $AnSte edit modified 0
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Saved '$Filename'."
}

oo::define App method file_import_text filename {
    $AnSte import_text [readFile $filename]
    $AnSte focus
    set Filename [regsub {\.txt$} $filename .ste]
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$filename' (will save as '$Filename')." long
}

oo::define App method file_import_html filename {
    $AnSte import_html [readFile $filename]
    $AnSte focus
    set Filename [regsub {\.html$} $filename .ste]
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$filename' (will save as '$Filename')." long
}

oo::define App method file_import_xml filename {
    $AnSte import_xml [readFile $filename]
    $AnSte focus
    set Filename [regsub {\.xml$} $filename .ste]
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$filename' (will save as '$Filename')." long
}
