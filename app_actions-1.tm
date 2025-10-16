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
    set filename [tk_getOpenFile -initialdir $dir -filetypes $FILETYPES \
            -title "[tk appname] — Open" -parent .]
    if {$filename ne ""} {
        set Filename $filename
        my file_open
    }
}

oo::define App method on_file_import_html {} {
    my on_file_save
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    const FILETYPES {{{HTML files} {.html}}}
    set filename [tk_getOpenFile -initialdir $dir -filetypes $FILETYPES \
            -title "[tk appname] — Open" -parent .]
    if {$filename ne ""} {
        my file_import_html $filename
    }
}

oo::define App method on_file_import_text {} {
    my on_file_save
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    const FILETYPES {{{text files} {.txt}}}
    set filename [tk_getOpenFile -initialdir $dir -filetypes $FILETYPES \
            -title "[tk appname] — Open" -parent .]
    if {$filename ne ""} {
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
    set filename [tk_getSaveFile -initialdir $dir -filetypes $FILETYPES \
            -title "[tk appname] — Save As" -parent .]
    if {$filename ne ""} {
        set Filename $filename
        my file_save
    }
}

oo::define App method on_file_export_html {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .html]
    writeFile $filename [$ATextEdit as_html $filename]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_export_text {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .txt]
    writeFile $filename [$ATextEdit as_text]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_print {} {
    if {[catch {tk print [$ATextEdit textedit]} err]} {
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
    if {[[$ATextEdit textedit] edit modified]} {
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

oo::define App method on_edit_undo {} { $ATextEdit maybe_undo }

oo::define App method on_edit_redo {} { $ATextEdit maybe_redo }

oo::define App method on_edit_copy {} { $ATextEdit copy }

oo::define App method on_edit_cut {} { $ATextEdit cut }

oo::define App method on_edit_paste {} { $ATextEdit paste }

oo::define App method on_edit_ins_chr {} {
    set ch [InsChrForm show]
    if {$ch ne ""} {
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
    set start [$ATextEdit get "insert linestart" insert]
    if {[regexp {^\S+} $start]} {
        $ATextEdit insert insert "• "
    } else {
        set tags [$ATextEdit tag names insert]
        puts -nonewline "tags=$tags → "
        if {"NtextTab" in $tags} {
            $ATextEdit tag remove bindent1 insert
            lappend tags bindent2
        } elseif {"bindent1" ni $tags} {
            lappend tags bindent1
        }
        $ATextEdit insert insert "• "
        foreach tag $tags {
            $ATextEdit tag add $tag "insert linestart" "insert lineend"
        }
        puts "tags=$tags"
    }
}
