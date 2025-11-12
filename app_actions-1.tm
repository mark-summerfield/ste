# Copyright © 2025 Mark Summerfield. All rights reserved.

package require about_form
package require config
package require config_form
package require ins_chr_form
package require maybe_save_form
package require ref

oo::define App method on_file_new {} {
    my on_file_save
    set Filename ""
    $ATextEdit clear
    $ATextEdit focus
    wm title . [tk appname]
    my show_message "New file."
}

oo::define App method on_file_open {} {
    my on_file_save
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    const FILETYPES [TextEdit filetypes]
    if {[set filename [tk_getOpenFile -initialdir $dir \
            -filetypes $FILETYPES \
            -title "[tk appname] — Open" -parent .]] ne ""} {
        set Filename $filename
        my file_open
    }
}

oo::define App method on_file_import_html {} {
    my on_file_save
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    const FILETYPES {{{HTML files} {.html}}}
    if {[set filename [tk_getOpenFile -initialdir $dir \
            -filetypes $FILETYPES \
            -title "[tk appname] — Open" -parent .]] ne ""} {
        my file_import_html $filename
    }
}

oo::define App method on_file_import_text {} {
    my on_file_save
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    const FILETYPES {{{text files} {.txt}}}
    if {[set filename [tk_getOpenFile -initialdir $dir \
            -filetypes $FILETYPES \
            -title "[tk appname] — Open" -parent .]] ne ""} {
        my file_import_text $filename
    }
}

oo::define App method on_file_save {} {
    if {$Filename ne ""} {
        my file_save
    } elseif {![$ATextEdit isempty]} {
        my on_file_save_as
    }
}

oo::define App method on_file_save_as {} {
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    const FILETYPES [TextEdit filetypes]
    if {[set filename [tk_getSaveFile -initialdir $dir \
            -filetypes $FILETYPES \
            -title "[tk appname] — Save As" -parent .]] ne ""} {
        set Filename $filename
        my file_save
    }
}

oo::define App method on_file_export_html {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .html]
    set title [html::html_entities [file rootname [file tail $filename]]]
    writeFile $filename [$ATextEdit as_html $title]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_export_text {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .txt]
    writeFile $filename [$ATextEdit as_text]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_print {} {
    if {[catch {tk print [$ATextEdit tk_text]} err]} {
        my show_error $err
    }
}

oo::define App method on_config {} {
    set config [Config new]
    set ok [Ref new false]
    set family [$config family]
    set size [$config size]
    set form [ConfigForm new $ok]
    tkwait window [$form form]
    if {[$ok get]} {
        if {$family ne [$config family] || $size != [$config size]} {
            $ATextEdit make_fonts [$config family] [$config size]
        }
    }
}

oo::define App method on_about {} {
    AboutForm new "Styled Text Editor" \
        https://github.com/mark-summerfield/ste
}

oo::define App method on_quit {} {
    if {[[$ATextEdit tk_text] edit modified]} {
        set reply [MaybeSaveForm show "[tk appname] — Unsaved Changes" \
            "Save unsaved changes?"]
        switch $reply {
            cancel { return }
            save { my on_file_save }
        }
    }
    set config [Config new]
    $config save [file normalize $Filename]
    exit
}

oo::define App method on_edit_undo {} { $ATextEdit on_undo }

oo::define App method on_edit_redo {} { $ATextEdit on_redo }

oo::define App method on_edit_copy {} { $ATextEdit on_copy }

oo::define App method on_edit_cut {} { $ATextEdit on_cut }

oo::define App method on_edit_paste {} { $ATextEdit on_paste }

oo::define App method on_edit_ins_chr {} {
    if {[set ch [InsChrForm show]] ne ""} {
        if {$ch eq "Q"} {
            $ATextEdit insert insert “”
            $ATextEdit mark set insert "insert -1 char"
        } elseif {$ch eq "•"} {
            my on_style_bullet_list
        } else {
            $ATextEdit insert insert $ch
        }
    }
}

oo::define App method on_style style { $ATextEdit apply_style $style }

oo::define App method on_style_color color {
    $ATextEdit apply_color $color
}

oo::define App method on_style_align align { $ATextEdit apply_align $align }

oo::define App method on_style_bullet_list {} {
    set i [$ATextEdit index "insert linestart"]
    set j [$ATextEdit index "insert lineend"]
    set start [$ATextEdit get $i insert]
    set line [$ATextEdit get $i $j]
    if {$line eq "• "} {
        $ATextEdit on_tab false
    } elseif {[regexp {^\S+} $start]} {
        $ATextEdit insert insert "• "
    } else {
        set tag ""
        set tags [$ATextEdit tag names insert]
        if {"bindent0" in $tags} {
            $ATextEdit tag remove bindent0 $i $j
            set tag bindent1
        } else {
            set tag bindent0
        }
        $ATextEdit tag remove NtextTab $i $j
        $ATextEdit insert insert "• " $tag
        $ATextEdit tag add $tag insert "insert +1 line"
    }
}

oo::define App method on_style_no_bullet_list {} {
    set i [$ATextEdit index "insert linestart"]
    set j [$ATextEdit index "insert lineend"]
    set line [$ATextEdit get $i $j]
    if {[regexp {^\s*•\s+$} $line]} {
        $ATextEdit delete $i $j
        set i [$ATextEdit index "$i -1 char"]
        set j [$ATextEdit index "$j +1 char"]
        $ATextEdit tag remove NtextTab $i $j
        $ATextEdit tag remove bindent0 $i $j
        $ATextEdit tag remove bindent1 $i $j
    }
}
