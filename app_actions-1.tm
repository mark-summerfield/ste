# Copyright © 2025-26 Mark Summerfield. All rights reserved.

package require about_form
package require config
package require config_form
package require ins_chr_form
package require maybe_save_form
package require ref

oo::define App method on_poll {} {
    set title [wm title .]
    if {[$AnSte edit modified]} {
        if {[string index $title end] ne "★"} {
            wm title . "$title ★"
        }
    } else {
        if {[string index $title end] eq "★"} {
            wm title . [string trim [string range $title 0 end-1]]
        }
    }
    after $::POLL_TIMEOUT [callback on_poll]
}

oo::define App method on_file_new {} {
    my on_file_save
    set Filename ""
    $AnSte clear
    $AnSte focus
    wm title . [tk appname]
    my show_message "New file."
}

oo::define App method on_file_open {} {
    my on_file_save
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    const FILETYPES [Ste filetypes]
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
    } elseif {![$AnSte isempty]} {
        my on_file_save_as
    }
}

oo::define App method on_file_save_as {} {
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    const FILETYPES [Ste filetypes]
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
    writeFile $filename [$AnSte as_html $title]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_export_odt {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .odt]
    set title [file rootname [file tail $filename]]
    $AnSte as_odt $filename $title
    my show_message "Exported '$filename'"
}

oo::define App method on_file_export_text {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .txt]
    writeFile $filename [$AnSte as_text]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_export_xml {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .xml]
    set title [Ste xml_escape [file rootname [file tail $filename]]]
    writeFile $filename [$AnSte as_xml $title]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_print {} {
    if {[catch {tk print [$AnSte tk_text]} err]} {
        my show_error $err
    }
}

oo::define App method on_config {} {
    set config [Config new]
    set ok [Ref new 0]
    set fonts [$config fonts]
    set show_indents [$config show_indents]
    set form [ConfigForm new $ok]
    tkwait window [$form form]
    if {[$ok get]} {
        set new_fonts [$config fonts]
        if {$fonts ne $new_fonts} {
            $AnSte set_fonts $new_fonts
            $AnSte edit modified 1
        }
        if {$show_indents != [$config show_indents]} {
            $AnSte show_indents [$config show_indents]
        }
    }
}

oo::define App method on_about {} {
    AboutForm new "Styled Text Editor" \
        https://github.com/mark-summerfield/ste
}

oo::define App method on_quit {} {
    if {[[$AnSte tk_text] edit modified]} {
        set reply [MaybeSaveForm show "[tk appname] — Unsaved Changes" \
            "Save unsaved changes?"]
        switch $reply {
            cancel { return }
            save { my on_file_save }
        }
    }
    my save_config
    exit
}

oo::define App method save_config {} {
    set hidden_toolbars [list]
    dict for {toolbar show} [$Toolbars toolbars] {
        if {!$show} { lappend hidden_toolbars $toolbar }
    }
    set config [Config new]
    $config set_hidden_toolbars $hidden_toolbars
    $config save [file normalize $Filename]
}

oo::define App method on_edit_undo {} { $AnSte on_undo }

oo::define App method on_edit_redo {} { $AnSte on_redo }

oo::define App method on_edit_copy {} { $AnSte on_copy }

oo::define App method on_edit_cut {} { $AnSte on_cut }

oo::define App method on_edit_paste {} { $AnSte on_paste }

oo::define App method on_edit_ins_chr {} {
    if {[set ch [InsChrForm show]] ne ""} {
        if {$ch eq "Q"} {
            $AnSte insert insert “”
            $AnSte mark set insert "insert -1 char"
        } else {
            $AnSte insert insert $ch
        }
    }
}

oo::define App method on_style style { $AnSte apply_style $style }

oo::define App method on_style_font kind { $AnSte apply_font $kind }

oo::define App method on_style_color color { $AnSte apply_color $color }

oo::define App method on_style_align align { $AnSte apply_align $align }

oo::define App method on_style_insert_bullet {} { $AnSte on_ctrl_tab 0 }

oo::define App method on_style_insert_number {} { $AnSte on_ctrl_key_1 0 }

oo::define App method on_style_indent_or_complete {} { $AnSte on_tab 1 0 0 }

oo::define App method on_style_unindent {} { $AnSte on_bs 0 }

oo::define App method on_find_changed {} {
    const opts "-pady 3 -padx 3"
    grid remove .mf.ff
    if {$ShowFindPanel} {
        grid .mf.ff
        focus .mf.ff.findEntry
    }
}

oo::define App method on_find {} {
    $FindEntry configure -foreground black
    set what [$FindEntry get]
    if {$what ne ""} {
        set i [$AnSte search -exact -nocase -- $what $FindIndex end]
        if {$i ne "" && [$AnSte compare $i != $FindIndex]} {
            $AnSte tag remove sel 1.0 end
            set j [$AnSte index "$i + [string length $what] chars"]
            $AnSte tag add sel $i $j
            $AnSte see $i
            set FindIndex [$AnSte index $j]
        } else {
            $FindEntry configure -foreground red
            set FindIndex 1.0
        }
    }
}
