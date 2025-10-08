# Copyright © 2025 Mark Summerfield. All rights reserved.

package require about_form
package require config
package require config_form
package require ins_char_form
package require ref
package require textedit

oo::define App method on_file_new {} {
    my on_file_save
    set Filename ""
    $TheTextEdit clear
    focus [$TheTextEdit textedit]
}

oo::define App method on_file_open {} {
    my on_file_save
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    set filename [tk_getOpenFile -initialdir $dir -filetypes $::STE_FILES \
            -title "[tk appname] — Open" -parent .]
    if {$filename ne ""} {
        set Filename $filename
        my file_open
    }
}

oo::define App method on_file_save {} {
    if {$Filename ne ""} {
        my file_save
    } else {
        my on_file_save_as
    }
}

oo::define App method on_file_save_as {} {
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    set filename [tk_getSaveFile -initialdir $dir -filetypes $::STE_FILES \
            -title "[tk appname] — Save As" -parent .]
    if {$filename ne ""} {
        set Filename $filename
        my file_save
    }
}

oo::define App method on_file_export_html {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .html]
    writeFile $filename [$TheTextEdit as_html $filename]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_export_text {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .txt]
    writeFile $filename [$TheTextEdit as_text]
    my show_message "Exported '$filename'"
}

oo::define App method on_file_print {} {
    if {[catch {tk print [$TheTextEdit textedit]} err]} {
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
            $TheTextEdit make_fonts [$config family] [$config size]
        }
    }
}

oo::define App method on_about {} {
    AboutForm new "Styled Text Editor" \
        https://github.com/mark-summerfield/ste
}

oo::define App method on_quit {} {
    if {[[$TheTextEdit textedit] edit modified]} { my on_file_save }
    set config [Config new]
    $config save $Filename
    exit
}

oo::define App method on_edit_undo {} { $TheTextEdit maybe_undo }

oo::define App method on_edit_redo {} { $TheTextEdit maybe_redo }

oo::define App method on_edit_copy {} { $TheTextEdit copy }

oo::define App method on_edit_cut {} { $TheTextEdit cut }

oo::define App method on_edit_paste {} { $TheTextEdit paste }

oo::define App method on_edit_ins_char {} {
    set ch [InsCharForm show]
    if {$ch ne ""} { $TheTextEdit insert_char $ch }
}

oo::define App method on_style_bold {} { $TheTextEdit apply_style bold }

oo::define App method on_style_italic {} { $TheTextEdit apply_style italic }

oo::define App method on_style_highlight {} {
    $TheTextEdit apply_style highlight
}
