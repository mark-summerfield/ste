# Copyright © 2025 Mark Summerfield. All rights reserved.

package require about_form
package require config
package require config_form
package require ins_chr_form
package require maybe_save_form
package require ref

oo::define App method on_poll {} {
    set title [wm title .]
    if {[$ATextEdit edit modified]} {
        if {[string index $title end] ne "❋"} {
            wm title . "$title ❋"
        }
    } else {
        if {[string index $title end] eq "❋"} {
            wm title . [string trim [string range $title 0 end-1]]
        }
    }
    after $::POLL_TIMEOUT [callback on_poll]
}

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

oo::define App method on_file_import_xml {} {
    my on_file_save
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    const FILETYPES {{{XML files} {.xml}}}
    if {[set filename [tk_getOpenFile -initialdir $dir \
            -filetypes $FILETYPES \
            -title "[tk appname] — Open" -parent .]] ne ""} {
        my file_import_xml $filename
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

oo::define App method on_file_export_xml {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .xml]
    set title [TextEdit xml_escape [file rootname [file tail $filename]]]
    writeFile $filename [$ATextEdit as_xml $title]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_print {} {
    if {[catch {tk print [$ATextEdit tk_text]} err]} {
        my show_error $err
    }
}

oo::define App method on_config {} {
    set config [Config new]
    set ok [Ref new 0]
    set family [$config family]
    set size [$config size]
    set show_indents [$config show_indents]
    set form [ConfigForm new $ok]
    tkwait window [$form form]
    if {[$ok get]} {
        if {$family ne [$config family] || $size != [$config size]} {
            $ATextEdit make_fonts [$config family] [$config size]
        }
        if {$show_indents != [$config show_indents]} {
            $ATextEdit show_indents [$config show_indents]
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

oo::define App method on_style_insert_bullet {} { $ATextEdit on_ctrl_tab 0 }

oo::define App method on_style_insert_number {} {
    $ATextEdit on_ctrl_key_1 0
}

oo::define App method on_style_indent_or_complete {} {
    $ATextEdit on_tab 1 0 0
}

oo::define App method on_style_unindent {} { $ATextEdit on_bs 0 }

oo::define App method on_find_changed {} {
    const opts "-pady 3 -padx 3"
    pack forget .mf.ff
    if {$ShowFindPanel} {
        pack .mf.ff -side bottom -fill x {*}$opts
        focus .mf.ff.findEntry
    }
}

oo::define App method on_find {} {
    $FindEntry configure -foreground black
    set what [$FindEntry get]
    if {$what ne ""} {
        set i [$ATextEdit search -exact -nocase -- $what $FindIndex end]
        if {$i ne "" && [$ATextEdit compare $i != $FindIndex]} {
            $ATextEdit tag remove sel 1.0 end
            set j [$ATextEdit index "$i + [string length $what] chars"]
            $ATextEdit tag add sel $i $j
            $ATextEdit see $i
            set FindIndex [$ATextEdit index $j]
        } else {
            $FindEntry configure -foreground red
            set FindIndex 1.0
        }
    }
}
