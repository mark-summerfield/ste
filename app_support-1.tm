# Copyright © 2025 Mark Summerfield. All rights reserved.

package require htmlparse 1

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
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Saved '$Filename'."
}

oo::define App method file_import_text filename {
    $ATextEdit load [readFile $filename]
    $ATextEdit focus
    set Filename [regsub {\.txt$} $filename .ste]
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$filename' (will save as '$Filename')." long
}

oo::define App method file_import_html filename {
    $ATextEdit clear
    htmlparse::parse -cmd [callback HandleHtmlTag] [readFile $filename]
    $ATextEdit highlight_urls
    $ATextEdit mark set insert 1.0
    $ATextEdit see 1.0
    $ATextEdit focus
    set Filename [regsub {\.html$} $filename .ste]
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$filename' (will save as '$Filename')." long
}

# TODO: colors aren't working!
# strike sub sup u center right + fix bold & italic → bolditalic
oo::define App method HandleHtmlTag {tag slash param txt} {
    const TAG_FOR_HTML_COLOR [$ATextEdit html_colors]
    set txt [string trimright [htmlparse::mapEscapes $txt] \n]
    set bold_index ""
    set color_index ""
    set color_tag ""
    set italic_index ""
    set highlight_index ""
    if {$slash eq ""} {
        switch $tag {
            b {
                if {$txt ne ""} { $ATextEdit insert end $txt bold }
                set bold_index [$ATextEdit index end]
            }
            br {
                $ATextEdit insert end [expr {[string trim $txt] eq ""\
                                             ? " " : $txt}]
            }
            i {
                if {$txt ne ""} { $ATextEdit insert end $txt italic }
                set italic [$ATextEdit index end]
            }
            p { if {$txt ne ""} { $ATextEdit insert end $txt } }
            li { $ATextEdit insert end "• $txt" }
            span {
                if {[regexp {background-color:\s*yellow} $param]} {
                    if {$txt ne ""} { $ATextEdit insert end $txt highlight }
                    set highlight_index [$ATextEdit index end]
                } else {
                    regexp {color:\s*(#[A-Fa-f0-9]+)} $param _ color
                    if {[info exists color]} {
                        set color_tag [dict getdef $TAG_FOR_HTML_COLOR \
                                        [string toupper $color] ""]
                        if {$color_tag ne ""} {
                            if {$txt ne ""} {
                                $ATextEdit insert end $txt $color_tag
                                set txt ""
                            }
                            set color_index [$ATextEdit index end]
                        }
                    }
                    if {$txt ne ""} { $ATextEdit insert end $txt }
                }
            }
            hmstart - html - head - title - body - meta - ul - ol - style {}
            default {
                puts "skipped <$tag $param>" ;# TODO debug
            }
        }
    } else {
        switch $tag {
            b {
                if {$bold_index ne ""} {
                    $ATextEdit tag add bold $bold_index end
                    set bold_index ""
                }
                if {$txt ne ""} { $ATextEdit insert end $txt }
            }
            br {
                $ATextEdit insert end [expr {[string trim $txt] eq ""\
                                             ? " " : $txt}]
            }
            i {
                if {$italic_index ne ""} {
                    $ATextEdit tag add italic $italic_index end
                    set italic_index ""
                }
                if {$txt ne ""} { $ATextEdit insert end $txt }
            }
            li - p { $ATextEdit insert end $txt\n }
            span {
                if {$highlight_index ne ""} {
                    $ATextEdit tag add yellow $highlight_index end
                    set highlight_index ""
                }
                if {$color_index ne "" && $color_tag ne ""} {
                    $ATextEdit tag add $color_tag $color_index end
                    set color_index ""
                }
                if {$txt ne ""} { $ATextEdit insert end $txt }
            }
            hmstart - html - head - title - body - meta - ul - ol - style {}
            default {}
        }
    }
}
